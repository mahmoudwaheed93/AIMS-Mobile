import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../data/models/excel_vehicle_model.dart';
import '../config/secrets.dart';
import 'arabic_voice_normalizer.dart';

/// Fallback plate extractor that asks a small LLM (Hugging Face Inference
/// Providers, OpenAI-compatible endpoint) to read a noisy transcript.
///
/// SPEED RULES (so the app keeps the same feel as the local engine):
///  * It is NEVER on the hot path. The local [ArabicVoiceNormalizer] runs first
///    on every partial result; this class is only called, in the background,
///    when the local parser found no plate in a transcript that clearly
///    contains plate-like digits.
///  * Hard timeout, tiny output (max_tokens), temperature 0.
///  * In-memory cache + de-duplication of identical in-flight requests.
class AiPlateRefiner {
  AiPlateRefiner._();
  static final AiPlateRefiner instance = AiPlateRefiner._();

  static const String _endpoint = 'https://router.huggingface.co/v1/chat/completions';

  /// Ultra-fast instruct model:
  /// - HuggingFace: 'Qwen/Qwen2.5-1.5B-Instruct' or 'meta-llama/Llama-3.2-3B-Instruct' (lightning fast ~250-400ms)
  /// - Groq: 'llama-3.1-8b-instant' (at https://api.groq.com/openai/v1/chat/completions ~120ms)
  static const String model = 'Qwen/Qwen2.5-1.5B-Instruct';

  static const Duration _timeout = Duration(milliseconds: 2000);
  static const int _maxCache = 200;

  static const String _systemPrompt =
      'You extract vehicle license plates from noisy Arabic speech-recognition text (Egyptian and Saudi dialects). '
      'A plate consists of 2 to 4 Arabic letters followed by exactly 4 digits. '
      'Spoken numbers must be converted to numeric digits (e.g. "الفين تمانية مية واحد وستين" -> 2861, "تلاتة تسعة اتنين ستة" -> 3926, "زيرو" -> 0). '
      'Spoken letter names and colloquial variations must become letters (e.g. "سين" -> س, "به" -> ب, "يه" -> ي, "طه" -> ط, "عين" -> ع, "نون" -> ن, "دال" -> د). '
      'Optional car brand or remarks spoken after the plate go to "brand" and "note". '
      'Reply with ONLY a valid JSON array, strictly without any prose, markdown explanation or thinking: '
      '[{"letters":"د ب ن","digits":"2816","brand":"","note":""}]. '
      'If no valid plate is detected, reply with []. Never invent digits or letters.';

  final http.Client _client = http.Client();
  final Map<String, List<ParsedPlateData>> _cache = {};
  final Set<String> _inFlight = {};

  bool get isEnabled => kHuggingFaceToken.isNotEmpty;

  Future<List<ParsedPlateData>> refine(String rawTranscript) async {
    if (!isEnabled) return const [];
    final key = ArabicVoiceNormalizer.normalizeArabicSpoken(rawTranscript);
    if (key.isEmpty) return const [];

    final cached = _cache[key];
    if (cached != null) return cached;
    if (!_inFlight.add(key)) return const [];

    final started = DateTime.now();
    try {
      final res = await _client
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Authorization': 'Bearer $kHuggingFaceToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': model,
              'temperature': 0,
              'max_tokens': 120,
              'messages': [
                {'role': 'system', 'content': _systemPrompt},
                {'role': 'user', 'content': rawTranscript},
              ],
            }),
          )
          .timeout(_timeout);

      if (res.statusCode != 200) {
        debugPrint('AI refine HTTP ${res.statusCode}');
        return const [];
      }
      final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final content = body['choices'][0]['message']['content'] as String? ?? '';
      final plates = _parse(content);

      if (_cache.length >= _maxCache) _cache.remove(_cache.keys.first);
      _cache[key] = plates;
      debugPrint('AI refine ${DateTime.now().difference(started).inMilliseconds}ms '
          '-> ${plates.map((p) => p.fullPlate).toList()}');
      return plates;
    } on TimeoutException {
      debugPrint('AI refine timeout');
      return const [];
    } catch (e) {
      debugPrint('AI refine error: $e');
      return const [];
    } finally {
      _inFlight.remove(key);
    }
  }

  /// Strictly validates the model output: anything that is not
  /// 2-4 Arabic letters + exactly 4 digits is dropped.
  List<ParsedPlateData> _parse(String content) {
    final start = content.indexOf('[');
    final end = content.lastIndexOf(']');
    if (start == -1 || end <= start) return const [];
    final List<dynamic> raw;
    try {
      raw = jsonDecode(content.substring(start, end + 1)) as List<dynamic>;
    } catch (_) {
      return const [];
    }

    final out = <ParsedPlateData>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final lettersRaw = ArabicVoiceNormalizer.normalizePlateForMatch('${item['letters'] ?? ''}');
      final digitsRaw = ArabicVoiceNormalizer.normalizePlateForMatch('${item['digits'] ?? ''}');
      if (!RegExp(r'^[ا-ي]{2,4}$').hasMatch(lettersRaw)) continue;
      if (!RegExp(r'^\d{4}$').hasMatch(digitsRaw)) continue;

      final letters = lettersRaw.split('').join(' ');
      final brand = '${item['brand'] ?? ''}'.trim();
      final note = '${item['note'] ?? ''}'.trim();
      out.add(ParsedPlateData(
        fullPlate: '$letters $digitsRaw',
        letters: letters,
        digits: digitsRaw,
        detectedBrand: brand.isEmpty ? '-' : brand,
        detectedNote: note.isEmpty ? '-' : note,
      ));
    }
    return out;
  }
}
