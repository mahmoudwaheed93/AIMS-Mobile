import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'speech_to_text_service_interface.dart';

/// Set to true ONLY if the Arabic offline speech pack is installed on the
/// phones (Settings > Google > Speech > Offline). On-device recognition has the
/// lowest latency and works without internet, but fails if the pack is missing.
const bool kPreferOnDeviceSpeech = false;

class MobileSpeechPlatformService implements SpeechPlatformService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  bool _wantListening = false;
  Function(String transcript)? _onResult;
  VoidCallback? _onDone;
  String? _localeId;

  int _session = 0;

  @override
  int get session => _session;

  @override
  bool get isListening => _wantListening;

  @override
  Future<bool> initSpeech() async {
    if (_isInitialized) return true;
    try {
      _isInitialized = await _speech.initialize(
        onError: (val) {
          debugPrint('Speech error: ${val.errorMsg} permanent=${val.permanent}');
          // Non-permanent errors (no_match / speech_timeout) => just restart.
          if (_wantListening && !val.permanent) {
            _restartSoon();
          } else if (_wantListening) {
            _wantListening = false;
            _onDone?.call();
          }
        },
        onStatus: (val) {
          debugPrint('Speech status: $val');
          if (_wantListening && (val == 'done' || val == 'notListening')) {
            _restartSoon();
          }
        },
      );
      if (_isInitialized) {
        final locales = await _speech.locales();
        final ar = locales.where((l) => l.localeId.toLowerCase().startsWith('ar')).toList();
        // Prefer Egyptian Arabic, then Saudi, then any Arabic; else device default.
        for (final pref in ['ar_eg', 'ar-eg', 'ar_sa', 'ar-sa']) {
          final m = ar.where((l) => l.localeId.toLowerCase() == pref);
          if (m.isNotEmpty) {
            _localeId = m.first.localeId;
            break;
          }
        }
        _localeId ??= ar.isNotEmpty ? ar.first.localeId : null;
        debugPrint('Speech locale used: $_localeId');
      }
      return _isInitialized;
    } catch (e) {
      debugPrint('Error initializing speech: $e');
      return false;
    }
  }

  Future<void> _restartSoon() async {
    await Future.delayed(const Duration(milliseconds: 60));
    if (_wantListening && !_speech.isListening) {
      await _listen();
    }
  }

  Future<void> _listen() async {
    _session++;
    try {
      await _speech.listen(
        listenOptions: stt.SpeechListenOptions(
          localeId: _localeId ?? 'ar_SA',
          listenMode: stt.ListenMode.dictation,
          partialResults: true,
          cancelOnError: false,
          autoPunctuation: false,
          enableHapticFeedback: false,
          onDevice: kPreferOnDeviceSpeech,
        ),
        listenFor: const Duration(minutes: 5),
        pauseFor: const Duration(seconds: 20),
        onResult: (result) => _onResult?.call(result.recognizedWords),
      );
    } catch (e) {
      debugPrint('Error during speech listen: $e');
      _wantListening = false;
      _onDone?.call();
    }
  }

  @override
  Future<void> startListening({
    required Function(String transcript) onResult,
    required VoidCallback onDone,
  }) async {
    final available = await initSpeech();
    if (!available) {
      onDone();
      return;
    }
    _onResult = onResult;
    _onDone = onDone;
    _wantListening = true;
    await _listen();
  }

  @override
  Future<void> stopListening() async {
    _wantListening = false;
    if (_speech.isListening) {
      await _speech.stop();
    }
  }
}

SpeechPlatformService getSpeechPlatformService() => MobileSpeechPlatformService();
