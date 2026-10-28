/// Encrypted storage for a device's private state.
library;

///
/// The state (the bridge's `export()` JSON) holds private keys and ratchet state,
/// so it is never written in plaintext. Each save encrypts the state with
/// AES-256-GCM under a random 256-bit data key. The data key lives in
/// flutter_secure_storage (Keychain on iOS, Keystore-backed on Android). The
/// ciphertext lives in the app support directory. Storing the blob in secure
/// storage itself is avoided because of its size limits.
///
/// File format (version 1): [version byte][12-byte nonce][ciphertext || 16-byte tag].
/// The owner id is bound as associated data, so a file cannot be moved to another
/// user's slot without failing authentication.
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pointycastle/export.dart';

class E2eeVaultException implements Exception {
  E2eeVaultException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Holds the 256-bit data key, outside the app's files.
abstract class E2eeDataKeyStore {
  Future<String?> read();
  Future<void> write(String base64Key);
  Future<void> delete();
}

class SecureE2eeDataKeyStore implements E2eeDataKeyStore {
  const SecureE2eeDataKeyStore();

  static const _keyName = 'murihspace_e2ee_data_key';
  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  @override
  Future<String?> read() => _storage.read(key: _keyName);

  @override
  Future<void> write(String base64Key) => _storage.write(key: _keyName, value: base64Key);

  @override
  Future<void> delete() => _storage.delete(key: _keyName);
}

class E2eeVault {
  E2eeVault({
    required this.keyStore,
    Future<Directory> Function()? directory,
    Random? random,
  })  : _directory = directory ?? _defaultDirectory,
        _random = random ?? Random.secure();

  final E2eeDataKeyStore keyStore;
  final Future<Directory> Function() _directory;
  final Random _random;

  static const _formatVersion = 1;
  static const _nonceBytes = 12;
  static const _tagBits = 128;
  static const _keyBytes = 32;

  Uint8List? _cachedKey;

  static Future<Directory> _defaultDirectory() async {
    final support = await getApplicationSupportDirectory();
    return Directory('${support.path}${Platform.pathSeparator}e2ee');
  }

  /// [owner] is the local user id as a string. Only letters, digits, `_` and `-` are allowed.
  static final _ownerPattern = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

  Future<File> _fileFor(String owner) async {
    if (!_ownerPattern.hasMatch(owner)) {
      throw E2eeVaultException('Invalid owner for encrypted device state.');
    }
    final dir = await _directory();
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('${dir.path}${Platform.pathSeparator}device_$owner.bin');
  }

  Uint8List _aad(String owner) => Uint8List.fromList(utf8.encode('murihspace-e2ee-device:$owner'));

  /// Returns the data key, creating it on first use when [create] is true.
  Future<Uint8List?> _dataKey({required bool create}) async {
    final cached = _cachedKey;
    if (cached != null) return cached;
    final stored = await keyStore.read();
    if (stored != null) {
      final decoded = base64Decode(stored);
      if (decoded.length != _keyBytes) {
        throw E2eeVaultException('The encryption data key is damaged.');
      }
      return _cachedKey = Uint8List.fromList(decoded);
    }
    if (!create) return null;
    final fresh = Uint8List.fromList(List<int>.generate(_keyBytes, (_) => _random.nextInt(256)));
    await keyStore.write(base64Encode(fresh));
    return _cachedKey = fresh;
  }

  /// Encrypts and atomically writes [plaintext] for [owner].
  Future<void> save(String owner, String plaintext) async {
    final key = (await _dataKey(create: true))!;
    final nonce = Uint8List.fromList(List<int>.generate(_nonceBytes, (_) => _random.nextInt(256)));
    final cipher = GCMBlockCipher(AESEngine())
      ..init(true, AEADParameters(KeyParameter(key), _tagBits, nonce, _aad(owner)));
    final sealed = cipher.process(Uint8List.fromList(utf8.encode(plaintext)));

    final out = BytesBuilder(copy: false)
      ..addByte(_formatVersion)
      ..add(nonce)
      ..add(sealed);

    final file = await _fileFor(owner);
    final temp = File('${file.path}.tmp');
    await temp.writeAsBytes(out.toBytes(), flush: true);
    await temp.rename(file.path);
  }

  /// Returns the decrypted state for [owner], or null when none is stored.
  /// Throws [E2eeVaultException] if the data is damaged or was tampered with.
  Future<String?> load(String owner) async {
    final file = await _fileFor(owner);
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    if (bytes.length < 1 + _nonceBytes + _tagBits ~/ 8 || bytes[0] != _formatVersion) {
      throw E2eeVaultException('Unsupported encrypted device state.');
    }
    final key = await _dataKey(create: false);
    if (key == null) {
      throw E2eeVaultException('The encryption data key is missing.');
    }
    final nonce = Uint8List.sublistView(bytes, 1, 1 + _nonceBytes);
    final sealed = Uint8List.sublistView(bytes, 1 + _nonceBytes);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(false, AEADParameters(KeyParameter(key), _tagBits, nonce, _aad(owner)));
    try {
      return utf8.decode(cipher.process(sealed));
    } on InvalidCipherTextException {
      throw E2eeVaultException('The encrypted device state could not be authenticated.');
    }
  }

  /// Removes the stored state for [owner]. The data key is kept for other users.
  Future<void> delete(String owner) async {
    final file = await _fileFor(owner);
    if (await file.exists()) await file.delete();
  }
}
