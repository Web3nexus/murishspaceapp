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

  bool _isRinging = false;

  /// Starts the outgoing telecom ringback tone (when calling someone).
  Future<void> startOutgoingRingback() async {
    _isRinging = true;
    try {
      await stopRinging();
      if (!_isRinging) return;
      final player = AudioPlayer();
      _ringingPlayer = player;
      await player.setAudioContext(AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: [
            AVAudioSessionOptions.defaultToSpeaker,
            AVAudioSessionOptions.mixWithOthers,
          ],
        ),
        android: AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: true,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.notificationCommunicationRequest,
          audioFocus: AndroidAudioFocus.gainTransient,
        ),
      ));
      await player.setReleaseMode(ReleaseMode.loop);
      if (!_isRinging) {
        await player.stop();
        await player.dispose();
        if (_ringingPlayer == player) _ringingPlayer = null;
        return;
      }
      await player.play(AssetSource('sounds/outgoing_ringback.wav'));
      if (!_isRinging) {
        await player.stop();
        await player.dispose();
        if (_ringingPlayer == player) _ringingPlayer = null;
      }
    } catch (_) {
      if (_isRinging) {
        HapticFeedback.lightImpact();
        SystemSound.play(SystemSoundType.click);
      }
    }
  }

  /// Starts the incoming phone ringtone (when someone calls you).
  Future<void> startIncomingRingtone() async {
    _isRinging = true;
    try {
      await stopRinging();
      if (!_isRinging) return;
      final player = AudioPlayer();
      _ringingPlayer = player;
      await player.setAudioContext(AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: [
            AVAudioSessionOptions.defaultToSpeaker,
            AVAudioSessionOptions.mixWithOthers,
          ],
        ),
        android: AudioContextAndroid(
          isSpeakerphoneOn: true,
          stayAwake: true,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.notificationRingtone,
          audioFocus: AndroidAudioFocus.gainTransient,
        ),
      ));
      await player.setReleaseMode(ReleaseMode.loop);
      if (!_isRinging) {
        await player.stop();
        await player.dispose();
        if (_ringingPlayer == player) _ringingPlayer = null;
        return;
      }
      await player.play(AssetSource('sounds/incoming_ringtone.wav'));
      if (!_isRinging) {
        await player.stop();
        await player.dispose();
        if (_ringingPlayer == player) _ringingPlayer = null;
      }
    } catch (_) {
      if (_isRinging) {
        HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.alert);
      }
    }
  }

  /// Stops any active ringing/dialing sound immediately.
  Future<void> stopRinging() async {
    _isRinging = false;
    try {
      if (_ringingPlayer != null) {
        final p = _ringingPlayer!;
        _ringingPlayer = null;
        await p.stop();
        await p.dispose();
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

