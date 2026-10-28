import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/e2ee/murih_device.dart';

/// These tests load the native murih-e2ee library. Build it from the web repo's
/// e2ee-bridge (`cargo build --release --features ffi`) and point MURIH_E2EE_LIB at the
/// result. Without that variable the group is skipped.
final String? _libraryPath = Platform.environment['MURIH_E2EE_LIB'];
final String? _skip = _libraryPath == null ? 'Set MURIH_E2EE_LIB to libmurih_e2ee.dylib to run' : null;

Uint8List _bytes(String text) => Uint8List.fromList(utf8.encode(text));
String _text(Uint8List bytes) => utf8.decode(bytes);

E2eeDevice _create(String name, {int registrationId = 1234, int prekeys = 5}) => E2eeDevice.create(
  name: name,
  registrationId: registrationId,
  prekeyCount: prekeys,
  libraryPath: _libraryPath,
);

void main() {
  group('native device exchange', () {
    test('two devices exchange messages both ways', () {
      final alice = _create('user:1');
      final bob = _create('user:2');
      addTearDown(() {
        alice.close();
        bob.close();
      });

      alice.startSession('user:2', bob.publicBundle());
      final first = alice.encrypt('user:2', _bytes('hello bob'));
      expect(_text(bob.decrypt('user:1', first)), 'hello bob');

      final reply = bob.encrypt('user:1', _bytes('hi alice'));
      expect(_text(alice.decrypt('user:2', reply)), 'hi alice');

      final second = alice.encrypt('user:2', _bytes('second message'));
      expect(_text(bob.decrypt('user:1', second)), 'second message');
    });

    test('empty plaintext round-trips', () {
      final alice = _create('user:1');
      final bob = _create('user:2');
      addTearDown(() {
        alice.close();
        bob.close();
      });
      alice.startSession('user:2', bob.publicBundle());
      final sealed = alice.encrypt('user:2', Uint8List(0));
      expect(bob.decrypt('user:1', sealed), isEmpty);
    });

    test('bundle has the directory shape with a Kyber key and one-time prekey', () {
      final bob = _create('user:2');
      addTearDown(bob.close);
      final bundle = jsonDecode(bob.publicBundle()) as Map<String, dynamic>;
      expect(
        bundle.keys,
        containsAll([
          'registration_id',
          'identity_key',
          'signed_prekey_id',
          'signed_prekey_public',
          'signed_prekey_signature',
          'kyber_prekey_id',
          'kyber_prekey_public',
          'kyber_prekey_signature',
          'one_time_prekey',
        ]),
      );
      expect(bundle['registration_id'], 1234);
      expect((bundle['kyber_prekey_public'] as String).length, greaterThan(2000));
      expect((bundle['one_time_prekey'] as Map)['id'], isA<int>());
    });

    test('a session starts from a bundle with no one-time prekey', () {
      final alice = _create('user:1');
      final bob = _create('user:2', prekeys: 0);
      addTearDown(() {
        alice.close();
        bob.close();
      });
      final bundle = jsonDecode(bob.publicBundle()) as Map<String, dynamic>;
      expect(bundle['one_time_prekey'], isNull);

      alice.startSession('user:2', bob.publicBundle());
      final sealed = alice.encrypt('user:2', _bytes('no one-time key'));
      expect(_text(bob.decrypt('user:1', sealed)), 'no one-time key');
    });

    test('restoring from export keeps sessions working', () {
      final alice = _create('user:1');
      final bob = _create('user:2');
      addTearDown(() {
        alice.close();
      });
      alice.startSession('user:2', bob.publicBundle());
      expect(_text(bob.decrypt('user:1', alice.encrypt('user:2', _bytes('before')))), 'before');

      final state = bob.export();
      bob.close();
      final restored = E2eeDevice.restore(name: 'user:2', stateJson: state, libraryPath: _libraryPath);
      addTearDown(restored.close);

      expect(_text(restored.decrypt('user:1', alice.encrypt('user:2', _bytes('after restore')))), 'after restore');
    });

    test('a tampered ciphertext is rejected', () {
      final alice = _create('user:1');
      final bob = _create('user:2');
      addTearDown(() {
        alice.close();
        bob.close();
      });
      alice.startSession('user:2', bob.publicBundle());
      final sealed = alice.encrypt('user:2', _bytes('do not change me'));
      final tampered = Uint8List.fromList(sealed);
      tampered[tampered.length - 1] ^= 0x01;
      expect(() => bob.decrypt('user:1', tampered), throwsA(isA<E2eeNativeException>()));
    });

    test('a closed device refuses further use and closing twice is safe', () {
      final device = _create('user:9');
      device.close();
      device.close();
      expect(device.isClosed, isTrue);
      expect(device.export, throwsStateError);
    });
  }, skip: _skip);
}
