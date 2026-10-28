/// Raw `dart:ffi` lookups for the murih-e2ee C ABI (`include/murih_e2ee.h`).
library;

///
/// Only this file knows the C names and signatures. The app uses [E2eeDevice]
/// (murih_device.dart). Ownership rules, from the header:
/// - Handles from `murih_device_new` / `murih_device_restore` are freed with
///   `murih_device_free`, exactly once.
/// - Output strings (and `err`) are freed with `murih_string_free`; output byte
///   buffers with `murih_bytes_free(ptr, len)`. Never free them with malloc/free.
/// - Input strings and byte buffers are borrowed for the call. Dart frees its own.
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

/// Opaque device handle. Dart sees only a pointer to this type.
final class MurihDeviceOpaque extends Opaque {}

/// Mirror of the C `MurihBytes` struct: a buffer allocated by Rust.
final class MurihBytesStruct extends Struct {
  external Pointer<Uint8> ptr;

  @IntPtr()
  external int len;
}

typedef _DeviceFreeNative = Void Function(Pointer<MurihDeviceOpaque> handle);
typedef _DeviceFreeDart = void Function(Pointer<MurihDeviceOpaque> handle);

typedef _StringFreeNative = Void Function(Pointer<Utf8> s);
typedef _StringFreeDart = void Function(Pointer<Utf8> s);

typedef _BytesFreeNative = Void Function(Pointer<Uint8> ptr, IntPtr len);
typedef _BytesFreeDart = void Function(Pointer<Uint8> ptr, int len);

typedef _DeviceNewNative =
    Pointer<MurihDeviceOpaque> Function(Pointer<Utf8> name, Uint32 registrationId, Uint32 prekeyCount, Pointer<Pointer<Utf8>> err);
typedef _DeviceNewDart =
    Pointer<MurihDeviceOpaque> Function(Pointer<Utf8> name, int registrationId, int prekeyCount, Pointer<Pointer<Utf8>> err);

typedef _DeviceRestoreNative =
    Pointer<MurihDeviceOpaque> Function(Pointer<Utf8> name, Pointer<Utf8> stateJson, Pointer<Pointer<Utf8>> err);
typedef _DeviceRestoreDart =
    Pointer<MurihDeviceOpaque> Function(Pointer<Utf8> name, Pointer<Utf8> stateJson, Pointer<Pointer<Utf8>> err);

typedef _JsonOutNative =
    Int32 Function(Pointer<MurihDeviceOpaque> handle, Pointer<Pointer<Utf8>> outJson, Pointer<Pointer<Utf8>> err);
typedef _JsonOutDart =
    int Function(Pointer<MurihDeviceOpaque> handle, Pointer<Pointer<Utf8>> outJson, Pointer<Pointer<Utf8>> err);

typedef _StartSessionNative =
    Int32 Function(Pointer<MurihDeviceOpaque> handle, Pointer<Utf8> remoteName, Pointer<Utf8> bundleJson, Pointer<Pointer<Utf8>> err);
typedef _StartSessionDart =
    int Function(Pointer<MurihDeviceOpaque> handle, Pointer<Utf8> remoteName, Pointer<Utf8> bundleJson, Pointer<Pointer<Utf8>> err);

typedef _CipherNative =
    Int32 Function(
      Pointer<MurihDeviceOpaque> handle,
      Pointer<Utf8> remoteName,
      Pointer<Uint8> input,
      IntPtr inputLen,
      Pointer<MurihBytesStruct> out,
      Pointer<Pointer<Utf8>> err,
    );
typedef _CipherDart =
    int Function(
      Pointer<MurihDeviceOpaque> handle,
      Pointer<Utf8> remoteName,
      Pointer<Uint8> input,
      int inputLen,
      Pointer<MurihBytesStruct> out,
      Pointer<Pointer<Utf8>> err,
    );

