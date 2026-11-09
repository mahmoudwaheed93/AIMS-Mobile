import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'speech_to_text_service_interface.dart';

/// Flag to control initial on-device preference.
/// Enabled by default for 0ms instant local speech recognition.
const bool kPreferOnDeviceSpeech = true;

class MobileSpeechPlatformService implements SpeechPlatformService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  bool _wantListening = false;
  bool _isStarting = false;
  bool _useOnDevice = kPreferOnDeviceSpeech;
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
          if (_wantListening) {
            // If on-device fails with unsupported language, fallback immediately to cloud
            if (_useOnDevice &&
                (val.errorMsg.contains('language_not_supported') ||
                    val.errorMsg.contains('error_server') ||
                    val.errorMsg.contains('error_busy'))) {
              debugPrint('On-device speech unavailable, falling back to standard recognition.');
              _useOnDevice = false;
            }
            if (!val.permanent) {
              _restartNow();
            } else {
              _wantListening = false;
              _onDone?.call();
            }
          }
        },
        onStatus: (val) {
          debugPrint('Speech status: $val');
          if (_wantListening && (val == 'done' || val == 'notListening')) {
            _restartNow();
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
        debugPrint('Speech locale used: $_localeId (onDevice: $_useOnDevice)');
      }
      return _isInitialized;
    } catch (e) {
      debugPrint('Error initializing speech: $e');
      return false;
    }
  }

  void _restartNow() {
    if (!_wantListening || _isStarting) return;
    // Immediate restart on next microtask with zero artificial delay for seamless continuous speech
    scheduleMicrotask(() {
      if (_wantListening && !_speech.isListening && !_isStarting) {
        _listen();
      }
    });
  }

  Future<void> _listen() async {
    if (_isStarting || !_wantListening) return;
    _isStarting = true;
    _session++;
    bool needFallback = false;
    try {
      await _speech.listen(
        listenOptions: stt.SpeechListenOptions(
          localeId: _localeId ?? 'ar_SA',
          // confirmation / deviceDefault emits partial words instantly without waiting for sentence silence
          listenMode: stt.ListenMode.confirmation,
          partialResults: true,
          cancelOnError: false,
          autoPunctuation: false,
          enableHapticFeedback: false,
          onDevice: _useOnDevice,
        ),
        listenFor: const Duration(hours: 1),
        pauseFor: const Duration(seconds: 4),
        onResult: (result) {
          if (result.recognizedWords.isNotEmpty) {
            _onResult?.call(result.recognizedWords);
          }
        },
      );
    } catch (e) {
      debugPrint('Error during speech listen: $e');
      if (_useOnDevice) {
        _useOnDevice = false;
        needFallback = true;
      } else {
        _wantListening = false;
        _onDone?.call();
      }
    } finally {
      _isStarting = false;
    }

    if (needFallback && _wantListening) {
      await _listen();
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
    _useOnDevice = kPreferOnDeviceSpeech;
    await _listen();
  }

  @override
  Future<void> stopListening() async {
    _wantListening = false;
    _isStarting = false;
    if (_speech.isListening) {
      await _speech.stop();
    }
  }
}

SpeechPlatformService getSpeechPlatformService() => MobileSpeechPlatformService();
