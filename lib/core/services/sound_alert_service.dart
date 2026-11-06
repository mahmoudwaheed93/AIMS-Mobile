import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Service to play alert/alarm sounds when a matching plate is detected.
class SoundAlertService {
  SoundAlertService._();
  static final SoundAlertService instance = SoundAlertService._();

  AudioPlayer? _player;
  DateTime? _lastAlertTime;

  /// Plays the alarm sound for a few seconds (e.g. 3-4s).
  /// Debounces rapid consecutive calls so audio does not overlap chaotically.
  Future<void> playMatchAlarm({int durationSeconds = 3}) async {
    try {
      final now = DateTime.now();
      if (_lastAlertTime != null &&
          now.difference(_lastAlertTime!).inMilliseconds < 1500) {
        return; // debounce
      }
      _lastAlertTime = now;

      _player ??= AudioPlayer();
      await _player!.stop();
      await _player!.setVolume(1.0);
      await _player!.play(AssetSource('sounds/alarm.wav'));

      Timer(Duration(seconds: durationSeconds), () async {
        try {
          await _player?.stop();
        } catch (_) {}
      });
    } catch (e) {
      debugPrint('[SoundAlertService] Error playing alert: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _player?.stop();
    } catch (_) {}
  }

  void dispose() {
    _player?.dispose();
    _player = null;
  }
}
