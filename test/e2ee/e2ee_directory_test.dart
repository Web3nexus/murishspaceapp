import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/e2ee/e2ee_directory.dart';

Map<String, dynamic> _bundleJson({Map<String, dynamic>? oneTime}) => {
  'device_uuid': 'device-bob',
  'registration_id': 77,
  'identity_key': 'ik',
  'signed_prekey_id': 1,
  'signed_prekey_public': 'spk',
  'signed_prekey_signature': 'sig',
  'kyber_prekey_id': 1,
  'kyber_prekey_public': 'kpk',
  'kyber_prekey_signature': 'ksig',
  'one_time_prekey': oneTime,
};

void main() {
  group('chunkPrekeys', () {
    List<OneTimePrekey> prekeys(int count) => [
      for (var i = 1; i <= count; i++) OneTimePrekey(id: i, publicKey: 'pk$i'),
    ];

    test('splits into batches of at most 100', () {
      final batches = chunkPrekeys(prekeys(250));
      expect(batches.map((b) => b.length), [100, 100, 50]);
      expect(batches.expand((b) => b).map((p) => p.id), [for (var i = 1; i <= 250; i++) i]);
    });

    test('an empty list gives no batches', () {
      expect(chunkPrekeys(const []), isEmpty);
    });

    test('a list of exactly 100 gives one batch', () {
      expect(chunkPrekeys(prekeys(100)).length, 1);
    });
  });

  group('PeerDeviceBundle', () {
    test('parses the directory shape and maps to the bridge shape', () {
      final bundle = PeerDeviceBundle.fromJson(_bundleJson(oneTime: {'id': 9, 'public_key': 'opk'}));
      expect(bundle.oneTimePrekey?.id, 9);

      final bridge = jsonDecode(bundle.toBridgeJson()) as Map<String, dynamic>;
      expect(bridge['registration_id'], 77);
      expect(bridge['kyber_prekey_public'], 'kpk');
      expect(bridge['one_time_prekey'], {'id': 9, 'public_key': 'opk'});
      expect(bridge.containsKey('device_uuid'), isFalse);
    });

    test('a null one-time prekey stays null in the bridge shape', () {
      final bundle = PeerDeviceBundle.fromJson(_bundleJson());
      expect(bundle.oneTimePrekey, isNull);
      final bridge = jsonDecode(bundle.toBridgeJson()) as Map<String, dynamic>;
      expect(bridge['one_time_prekey'], isNull);
    });
  });
}
