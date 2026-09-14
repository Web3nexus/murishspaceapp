import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  AudioPlayer? _ringingPlayer;
  AudioPlayer? _previewPlayer;
  AudioPlayer? _notifyPlayer;

  static const _soundsPrefKey = 'murihspace_chat_sounds';

  /// Returns true if the user has chat sounds enabled (default: true).
  Future<bool> isSoundEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_soundsPrefKey) ?? true;
  }

  Future<void> setSoundEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundsPrefKey, value);
  }

  /// Plays a short incoming-message chime.
  Future<void> playMessageReceived() async {
    try {
      if (!(await isSoundEnabled())) return;
      if (_notifyPlayer != null) {
        await _notifyPlayer!.stop();
        await _notifyPlayer!.dispose();
        _notifyPlayer = null;
      }
      _notifyPlayer = AudioPlayer();
      await _notifyPlayer!.setReleaseMode(ReleaseMode.stop);
      await _notifyPlayer!.play(AssetSource('sounds/sound_default.wav'));
      HapticFeedback.lightImpact();
    } catch (_) {
      HapticFeedback.selectionClick();
    }
  }

  /// Plays a notification alert sound.
  Future<void> playNotification() async {
    try {
      if (!(await isSoundEnabled())) return;
      if (_notifyPlayer != null) {
        await _notifyPlayer!.stop();
        await _notifyPlayer!.dispose();
        _notifyPlayer = null;
      }
      _notifyPlayer = AudioPlayer();
      await _notifyPlayer!.setReleaseMode(ReleaseMode.stop);
      await _notifyPlayer!.play(AssetSource('sounds/sound_chime.wav'));
      HapticFeedback.lightImpact();
    } catch (_) {
      HapticFeedback.selectionClick();
    }
  }

  /// Starts the outgoing telecom ringback tone (when calling someone).
  Future<void> startOutgoingRingback() async {
    try {
      await stopRinging();
      _ringingPlayer = AudioPlayer();
      await _ringingPlayer!.setReleaseMode(ReleaseMode.loop);
      await _ringingPlayer!.play(AssetSource('sounds/outgoing_ringback.wav'));
    } catch (_) {
      HapticFeedback.lightImpact();
      SystemSound.play(SystemSoundType.click);
    }
  }

  /// Starts the incoming phone ringtone (when someone calls you).
  Future<void> startIncomingRingtone() async {
    try {
      await stopRinging();
      _ringingPlayer = AudioPlayer();
      await _ringingPlayer!.setReleaseMode(ReleaseMode.loop);
      await _ringingPlayer!.play(AssetSource('sounds/incoming_ringtone.wav'));
    } catch (_) {
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
    }
  }

  /// Stops any active ringing/dialing sound immediately.
  Future<void> stopRinging() async {
    try {
      if (_ringingPlayer != null) {
        await _ringingPlayer!.stop();
        await _ringingPlayer!.dispose();
        _ringingPlayer = null;
      }
    } catch (_) {}
  }

  /// Plays a one-shot preview sound for notification sound picker.
  Future<void> playNotificationPreview(String soundName) async {
    try {
      if (_previewPlayer != null) {
        await _previewPlayer!.stop();
        await _previewPlayer!.dispose();
        _previewPlayer = null;
      }

      final filename = switch (soundName.toLowerCase()) {
        'aurora' => 'sound_aurora.wav',
        'chime' => 'sound_chime.wav',
        'bamboo' => 'sound_bamboo.wav',
        'glass' => 'sound_glass.wav',
        'pop' => 'sound_pop.wav',
        _ => 'sound_default.wav',
      };

      _previewPlayer = AudioPlayer();
      await _previewPlayer!.setReleaseMode(ReleaseMode.stop);
      await _previewPlayer!.play(AssetSource('sounds/$filename'));
      HapticFeedback.selectionClick();
    } catch (_) {
      HapticFeedback.selectionClick();
      SystemSound.play(SystemSoundType.click);
    }
  }
}

