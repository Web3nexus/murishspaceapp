import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/e2ee/e2ee_directory.dart';
import 'package:mobile/core/e2ee/e2ee_service.dart';
import 'package:mobile/core/e2ee/e2ee_vault.dart';

/// End-to-end test of the phone flow with the native library: two users, each with
/// its own service, vault and device, and an in-memory key directory. Needs
/// MURIH_E2EE_LIB, like murih_device_test.dart.
final String? _libraryPath = Platform.environment['MURIH_E2EE_LIB'];
final String? _skip = _libraryPath == null ? 'Set MURIH_E2EE_LIB to libmurih_e2ee.dylib to run' : null;

class _MemoryKeyStore implements E2eeDataKeyStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String base64Key) async => value = base64Key;

  @override
  Future<void> delete() async => value = null;
}

/// Stands in for the key directory. It keeps what the phone uploads, and hands out
/// one-time prekeys once each, as the server does.
class _Registry {
  final Map<int, Map<String, dynamic>> devices = {};
  final Map<int, List<OneTimePrekey>> prekeys = {};
  final Map<int, int> registrations = {};
  final Map<int, List<int>> batchSizes = {};
}

class _FakeDirectory implements E2eeDirectory {
  _FakeDirectory(this.registry, this.owner);

  final _Registry registry;
  final int owner;

  @override
  Future<void> registerDevice({required String deviceUuid, required Map<String, dynamic> bundle}) async {
    registry.registrations[owner] = (registry.registrations[owner] ?? 0) + 1;
    registry.devices[owner] = {...bundle, 'device_uuid': deviceUuid}..remove('one_time_prekey');
  }

  @override
  Future<void> uploadPrekeys(String deviceUuid, List<OneTimePrekey> prekeys) async {
    registry.batchSizes.putIfAbsent(owner, () => []).add(prekeys.length);
    registry.prekeys.putIfAbsent(owner, () => []).addAll(prekeys);
  }

  @override
  Future<List<PeerDeviceBundle>> fetchBundles(int userId) async {
    final device = registry.devices[userId];
    if (device == null) return const [];
    final available = registry.prekeys[userId] ?? [];
    final claimed = available.isEmpty ? null : available.removeAt(0);
    return [
      PeerDeviceBundle.fromJson({
        ...device,
        'one_time_prekey': claimed == null ? null : {'id': claimed.id, 'public_key': claimed.publicKey},
      }),
    ];
  }
}

void main() {
  late Directory dir;
  late _Registry registry;
  late _MemoryKeyStore keys;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('e2ee_service_test');
    registry = _Registry();
    keys = _MemoryKeyStore();
  });

  tearDown(() => dir.deleteSync(recursive: true));

  /// A service as the app builds it. A fresh one, over the same files, models an app restart.
  E2eeService serviceFor(int userId) => E2eeService(
    vault: E2eeVault(keyStore: keys, directory: () async => dir),
    directory: _FakeDirectory(registry, userId),
    libraryPath: _libraryPath,
  );

  group('phone flow', () {
    test('two users exchange encrypted messages through the directory', () async {
      final alice = serviceFor(1);
      final bob = serviceFor(2);
      await alice.ensureRegistered(1);
      await bob.ensureRegistered(2);

      final first = await alice.encryptFor(ownUserId: 1, peerUserId: 2, text: 'hello bob');
      expect(await bob.decryptFrom(ownUserId: 2, senderUserId: 1, ciphertext: first), 'hello bob');

      final reply = await bob.encryptFor(ownUserId: 2, peerUserId: 1, text: 'hi alice');
      expect(await alice.decryptFrom(ownUserId: 1, senderUserId: 2, ciphertext: reply), 'hi alice');
    });

    test('registration uploads the Kyber keys and the one-time prekey', () async {
      await serviceFor(1).ensureRegistered(1);
      final device = registry.devices[1]!;
      expect(device['kyber_prekey_public'], isA<String>());
      expect(device['device_uuid'], matches(RegExp(r'^[0-9a-f-]{36}$')));
      expect(registry.prekeys[1], hasLength(1));
      expect(registry.batchSizes[1], [1]);
    });

    test('ensureRegistered registers once, even across restarts', () async {
      await serviceFor(1).ensureRegistered(1);
      await serviceFor(1).ensureRegistered(1);
      expect(registry.registrations[1], 1);
    });

    test('state survives a restart: the next message still decrypts', () async {
      final alice = serviceFor(1);
      await alice.ensureRegistered(1);
      await serviceFor(2).ensureRegistered(2);

      final bob = serviceFor(2);
      final first = await alice.encryptFor(ownUserId: 1, peerUserId: 2, text: 'one');
      expect(await bob.decryptFrom(ownUserId: 2, senderUserId: 1, ciphertext: first), 'one');

      // New services over the same files, as after an app restart.
      final bobAfterRestart = serviceFor(2);
      final aliceAfterRestart = serviceFor(1);
      final second = await aliceAfterRestart.encryptFor(ownUserId: 1, peerUserId: 2, text: 'two');
      expect(await bobAfterRestart.decryptFrom(ownUserId: 2, senderUserId: 1, ciphertext: second), 'two');
    });

    test('encrypting without a registered device is refused', () async {
      final alice = serviceFor(1);
      await expectLater(
        alice.encryptFor(ownUserId: 1, peerUserId: 2, text: 'hello'),
        throwsA(isA<E2eeException>().having((e) => e.code, 'code', E2eeErrorCode.notReady)),
      );
    });

    test('encrypting to a peer with no device is refused', () async {
      final alice = serviceFor(1);
      await alice.ensureRegistered(1);
      await expectLater(
        alice.encryptFor(ownUserId: 1, peerUserId: 5, text: 'hello'),
        throwsA(isA<E2eeException>().having((e) => e.code, 'code', E2eeErrorCode.peerHasNoDevice)),
      );
    });

    test('a tampered message throws and the device still works afterwards', () async {
      final alice = serviceFor(1);
      final bob = serviceFor(2);
      await alice.ensureRegistered(1);
      await bob.ensureRegistered(2);

      final sealed = base64Decode(await alice.encryptFor(ownUserId: 1, peerUserId: 2, text: 'original'));
      final tampered = Uint8List.fromList(sealed)..[sealed.length - 1] ^= 0x01;
      await expectLater(
        bob.decryptFrom(ownUserId: 2, senderUserId: 1, ciphertext: base64Encode(tampered)),
        throwsA(anything),
      );

      final next = await alice.encryptFor(ownUserId: 1, peerUserId: 2, text: 'next');
      expect(await bob.decryptFrom(ownUserId: 2, senderUserId: 1, ciphertext: next), 'next');
    });

    test('forget removes the stored device for that user', () async {
      final alice = serviceFor(1);
      await alice.ensureRegistered(1);
      await alice.forget(1);
      await expectLater(
        alice.encryptFor(ownUserId: 1, peerUserId: 2, text: 'hello'),
        throwsA(isA<E2eeException>()),
      );
    });
  }, skip: _skip);
}
