/// One end-to-end encryption device: a Signal identity with sessions to other devices.
///
/// Wraps the native handle from murih_e2ee_bindings.dart. The handle is not
/// thread-safe, so a device must be used from one isolate only. Each mutating call
/// (startSession, encrypt, decrypt) advances ratchet state. Call [export] and save
/// it after every such call, before the result is sent or shown.
library;

import 'dart:ffi';
import 'dart:typed_data';

import 'murih_e2ee_bindings.dart';

export 'murih_e2ee_bindings.dart' show E2eeNativeException;

class E2eeDevice implements Finalizable {
  E2eeDevice._(this._bindings, Pointer<MurihDeviceOpaque> handle) : _handle = handle {
    _bindings.handleFinalizer.attach(this, handle.cast(), detach: this);
  }

  final MurihE2eeBindings _bindings;
  Pointer<MurihDeviceOpaque>? _handle;

  /// Creates a device with fresh keys. [name] is the protocol address of this device.
  /// Pass [libraryPath] only from tests. Create on a background isolate when possible.
  static E2eeDevice create({
    required String name,
    required int registrationId,
    required int prekeyCount,
    String? libraryPath,
  }) {
    final bindings = MurihE2eeBindings.load(path: libraryPath);
    return E2eeDevice._(bindings, bindings.newDevice(name, registrationId, prekeyCount));
  }

  /// Restores a device from the JSON that [export] returned.
  static E2eeDevice restore({
    required String name,
    required String stateJson,
    String? libraryPath,
  }) {
    final bindings = MurihE2eeBindings.load(path: libraryPath);
    return E2eeDevice._(bindings, bindings.restoreDevice(name, stateJson));
  }

  bool get isClosed => _handle == null;

  Pointer<MurihDeviceOpaque> get _live {
    final handle = _handle;
    if (handle == null) throw StateError('The encryption device is closed.');
    return handle;
  }

  /// Full private state as JSON. Encrypt it before it is stored.
  String export() => _bindings.exportState(_live);

  /// Public keys for the key directory, as JSON in the bundle shape.
  String publicBundle() => _bindings.publicBundle(_live);

  /// Starts a session with a remote device from its public bundle JSON.
  void startSession(String remoteName, String bundleJson) =>
      _bindings.startSession(_live, remoteName, bundleJson);

  /// Encrypts [plaintext] for [remoteName]. Returns the wire ciphertext.
  Uint8List encrypt(String remoteName, Uint8List plaintext) =>
      _bindings.encrypt(_live, remoteName, plaintext);

  /// Decrypts a ciphertext from [remoteName]. Throws if it was tampered with or
  /// does not belong to this device's sessions.
  Uint8List decrypt(String remoteName, Uint8List ciphertext) =>
      _bindings.decrypt(_live, remoteName, ciphertext);

  /// Frees the native handle. Safe to call twice.
  void close() {
    final handle = _handle;
    if (handle == null) return;
    _handle = null;
    _bindings.handleFinalizer.detach(this);
    _bindings.freeDevice(handle);
  }
}
