/// This phone's end-to-end encryption device, used by the chat send and receive paths.
///
/// One device per signed-in user per install. Every operation runs one at a time,
/// because each one moves the ratchet forward. The device state is saved (encrypted)
/// after every operation, before its result is returned, so a crash cannot leave the
/// ratchet behind the messages already sent or shown.
library;

import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api_client.dart';
import 'e2ee_directory.dart';
import 'e2ee_vault.dart';
import 'murih_device.dart';

export 'murih_device.dart' show E2eeNativeException;

const int _stateVersion = 1;

/// Prekeys generated at creation, as the web client does. The bridge exposes only the
/// first one in its public bundle today, so only that one is uploaded.
const int _prekeyCount = 20;

enum E2eeErrorCode { notReady, peerHasNoDevice }

class E2eeException implements Exception {
  E2eeException(this.code, this.message);
  final E2eeErrorCode code;
  final String message;

  @override
  String toString() => message;
}

/// Protocol address of a user's device. The bridge keys sessions by this name.
String protocolNameFor(int userId) => 'user:$userId';

/// Creates the device state on a background isolate, since key generation is slow.
String _createDeviceState(String name, int registrationId, int prekeyCount, String? libraryPath) {
  final device = E2eeDevice.create(
    name: name,
    registrationId: registrationId,
    prekeyCount: prekeyCount,
    libraryPath: libraryPath,
  );
  try {
    return device.export();
  } finally {
    device.close();
  }
}

class _LocalDevice {
  _LocalDevice({
    required this.userId,
    required this.deviceUuid,
    required this.registered,
    required this.device,
    required this.sessionPeers,
  });

  final int userId;
  final String deviceUuid;
  bool registered;
  final E2eeDevice device;
  final Set<int> sessionPeers;
}

class E2eeService {
  E2eeService({
    required E2eeVault vault,
    required E2eeDirectory directory,
    this.libraryPath,
    Random? random,
  })  : _vault = vault,
        _directory = directory,
        _random = random ?? Random.secure();

  final E2eeVault _vault;
  final E2eeDirectory _directory;
  final Random _random;

  /// Set only by tests, which load the host dylib. Null in the app.
  final String? libraryPath;

  _LocalDevice? _current;
  Future<void> _queue = Future.value();

  /// Runs [task] after every earlier operation has finished.
  Future<T> _serialized<T>(Future<T> Function() task) {
    final run = _queue.then((_) => task());
    _queue = run.then<void>((_) {}, onError: (_) {});
    return run;
  }

