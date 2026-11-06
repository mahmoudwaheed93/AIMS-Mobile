import 'dart:io';
import 'package:flutter/foundation.dart';
import 'speech_to_text_service_interface.dart';
import 'speech_to_text_service_mobile.dart';
import 'speech_to_text_service_web.dart';
import 'arabic_voice_normalizer.dart';
import '../../data/models/excel_vehicle_model.dart';

class SpeechService {
  static final SpeechService instance = SpeechService._init();
  SpeechService._init();

  late final SpeechPlatformService _platformService = kIsWeb
      ? WebSpeechPlatformService()
      : MobileSpeechPlatformService();

  bool get isListening => _platformService.isListening;

  Future<bool> initSpeech() => _platformService.initSpeech();

  Future<void> startListening({
    required Function(String rawTranscript, List<ParsedPlateData> plates, Map<String, String> slots) onResult,
    required VoidCallback onDone,
    void Function(String? note, int session)? onOrphanNote,
  }) async {
    await _platformService.startListening(
      onResult: (transcript) {
        // A note without its plate (said after a pause) is delivered FIRST,
        // before any new plate of the same transcript is recorded.
        if (onOrphanNote != null) {
          onOrphanNote(ArabicVoiceNormalizer.orphanNote(transcript), _platformService.session);
        }
        final plates = ArabicVoiceNormalizer.extractPlatesFromTranscript(transcript);
        final slots = ArabicVoiceNormalizer.extractSlots(transcript);
        onResult(transcript, plates, slots);
      },
      onDone: onDone,
    );
  }

  Future<void> stopListening() => _platformService.stopListening();
}
