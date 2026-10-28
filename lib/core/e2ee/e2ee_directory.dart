/// HTTP calls to the end-to-end encryption key directory. Only public keys cross this boundary.
/// Requests go through the shared [ApiClient], so they carry the same bearer token as the rest of the app.
library;

import 'dart:convert';

import '../api_client.dart';

/// The backend accepts at most this many one-time prekeys per upload.
const int maxPrekeysPerUpload = 100;

class OneTimePrekey {
  const OneTimePrekey({required this.id, required this.publicKey});

  final int id;
  final String publicKey;

  factory OneTimePrekey.fromJson(Map<String, dynamic> json) => OneTimePrekey(
    id: (json['id'] as num).toInt(),
    publicKey: json['public_key'] as String,
  );
}

/// One device of a user, as the key directory returns it. [oneTimePrekey] is null when
/// the device has none left. A session can still start from the signed prekey.
class PeerDeviceBundle {
  const PeerDeviceBundle({
    required this.deviceUuid,
    required this.registrationId,
    required this.identityKey,
    required this.signedPrekeyId,
    required this.signedPrekeyPublic,
    required this.signedPrekeySignature,
    required this.kyberPrekeyId,
    required this.kyberPrekeyPublic,
    required this.kyberPrekeySignature,
    required this.oneTimePrekey,
  });

  final String deviceUuid;
  final int registrationId;
  final String identityKey;
  final int signedPrekeyId;
  final String signedPrekeyPublic;
  final String signedPrekeySignature;
  final int kyberPrekeyId;
  final String kyberPrekeyPublic;
  final String kyberPrekeySignature;
  final OneTimePrekey? oneTimePrekey;

  factory PeerDeviceBundle.fromJson(Map<String, dynamic> json) {
    final oneTime = json['one_time_prekey'];
    return PeerDeviceBundle(
      deviceUuid: json['device_uuid'] as String,
      registrationId: (json['registration_id'] as num).toInt(),
      identityKey: json['identity_key'] as String,
      signedPrekeyId: (json['signed_prekey_id'] as num).toInt(),
      signedPrekeyPublic: json['signed_prekey_public'] as String,
      signedPrekeySignature: json['signed_prekey_signature'] as String,
      kyberPrekeyId: (json['kyber_prekey_id'] as num).toInt(),
      kyberPrekeyPublic: json['kyber_prekey_public'] as String,
      kyberPrekeySignature: json['kyber_prekey_signature'] as String,
      oneTimePrekey: oneTime is Map<String, dynamic> ? OneTimePrekey.fromJson(oneTime) : null,
    );
  }

  /// The bundle in the shape the bridge's `startSession` reads.
  String toBridgeJson() {
    final oneTime = oneTimePrekey;
    return jsonEncode({
    'registration_id': registrationId,
    'identity_key': identityKey,
    'signed_prekey_id': signedPrekeyId,
    'signed_prekey_public': signedPrekeyPublic,
    'signed_prekey_signature': signedPrekeySignature,
    'kyber_prekey_id': kyberPrekeyId,
    'kyber_prekey_public': kyberPrekeyPublic,
    'kyber_prekey_signature': kyberPrekeySignature,
      'one_time_prekey': oneTime == null ? null : {'id': oneTime.id, 'public_key': oneTime.publicKey},
    });
  }
}

/// Splits [prekeys] into upload batches of at most [maxPrekeysPerUpload].
List<List<OneTimePrekey>> chunkPrekeys(List<OneTimePrekey> prekeys, {int size = maxPrekeysPerUpload}) {
  if (size <= 0) throw ArgumentError.value(size, 'size', 'must be positive');
  return [
    for (var start = 0; start < prekeys.length; start += size)
      prekeys.sublist(start, start + size > prekeys.length ? prekeys.length : start + size),
  ];
}

class E2eeDirectory {
  E2eeDirectory(this._api);

  final ApiClient _api;

  /// Registers this device's public keys. [bundle] is the bridge's public bundle.
  Future<void> registerDevice({required String deviceUuid, required Map<String, dynamic> bundle}) async {
    final response = await _api.post(
      '/e2ee/devices',
      data: {
        'device_uuid': deviceUuid,
        'registration_id': bundle['registration_id'],
        'identity_key': bundle['identity_key'],
        'signed_prekey_id': bundle['signed_prekey_id'],
        'signed_prekey_public': bundle['signed_prekey_public'],
        'signed_prekey_signature': bundle['signed_prekey_signature'],
        'kyber_prekey_id': bundle['kyber_prekey_id'],
        'kyber_prekey_public': bundle['kyber_prekey_public'],
        'kyber_prekey_signature': bundle['kyber_prekey_signature'],
      },
    );
    _api.unwrap(response);
  }

  /// Uploads one-time prekeys in batches of at most 100.
  Future<void> uploadPrekeys(String deviceUuid, List<OneTimePrekey> prekeys) async {
    for (final batch in chunkPrekeys(prekeys)) {
      final response = await _api.post(
        '/e2ee/devices/${Uri.encodeComponent(deviceUuid)}/prekeys',
        data: {
          'prekeys': [
            for (final prekey in batch) {'key_id': prekey.id, 'public_key': prekey.publicKey},
          ],
        },
      );
      _api.unwrap(response);
    }
  }

  /// Every device of [userId]. Each one-time prekey is claimed by this request.
  Future<List<PeerDeviceBundle>> fetchBundles(int userId) async {
    final response = await _api.get('/e2ee/users/$userId/bundles');
    final payload = _api.unwrap(response);
    if (payload is! List) return const [];
    return [
      for (final item in payload)
        if (item is Map<String, dynamic>) PeerDeviceBundle.fromJson(item),
    ];
  }
}
