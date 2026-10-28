import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/e2ee/e2ee_vault.dart';

class _MemoryKeyStore implements E2eeDataKeyStore {
  String? value;
  int writes = 0;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String base64Key) async {
    writes += 1;
    value = base64Key;
  }

  @override
  Future<void> delete() async => value = null;
}

void main() {
  late Directory dir;
  late _MemoryKeyStore keys;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('e2ee_vault_test');
    keys = _MemoryKeyStore();
  });

  tearDown(() => dir.deleteSync(recursive: true));

  E2eeVault vault() => E2eeVault(keyStore: keys, directory: () async => dir);

  test('save then load returns the same state', () async {
    await vault().save('42', '{"state":"private keys here"}');
    expect(await vault().load('42'), '{"state":"private keys here"}');
  });

  test('the file on disk is not plaintext', () async {
    await vault().save('42', 'PLAINTEXT-MARKER-123');
    final file = File('${dir.path}/device_42.bin');
    expect(file.existsSync(), isTrue);
    expect(utf8.decode(file.readAsBytesSync(), allowMalformed: true), isNot(contains('PLAINTEXT-MARKER-123')));
  });

  test('the data key is created once and reused', () async {
    await vault().save('1', 'a');
    await vault().save('2', 'b');
    expect(keys.writes, 1);
    expect(await vault().load('1'), 'a');
  });

  test('a missing device returns null', () async {
    expect(await vault().load('99'), isNull);
  });

  test('a file copied to another owner fails authentication', () async {
    await vault().save('42', 'secret');
    File('${dir.path}/device_42.bin').copySync('${dir.path}/device_43.bin');
    await expectLater(vault().load('43'), throwsA(isA<E2eeVaultException>()));
  });

  test('a tampered file fails authentication', () async {
    await vault().save('42', 'secret');
    final file = File('${dir.path}/device_42.bin');
    final bytes = file.readAsBytesSync();
    bytes[bytes.length - 1] ^= 0x01;
    file.writeAsBytesSync(bytes);
    await expectLater(vault().load('42'), throwsA(isA<E2eeVaultException>()));
  });

  test('delete removes the stored state', () async {
    await vault().save('42', 'secret');
    await vault().delete('42');
    expect(await vault().load('42'), isNull);
  });

  test('an owner id outside the allowed pattern is refused', () async {
    await expectLater(vault().save('../evil', 'x'), throwsA(isA<E2eeVaultException>()));
  });
}
