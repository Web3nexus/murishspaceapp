import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/providers/security_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _legacyHash(String pin) =>
    sha256.convert(utf8.encode(pin + 'murih_space_salt_2026')).toString();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('PBKDF2-HMAC-SHA256 matches the published test vector', () {
    final out = pbkdf2HmacSha256(
      utf8.encode('password'),
      utf8.encode('salt'),
      1,
      32,
    );
    expect(
      out.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
      '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b',
    );
  });

  test('a new PIN verifies and a wrong PIN fails', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(securityProvider.notifier);

    await notifier.setPin('123456');
    expect(await notifier.verifyPin('123456'), true);
    expect(await notifier.verifyPin('654321'), false);

    final stored = await const FlutterSecureStorage().read(key: 'app_pin_hash');
    expect(stored, startsWith('pbkdf2-sha256\$210000\$'));
    expect(stored, isNot(contains('123456')));
  });

  test('a legacy SHA-256 hash verifies once and is then upgraded', () async {
    FlutterSecureStorage.setMockInitialValues({
      'app_pin_hash': _legacyHash('246810'),
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(securityProvider.notifier);

    expect(await notifier.verifyPin('000000'), false);
    expect(
      await const FlutterSecureStorage().read(key: 'app_pin_hash'),
      _legacyHash('246810'),
      reason: 'a wrong PIN must not rewrite the stored hash',
    );

    expect(await notifier.verifyPin('246810'), true);
    final upgraded = await const FlutterSecureStorage().read(
      key: 'app_pin_hash',
    );
    expect(upgraded, startsWith('pbkdf2-sha256\$'));

    // The upgraded value keeps working, and the legacy check is no longer used.
    expect(await notifier.verifyPin('246810'), true);
    expect(
      await const FlutterSecureStorage().read(key: 'app_pin_hash'),
      upgraded,
    );
  });

  test('two hashes of the same PIN differ because the salt differs', () {
    final a = hashPinForStorage('135790', random: Random(1));
    final b = hashPinForStorage('135790', random: Random(2));
    final c = hashPinForStorage('135790');
    final d = hashPinForStorage('135790');

    expect(a, isNot(b));
    expect(c, isNot(d));
    expect(verifyPbkdf2PinHash('135790', a), true);
    expect(verifyPbkdf2PinHash('135790', b), true);
    expect(verifyPbkdf2PinHash('135791', a), false);
  });

  test('isolate path gives the same verification result as the sync path', () async {
    final stored = hashPinForStorage('579135', random: Random(7));

    for (final pin in ['579135', '579136', '']) {
      expect(
        await verifyPbkdf2PinHashAsync(pin, stored),
        verifyPbkdf2PinHash(pin, stored),
        reason: 'pin "$pin"',
      );
    }
    expect(await verifyPbkdf2PinHashAsync('579135', stored), true);

    final malformed = [
      'pbkdf2-sha256\$abc\$AAAA\$AAAA',
      'pbkdf2-sha256\$1000\$not base64!\$AAAA',
      'pbkdf2-sha256\$1000\$AAAA',
    ];
    for (final value in malformed) {
      expect(await verifyPbkdf2PinHashAsync('1234', value), false, reason: value);
    }
  });

  test('isolate hashing output is verifiable by the sync path and stays in format', () async {
    final hashed = await hashPinForStorageAsync('314159', random: Random(3));

    expect(hashed, startsWith('pbkdf2-sha256\$210000\$'));
    expect(verifyPbkdf2PinHash('314159', hashed), true);
    expect(verifyPbkdf2PinHash('314158', hashed), false);
    expect(await verifyPbkdf2PinHashAsync('314159', hashed), true);

    // Same salt and PIN give the same stored value on both paths.
    expect(
      hashed,
      hashPinForStorage('314159', random: Random(3)),
    );
  });

  test('malformed PBKDF2 values fail closed', () {
    expect(
      verifyPbkdf2PinHash('1234', 'pbkdf2-sha256\$abc\$AAAA\$AAAA'),
      false,
    );
    expect(
      verifyPbkdf2PinHash('1234', 'pbkdf2-sha256\$1000\$not base64!\$AAAA'),
      false,
    );
    expect(verifyPbkdf2PinHash('1234', 'pbkdf2-sha256\$1000\$AAAA'), false);
  });
}