/// Failure reported by the native library, with the message Rust wrote to `err`.
class E2eeNativeException implements Exception {
  E2eeNativeException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Symbols of the native library. One instance per isolate (see [load]).
class MurihE2eeBindings {
  MurihE2eeBindings._(DynamicLibrary lib)
    : _newDevice = lib.lookupFunction<_DeviceNewNative, _DeviceNewDart>('murih_device_new'),
      _restoreDevice = lib.lookupFunction<_DeviceRestoreNative, _DeviceRestoreDart>('murih_device_restore'),
      _exportState = lib.lookupFunction<_JsonOutNative, _JsonOutDart>('murih_device_export'),
      _publicBundle = lib.lookupFunction<_JsonOutNative, _JsonOutDart>('murih_device_public_bundle'),
      _startSession = lib.lookupFunction<_StartSessionNative, _StartSessionDart>('murih_device_start_session'),
      _encrypt = lib.lookupFunction<_CipherNative, _CipherDart>('murih_device_encrypt'),
      _decrypt = lib.lookupFunction<_CipherNative, _CipherDart>('murih_device_decrypt'),
      _freeDevice = lib.lookupFunction<_DeviceFreeNative, _DeviceFreeDart>('murih_device_free'),
      _stringFree = lib.lookupFunction<_StringFreeNative, _StringFreeDart>('murih_string_free'),
      _bytesFree = lib.lookupFunction<_BytesFreeNative, _BytesFreeDart>('murih_bytes_free'),
      _freeDevicePointer = lib.lookup<NativeFunction<_DeviceFreeNative>>('murih_device_free') {
    handleFinalizer = NativeFinalizer(_freeDevicePointer.cast());
  }

  static MurihE2eeBindings? _instance;
  static String? _instancePath;

  /// Opens the library once per isolate. [path] is for tests, which load the host
  /// dylib. The app passes null and gets the platform default.
  static MurihE2eeBindings load({String? path}) {
    final existing = _instance;
    if (existing != null && _instancePath == path) return existing;
    final created = MurihE2eeBindings._(_open(path));
    _instance = created;
    _instancePath = path;
    return created;
  }

  static DynamicLibrary _open(String? path) {
    if (path != null) return DynamicLibrary.open(path);
    if (Platform.isAndroid) return DynamicLibrary.open('libmurih_e2ee.so');
    if (Platform.isIOS || Platform.isMacOS) {
      // The static library is linked into Runner. Its symbols are kept with -force_load.
      return DynamicLibrary.process();
    }
    throw UnsupportedError('End-to-end encryption is not available on this platform.');
  }

  final _DeviceNewDart _newDevice;
  final _DeviceRestoreDart _restoreDevice;
  final _JsonOutDart _exportState;
  final _JsonOutDart _publicBundle;
  final _StartSessionDart _startSession;
  final _CipherDart _encrypt;
  final _CipherDart _decrypt;
  final _DeviceFreeDart _freeDevice;
  final _StringFreeDart _stringFree;
  final _BytesFreeDart _bytesFree;
  final Pointer<NativeFunction<_DeviceFreeNative>> _freeDevicePointer;

  /// Finalizer that frees a handle if its [E2eeDevice] is garbage collected unclosed.
  late final NativeFinalizer handleFinalizer;

  /// Creates a device. Throws [E2eeNativeException] on failure.
  Pointer<MurihDeviceOpaque> newDevice(String name, int registrationId, int prekeyCount) {
    final err = calloc<Pointer<Utf8>>();
    final cName = name.toNativeUtf8(allocator: calloc);
    try {
      final handle = _newDevice(cName, registrationId, prekeyCount, err);
      if (handle == nullptr) throw _takeError(err, 'Could not create the encryption device.');
      return handle;
    } finally {
      calloc.free(cName);
      calloc.free(err);
    }
  }

  /// Restores a device from [stateJson]. Throws [E2eeNativeException] on failure.
  Pointer<MurihDeviceOpaque> restoreDevice(String name, String stateJson) {
    final err = calloc<Pointer<Utf8>>();
    final cName = name.toNativeUtf8(allocator: calloc);
    final cState = stateJson.toNativeUtf8(allocator: calloc);
    try {
      final handle = _restoreDevice(cName, cState, err);
      if (handle == nullptr) throw _takeError(err, 'Could not restore the encryption device.');
      return handle;
    } finally {
      calloc.free(cState);
      calloc.free(cName);
      calloc.free(err);
    }
  }

