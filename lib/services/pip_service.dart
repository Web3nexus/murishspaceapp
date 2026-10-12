import 'dart:io';
import 'package:flutter/services.dart';

/// Platform channel interface to trigger and configure OS-level
/// Picture-in-Picture (PiP) mode on Android and iOS.
class PipService {
  static const _channel = MethodChannel('com.murihspace.mobile/pip');

  /// Checks if the device and platform support native OS Picture-in-Picture.
  static Future<bool> isPipSupported() async {
    if (!Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('isPipSupported');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Informs the native platform of active call status so that pressing the
  /// Home button or switching apps automatically enters OS Picture-in-Picture.
  static Future<void> updateCallState({
    required bool isActive,
    required bool isVideo,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('updateCallState', {
        'isActive': isActive,
        'isVideo': isVideo,
      });
    } catch (_) {}
  }

  /// Explicitly requests the native OS to enter Picture-in-Picture mode now.
  static Future<bool> enterPip() async {
    if (!Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('enterPip');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }
}

