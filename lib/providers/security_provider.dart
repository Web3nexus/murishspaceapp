import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/key_derivators/api.dart';
import 'package:pointycastle/key_derivators/pbkdf2.dart';
import 'package:pointycastle/macs/hmac.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecurityState {
  final bool isInitialized;
  final bool isLocked;
  final bool isPinSet;
  final bool isTransactionPinSet;
  final bool useBiometrics;
  final int lockTimeoutMinutes;
  final List<BiometricType> availableBiometrics;
  final bool isBiometricHardwareAvailable;
  final int failedPinAttempts;
  final DateTime? lockoutUntil;

  SecurityState({
    this.isInitialized = false,
    this.isLocked = false,
    this.isPinSet = false,
    this.isTransactionPinSet = false,
    this.useBiometrics = false,
    this.lockTimeoutMinutes = 1,
    this.availableBiometrics = const [],
    this.isBiometricHardwareAvailable = false,
    this.failedPinAttempts = 0,
    this.lockoutUntil,
  });

  bool get isLockedOut =>
      lockoutUntil != null && DateTime.now().isBefore(lockoutUntil!);

  int get remainingLockoutSeconds {
    if (lockoutUntil == null) return 0;
    final diff = lockoutUntil!.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  String get biometricLabel {
    if (availableBiometrics.contains(BiometricType.face)) {
      return 'Face ID';
    } else if (availableBiometrics.contains(BiometricType.fingerprint)) {
      return 'Fingerprint';
    } else if (availableBiometrics.contains(BiometricType.iris)) {
      return 'Iris Scanner';
    }
    return 'Biometrics';
  }

  SecurityState copyWith({
    bool? isInitialized,
    bool? isLocked,
    bool? isPinSet,
    bool? isTransactionPinSet,
    bool? useBiometrics,
    int? lockTimeoutMinutes,
    List<BiometricType>? availableBiometrics,
    bool? isBiometricHardwareAvailable,
    int? failedPinAttempts,
    DateTime? lockoutUntil,
    bool clearLockout = false,
  }) {
    return SecurityState(
      isInitialized: isInitialized ?? this.isInitialized,
      isLocked: isLocked ?? this.isLocked,
      isPinSet: isPinSet ?? this.isPinSet,
      isTransactionPinSet: isTransactionPinSet ?? this.isTransactionPinSet,
      useBiometrics: useBiometrics ?? this.useBiometrics,
      lockTimeoutMinutes: lockTimeoutMinutes ?? this.lockTimeoutMinutes,
      availableBiometrics: availableBiometrics ?? this.availableBiometrics,
      isBiometricHardwareAvailable:
          isBiometricHardwareAvailable ?? this.isBiometricHardwareAvailable,
      failedPinAttempts: failedPinAttempts ?? this.failedPinAttempts,
      lockoutUntil: clearLockout ? null : (lockoutUntil ?? this.lockoutUntil),
    );
  }
}

class SecurityNotifier extends Notifier<SecurityState> {
  final _secureStorage = const FlutterSecureStorage();
  final _localAuth = LocalAuthentication();

  DateTime? _lastActiveTime;
  DateTime? _lastPeriodicCheck;

  @override
  SecurityState build() {
    _init();
    return SecurityState();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted) return;

    final pinHash = await _secureStorage.read(key: 'app_pin_hash');
    if (!ref.mounted) return;
    final isPinSet = pinHash != null && pinHash.isNotEmpty;

    final txnPinHash = await _secureStorage.read(key: 'txn_pin_hash');
    if (!ref.mounted) return;
    final isTransactionPinSet = txnPinHash != null && txnPinHash.isNotEmpty;

    final useBiometrics = prefs.getBool('use_biometrics') ?? false;
    final lockTimeoutMinutes = prefs.getInt('lock_timeout_minutes') ?? 1;