  String exportState(Pointer<MurihDeviceOpaque> handle) =>
      _readJsonOut((out, err) => _exportState(handle, out, err), 'Could not export the device state.');

  String publicBundle(Pointer<MurihDeviceOpaque> handle) =>
      _readJsonOut((out, err) => _publicBundle(handle, out, err), 'Could not read the public bundle.');

  void startSession(Pointer<MurihDeviceOpaque> handle, String remoteName, String bundleJson) {
    final err = calloc<Pointer<Utf8>>();
    final cName = remoteName.toNativeUtf8(allocator: calloc);
    final cBundle = bundleJson.toNativeUtf8(allocator: calloc);
    try {
      final status = _startSession(handle, cName, cBundle, err);
      if (status != 0) throw _takeError(err, 'Could not start a session.');
    } finally {
      calloc.free(cBundle);
      calloc.free(cName);
      calloc.free(err);
    }
  }

  Uint8List encrypt(Pointer<MurihDeviceOpaque> handle, String remoteName, Uint8List plaintext) =>
      _cipher(_encrypt, handle, remoteName, plaintext, 'Could not encrypt the message.');

  Uint8List decrypt(Pointer<MurihDeviceOpaque> handle, String remoteName, Uint8List ciphertext) =>
      _cipher(_decrypt, handle, remoteName, ciphertext, 'Could not decrypt the message.');

  void freeDevice(Pointer<MurihDeviceOpaque> handle) => _freeDevice(handle);

  // ── Helpers ──

  /// Reads an output JSON string, then frees it.
  String _readJsonOut(
    int Function(Pointer<Pointer<Utf8>> out, Pointer<Pointer<Utf8>> err) call,
    String fallback,
  ) {
    final out = calloc<Pointer<Utf8>>();
    final err = calloc<Pointer<Utf8>>();
    try {
      final status = call(out, err);
      if (status != 0) throw _takeError(err, fallback);
      final value = out.value;
      if (value == nullptr) throw E2eeNativeException(fallback);
      try {
        return value.toDartString();
      } finally {
        _stringFree(value);
      }
    } finally {
      calloc.free(out);
      calloc.free(err);
    }
  }

  /// Runs encrypt or decrypt. Copies the Rust buffer into Dart memory, then frees it.
  Uint8List _cipher(
    _CipherDart fn,
    Pointer<MurihDeviceOpaque> handle,
    String remoteName,
    Uint8List input,
    String fallback,
  ) {
    final out = calloc<MurihBytesStruct>();
    final err = calloc<Pointer<Utf8>>();
    final cName = remoteName.toNativeUtf8(allocator: calloc);
    final cInput = calloc<Uint8>(input.isEmpty ? 1 : input.length);
    try {
      if (input.isNotEmpty) cInput.asTypedList(input.length).setAll(0, input);
      final status = fn(handle, cName, cInput, input.length, out, err);
      if (status != 0) throw _takeError(err, fallback);
      final ptr = out.ref.ptr;
      final len = out.ref.len;
      try {
        return len == 0 ? Uint8List(0) : Uint8List.fromList(ptr.asTypedList(len));
      } finally {
        _bytesFree(ptr, len);
      }
    } finally {
      calloc.free(cInput);
      calloc.free(cName);
      calloc.free(err);
      calloc.free(out);
    }
  }

  /// Reads and frees the error string Rust wrote to `err`, if any.
  E2eeNativeException _takeError(Pointer<Pointer<Utf8>> err, String fallback) {
    final value = err.value;
    if (value == nullptr) return E2eeNativeException(fallback);
    try {
      return E2eeNativeException(value.toDartString());
    } finally {
      _stringFree(value);
      err.value = nullptr;
    }
  }
}