  String _newDeviceUuid() {
    final bytes = Uint8List.fromList(List<int>.generate(16, (_) => _random.nextInt(256)));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  /// Loads the device for [userId] from the vault, or creates it when [create] is true.
  /// Returns null when there is no device and [create] is false.
  Future<_LocalDevice?> _open(int userId, {required bool create}) async {
    final loaded = _current;
    if (loaded != null && loaded.userId == userId) return loaded;

    final stored = await _vault.load(userId.toString());
    if (stored == null && !create) return null;

    final String stateJson;
    final _StoredDevice record;
    if (stored == null) {
      final registrationId = 1 + _random.nextInt(16380);
      // Locals only: a closure over `this` cannot be sent to the isolate.
      final path = libraryPath;
      stateJson = await Isolate.run(
        () => _createDeviceState(protocolNameFor(userId), registrationId, _prekeyCount, path),
      );
      record = _StoredDevice(deviceUuid: _newDeviceUuid(), registered: false, state: stateJson, sessionPeers: const []);
    } else {
      record = _StoredDevice.fromJson(stored);
    }

    final device = E2eeDevice.restore(
      name: protocolNameFor(userId),
      stateJson: record.state,
      libraryPath: libraryPath,
    );
    _current?.device.close();
    final local = _LocalDevice(
      userId: userId,
      deviceUuid: record.deviceUuid,
      registered: record.registered,
      device: device,
      sessionPeers: record.sessionPeers.toSet(),
    );
    _current = local;
    if (stored == null) await _save(local);
    return local;
  }

  /// Writes the current device state, encrypted. Call after every operation that changes it.
  Future<void> _save(_LocalDevice local) {
    final record = _StoredDevice(
      deviceUuid: local.deviceUuid,
      registered: local.registered,
      state: local.device.export(),
      sessionPeers: local.sessionPeers.toList()..sort(),
    );
    return _vault.save(local.userId.toString(), jsonEncode(record.toJson()));
  }

  /// Makes sure [userId] has a device and that its public keys are in the directory.
  /// Creates the device on first use. Safe to call repeatedly.
  Future<void> ensureRegistered(int userId) => _serialized(() async {
    final local = (await _open(userId, create: true))!;
    if (local.registered) return;
    try {
      final bundle = jsonDecode(local.device.publicBundle()) as Map<String, dynamic>;
      await _directory.registerDevice(deviceUuid: local.deviceUuid, bundle: bundle);
      final oneTime = bundle['one_time_prekey'];
      if (oneTime is Map<String, dynamic>) {
        await _directory.uploadPrekeys(
          local.deviceUuid,
          [OneTimePrekey.fromJson(oneTime)],
        );
      }
      local.registered = true;
    } finally {
      await _save(local);
    }
  });

  /// Encrypts [text] for [peerUserId] as [ownUserId]. Returns base64 ciphertext for the server.
  /// Starts a session from the peer's directory bundle when there is none yet.
  Future<String> encryptFor({
    required int ownUserId,
    required int peerUserId,
    required String text,
  }) => _serialized(() async {
    final local = await _open(ownUserId, create: false);
    if (local == null || !local.registered) {
      throw E2eeException(E2eeErrorCode.notReady, 'End-to-end encryption is not ready on this device.');
    }
    try {
      if (!local.sessionPeers.contains(peerUserId)) {
        final bundles = await _directory.fetchBundles(peerUserId);
        if (bundles.isEmpty) {
          throw E2eeException(E2eeErrorCode.peerHasNoDevice, 'The recipient has no encryption device yet.');
        }
        // The newest device is the one most likely in use. Prefer one with a one-time prekey.
        final target = bundles.lastWhere(
          (bundle) => bundle.oneTimePrekey != null,
          orElse: () => bundles.last,
        );
        local.device.startSession(protocolNameFor(peerUserId), target.toBridgeJson());
        local.sessionPeers.add(peerUserId);
      }
      final sealed = local.device.encrypt(protocolNameFor(peerUserId), Uint8List.fromList(utf8.encode(text)));
      return base64Encode(sealed);
    } finally {
      await _save(local);
    }
  });

  /// Decrypts base64 [ciphertext] from [senderUserId] as [ownUserId].
  /// Throws if this device cannot read it. Callers show a placeholder in that case.
  Future<String> decryptFrom({
    required int ownUserId,
    required int senderUserId,
    required String ciphertext,
  }) => _serialized(() async {
    final local = await _open(ownUserId, create: false);
    if (local == null) {
      throw E2eeException(E2eeErrorCode.notReady, 'End-to-end encryption is not set up on this device.');
    }
    try {
      final plain = local.device.decrypt(protocolNameFor(senderUserId), base64Decode(ciphertext));
      local.sessionPeers.add(senderUserId);
      return utf8.decode(plain);
    } finally {
      await _save(local);
    }
  });

  /// Drops the device for [userId] from memory and from disk. Used on sign-out.
  /// The directory still lists the device; there is no delete endpoint yet.
  Future<void> forget(int userId) => _serialized(() async {
    final local = _current;
    if (local != null && local.userId == userId) {
      local.device.close();
      _current = null;
    }
    await _vault.delete(userId.toString());
  });
}

/// The vault payload for one device. Versioned so the format can change later.
class _StoredDevice {
  const _StoredDevice({
    required this.deviceUuid,
    required this.registered,
    required this.state,
    required this.sessionPeers,
  });

  final String deviceUuid;
  final bool registered;
  final String state;
  final List<int> sessionPeers;

  factory _StoredDevice.fromJson(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    if (json['v'] != _stateVersion) {
      throw E2eeVaultException('Unsupported encrypted device state version.');
    }
    return _StoredDevice(
      deviceUuid: json['deviceUuid'] as String,
      registered: json['registered'] as bool,
      state: json['state'] as String,
      sessionPeers: [for (final peer in json['sessionPeers'] as List) (peer as num).toInt()],
    );
  }

  Map<String, dynamic> toJson() => {
    'v': _stateVersion,
    'deviceUuid': deviceUuid,
    'registered': registered,
    'state': state,
    'sessionPeers': sessionPeers,
  };
}

final e2eeServiceProvider = Provider<E2eeService>((ref) {
  return E2eeService(
    vault: E2eeVault(keyStore: const SecureE2eeDataKeyStore()),
    directory: E2eeDirectory(ApiClient.instance),
  );
});