    // Check hardware biometrics
    bool isBiometricAvailable = false;
    List<BiometricType> biometrics = [];
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      isBiometricAvailable = canCheck || isSupported;
      if (isBiometricAvailable) {
        biometrics = await _localAuth.getAvailableBiometrics();
      }
    } catch (_) {}

    if (!ref.mounted) return;

    final lastCheckStr = prefs.getString('last_periodic_check');
    if (lastCheckStr != null) {
      _lastPeriodicCheck = DateTime.tryParse(lastCheckStr);
    } else {
      _lastPeriodicCheck = DateTime.now();
      await prefs.setString(
        'last_periodic_check',
        _lastPeriodicCheck!.toIso8601String(),
      );
    }

    if (!ref.mounted) return;

    state = state.copyWith(
      isInitialized: true,
      isPinSet: isPinSet,
      isTransactionPinSet: isTransactionPinSet,
      useBiometrics: useBiometrics,
      lockTimeoutMinutes: lockTimeoutMinutes,
      availableBiometrics: biometrics,
      isBiometricHardwareAvailable: isBiometricAvailable,
    );
  }

  Future<void> setTransactionPin(String newPin) async {
    final hash = await _hashPin(newPin);
    await _secureStorage.write(key: 'txn_pin_hash', value: hash);
    if (ref.mounted) {
      state = state.copyWith(isTransactionPinSet: true);
    }
  }

  Future<bool> verifyTransactionPin(String pin) async {
    if (state.isLockedOut) return false;

    final storedHash = await _secureStorage.read(key: 'txn_pin_hash');
    if (storedHash == null) return false;

    final isCorrect = await _checkPinAndMigrate(
      pin,
      storedHash,
      'txn_pin_hash',
    );
    if (isCorrect) {
      if (ref.mounted) {
        state = state.copyWith(failedPinAttempts: 0, clearLockout: true);
      }
      return true;
    } else {
      _handleFailedAttempt();
      return false;
    }
  }

  void onAppBackgrounded() {
    if (!state.isPinSet) return;
    _lastActiveTime = DateTime.now();
  }

  void onAppForegrounded() {
    if (!state.isPinSet) return;

    final now = DateTime.now();

    if (_lastActiveTime != null) {
      final difference = now.difference(_lastActiveTime!);
      if (difference.inMinutes >= state.lockTimeoutMinutes) {
        state = state.copyWith(isLocked: true);
        return;
      }
    }

    if (_lastPeriodicCheck != null) {
      final diffPeriodic = now.difference(_lastPeriodicCheck!);
      if (diffPeriodic.inHours >= 24) {
        state = state.copyWith(isLocked: true);
      }
    }
  }

  Future<bool> authenticateWithBiometrics({String? reason}) async {
    if (!state.useBiometrics && !state.isBiometricHardwareAvailable) {
      return false;
    }
    try {
      final isAvailable =
          await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();
      if (!isAvailable) return false;

      final authenticated = await _localAuth.authenticate(
        localizedReason:
            reason ?? 'Unlock MurihSpace with ${state.biometricLabel}',
        persistAcrossBackgrounding: true,
        biometricOnly: true,
      );

      if (authenticated) {
        _unlock();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> verifyPin(String pin) async {
    if (state.isLockedOut) return false;

    final storedHash = await _secureStorage.read(key: 'app_pin_hash');
    if (storedHash == null) return false;

    if (await _checkPinAndMigrate(pin, storedHash, 'app_pin_hash')) {
      _unlock();
      return true;
    }

    _handleFailedAttempt();
    return false;
  }

  void _handleFailedAttempt() {
    final newAttempts = state.failedPinAttempts + 1;
    if (newAttempts >= 5) {
      final lockoutDuration = Duration(seconds: (newAttempts - 4) * 30);
      if (ref.mounted) {
        state = state.copyWith(
          failedPinAttempts: newAttempts,
          lockoutUntil: DateTime.now().add(lockoutDuration),
        );
      }
    } else {
      if (ref.mounted) {
        state = state.copyWith(failedPinAttempts: newAttempts);
      }
    }
  }

  void _unlock() {
    _lastActiveTime = DateTime.now();
    _lastPeriodicCheck = DateTime.now();

    SharedPreferences.getInstance()
        .then((prefs) async {
          await prefs.setString(
            'last_periodic_check',
            _lastPeriodicCheck!.toIso8601String(),
          );
        })
        .then<void>((_) {}, onError: (_) {});

    if (ref.mounted) {
      state = state.copyWith(
        isLocked: false,
        failedPinAttempts: 0,
        clearLockout: true,
      );
    }
  }

  Future<void> setPin(String newPin) async {
    final hash = await _hashPin(newPin);
    await _secureStorage.write(key: 'app_pin_hash', value: hash);
    _unlock();
    if (ref.mounted) {
      state = state.copyWith(isPinSet: true);
    }
  }

  Future<void> removePin() async {
    await _secureStorage.delete(key: 'app_pin_hash');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('use_biometrics');

    if (ref.mounted) {
      state = state.copyWith(
        isPinSet: false,
        useBiometrics: false,
        isLocked: false,
        failedPinAttempts: 0,
        clearLockout: true,
      );
    }
  }

  Future<void> setUseBiometrics(bool use) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_biometrics', use);
    if (ref.mounted) {
      state = state.copyWith(useBiometrics: use);
    }
  }

  Future<void> setLockTimeout(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lock_timeout_minutes', minutes);
    if (ref.mounted) {
      state = state.copyWith(lockTimeoutMinutes: minutes);
    }
  }

  Future<String> _hashPin(String pin) => hashPinForStorageAsync(pin);

  /// Checks [pin] against [storedHash]. A legacy SHA-256 hash that matches is
  /// re-hashed in the current format and written back under [storageKey], so
  /// the legacy check runs at most once per user. A failed write-back never
  /// fails the unlock.
  Future<bool> _checkPinAndMigrate(
    String pin,
    String storedHash,
    String storageKey,
  ) async {
    if (!isPbkdf2PinHash(storedHash)) {
      if (!verifyLegacyPinHash(pin, storedHash)) return false;
      try {
        await _secureStorage.write(
          key: storageKey,
          value: await hashPinForStorageAsync(pin),
        );
      } catch (_) {}
      return true;
    }
    return verifyPbkdf2PinHashAsync(pin, storedHash);
  }
}

const _pinHashPrefix = 'pbkdf2-sha256';
const _pinHashIterations = 210000;
const _pinHashSaltBytes = 16;
const _pinHashKeyBytes = 32;

/// Encodes a new PIN hash as `pbkdf2-sha256$<iterations>$<salt b64>$<hash b64>`
/// with a fresh random salt on every call.
String hashPinForStorage(String pin, {Random? random}) {
  final rng = random ?? Random.secure();
  final salt = Uint8List.fromList(
    List<int>.generate(_pinHashSaltBytes, (_) => rng.nextInt(256)),
  );
  final key = pbkdf2HmacSha256(
    utf8.encode(pin),
    salt,
    _pinHashIterations,
    _pinHashKeyBytes,
  );
  return '$_pinHashPrefix\$$_pinHashIterations\$${base64Encode(salt)}\$${base64Encode(key)}';
}

bool isPbkdf2PinHash(String stored) => stored.startsWith('$_pinHashPrefix\$');

/// Verifies [pin] against a value in the current PBKDF2 format. Malformed
/// values fail closed.
bool verifyPbkdf2PinHash(String pin, String stored) {
  final parts = stored.split('\$');
  if (parts.length != 4 || parts[0] != _pinHashPrefix) return false;
  final iterations = int.tryParse(parts[1]);
  if (iterations == null || iterations < 1) return false;
  try {
    final salt = base64Decode(parts[2]);
    final expected = base64Decode(parts[3]);
    final actual = pbkdf2HmacSha256(
      utf8.encode(pin),
      salt,
      iterations,
      expected.length,
    );
    return _constantTimeEquals(actual, expected);
  } on FormatException {
    return false;
  }
}

/// Same output as [hashPinForStorage], but the PBKDF2 derivation runs in a
/// background isolate so the UI thread stays responsive. The salt is still
/// drawn on the calling isolate.
Future<String> hashPinForStorageAsync(String pin, {Random? random}) async {
  final rng = random ?? Random.secure();
  final salt = Uint8List.fromList(
    List<int>.generate(_pinHashSaltBytes, (_) => rng.nextInt(256)),
  );
  final key = await _derivePinKeyInIsolate(
    utf8.encode(pin),
    salt,
    _pinHashIterations,
    _pinHashKeyBytes,
  );
  return '$_pinHashPrefix\$$_pinHashIterations\$${base64Encode(salt)}\$${base64Encode(key)}';
}

/// Async counterpart of [verifyPbkdf2PinHash] with identical results. The
/// key derivation runs in a background isolate; parsing and the comparison
/// stay on the calling isolate.
Future<bool> verifyPbkdf2PinHashAsync(String pin, String stored) async {
  final parts = stored.split('\$');
  if (parts.length != 4 || parts[0] != _pinHashPrefix) return false;
  final iterations = int.tryParse(parts[1]);
  if (iterations == null || iterations < 1) return false;
  try {
    final salt = base64Decode(parts[2]);
    final expected = base64Decode(parts[3]);
    final actual = await _derivePinKeyInIsolate(
      utf8.encode(pin),
      salt,
      iterations,
      expected.length,
    );
    return _constantTimeEquals(actual, expected);
  } on FormatException {
    return false;
  }
}

Future<Uint8List> _derivePinKeyInIsolate(
  List<int> password,
  List<int> salt,
  int iterations,
  int keyLength,
) {
  return Isolate.run(
    () => pbkdf2HmacSha256(password, salt, iterations, keyLength),
  );
}

/// Verifies [pin] against the legacy unsalted-per-user SHA-256 format.
/// Used only to migrate existing PINs.
bool verifyLegacyPinHash(String pin, String stored) {
  final legacy = sha256.convert(utf8.encode('${pin}murih_space_salt_2026'));
  return _constantTimeEquals(
    utf8.encode(legacy.toString()),
    utf8.encode(stored),
  );
}

Uint8List pbkdf2HmacSha256(
  List<int> password,
  List<int> salt,
  int iterations,
  int keyLength,
) {
  final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
    ..init(Pbkdf2Parameters(Uint8List.fromList(salt), iterations, keyLength));
  return derivator.process(Uint8List.fromList(password));
}

bool _constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}

final securityProvider = NotifierProvider<SecurityNotifier, SecurityState>(
  SecurityNotifier.new,
);
