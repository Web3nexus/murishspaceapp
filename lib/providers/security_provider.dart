import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class SecurityState {
  final bool isInitialized;
  final bool isLocked;
  final bool isPinSet;
  final bool isTransactionPinSet;
  final bool useBiometrics;
  final int lockTimeoutMinutes;
  
  SecurityState({
    this.isInitialized = false,
    this.isLocked = false,
    this.isPinSet = false,
    this.isTransactionPinSet = false,
    this.useBiometrics = false,
    this.lockTimeoutMinutes = 1,
  });

  SecurityState copyWith({
    bool? isInitialized,
    bool? isLocked,
    bool? isPinSet,
    bool? isTransactionPinSet,
    bool? useBiometrics,
    int? lockTimeoutMinutes,
  }) {
    return SecurityState(
      isInitialized: isInitialized ?? this.isInitialized,
      isLocked: isLocked ?? this.isLocked,
      isPinSet: isPinSet ?? this.isPinSet,
      isTransactionPinSet: isTransactionPinSet ?? this.isTransactionPinSet,
      useBiometrics: useBiometrics ?? this.useBiometrics,
      lockTimeoutMinutes: lockTimeoutMinutes ?? this.lockTimeoutMinutes,
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
    
    final pinHash = await _secureStorage.read(key: 'app_pin_hash');
    final isPinSet = pinHash != null && pinHash.isNotEmpty;

    final txnPinHash = await _secureStorage.read(key: 'txn_pin_hash');
    final isTransactionPinSet = txnPinHash != null && txnPinHash.isNotEmpty;
    
    final useBiometrics = prefs.getBool('use_biometrics') ?? false;
    final lockTimeoutMinutes = prefs.getInt('lock_timeout_minutes') ?? 1;
    
    final lastCheckStr = prefs.getString('last_periodic_check');
    if (lastCheckStr != null) {
      _lastPeriodicCheck = DateTime.tryParse(lastCheckStr);
    } else {
      _lastPeriodicCheck = DateTime.now();
      await prefs.setString('last_periodic_check', _lastPeriodicCheck!.toIso8601String());
    }

    state = state.copyWith(
      isInitialized: true,
      isPinSet: isPinSet,
      isTransactionPinSet: isTransactionPinSet,
      useBiometrics: useBiometrics,
      lockTimeoutMinutes: lockTimeoutMinutes,
    );
  }

  Future<void> setTransactionPin(String newPin) async {
    final hash = _hashPin(newPin);
    await _secureStorage.write(key: 'txn_pin_hash', value: hash);
    state = state.copyWith(isTransactionPinSet: true);
  }

  Future<bool> verifyTransactionPin(String pin) async {
    final storedHash = await _secureStorage.read(key: 'txn_pin_hash');
    if (storedHash == null) return false;
    return _hashPin(pin) == storedHash;
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

  Future<bool> authenticateWithBiometrics() async {
    if (!state.useBiometrics) return false;
    try {
      final isAvailable = await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
      if (!isAvailable) return false;
      
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Unlock MurihSpace',
        persistAcrossBackgrounding: true,
        biometricOnly: true,
      );
      
      if (authenticated) {
        _unlock();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> verifyPin(String pin) async {
    final storedHash = await _secureStorage.read(key: 'app_pin_hash');
    if (storedHash == null) return false;
    
    final inputHash = _hashPin(pin);
    if (inputHash == storedHash) {
      _unlock();
      return true;
    }
    return false;
  }

  void _unlock() async {
    _lastActiveTime = DateTime.now();
    _lastPeriodicCheck = DateTime.now();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_periodic_check', _lastPeriodicCheck!.toIso8601String());
    
    state = state.copyWith(isLocked: false);
  }

  Future<void> setPin(String newPin) async {
    final hash = _hashPin(newPin);
    await _secureStorage.write(key: 'app_pin_hash', value: hash);
    _unlock();
    state = state.copyWith(isPinSet: true);
  }

  Future<void> removePin() async {
    await _secureStorage.delete(key: 'app_pin_hash');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('use_biometrics');
    
    state = state.copyWith(
      isPinSet: false,
      useBiometrics: false,
      isLocked: false,
    );
  }

  Future<void> setUseBiometrics(bool use) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_biometrics', use);
    state = state.copyWith(useBiometrics: use);
  }

  Future<void> setLockTimeout(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lock_timeout_minutes', minutes);
    state = state.copyWith(lockTimeoutMinutes: minutes);
  }

  String _hashPin(String pin) {
    final bytes = utf8.encode(pin + "murih_space_salt_2026");
    return sha256.convert(bytes).toString();
  }
}

final securityProvider = NotifierProvider<SecurityNotifier, SecurityState>(() {
  return SecurityNotifier();
});
