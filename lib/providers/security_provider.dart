import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
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
          'last_periodic_check', _lastPeriodicCheck!.toIso8601String());
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
    final hash = _hashPin(newPin);
    await _secureStorage.write(key: 'txn_pin_hash', value: hash);
    if (ref.mounted) {
      state = state.copyWith(isTransactionPinSet: true);
    }
  }

  Future<bool> verifyTransactionPin(String pin) async {
    if (state.isLockedOut) return false;

    final storedHash = await _secureStorage.read(key: 'txn_pin_hash');
    if (storedHash == null) return false;

    final isCorrect = _hashPin(pin) == storedHash;
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
      final isAvailable = await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();
      if (!isAvailable) return false;

      final authenticated = await _localAuth.authenticate(
        localizedReason: reason ?? 'Unlock MurihSpace with ${state.biometricLabel}',
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

    final inputHash = _hashPin(pin);
    if (inputHash == storedHash) {
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

    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(
          'last_periodic_check', _lastPeriodicCheck!.toIso8601String());
    }).catchError((_) {});

    if (ref.mounted) {
      state = state.copyWith(
        isLocked: false,
        failedPinAttempts: 0,
        clearLockout: true,
      );
    }
  }

  Future<void> setPin(String newPin) async {
    final hash = _hashPin(newPin);
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

  String _hashPin(String pin) {
    final bytes = utf8.encode(pin + "murih_space_salt_2026");
    return sha256.convert(bytes).toString();
  }
}

final securityProvider =
    NotifierProvider<SecurityNotifier, SecurityState>(SecurityNotifier.new);
