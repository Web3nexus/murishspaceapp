import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinput/pinput.dart';
import '../providers/security_provider.dart';
import '../core/design_tokens.dart';

class AppLockOverlay extends ConsumerStatefulWidget {
  final Widget child;

  const AppLockOverlay({super.key, required this.child});

  @override
  ConsumerState<AppLockOverlay> createState() => _AppLockOverlayState();
}

class _AppLockOverlayState extends ConsumerState<AppLockOverlay> {
  final _pinController = TextEditingController();
  String _error = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryBiometrics();
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _tryBiometrics() async {
    final security = ref.read(securityProvider);
    if (security.isLocked && security.useBiometrics && !security.isLockedOut) {
      await ref.read(securityProvider.notifier).authenticateWithBiometrics();
    }
  }

  void _onPinCompleted(String pin) async {
    final security = ref.read(securityProvider);
    if (security.isLockedOut) {
      setState(() {
        _error = 'Too many attempts. Locked for ${security.remainingLockoutSeconds}s';
        _pinController.clear();
      });
      return;
    }

    setState(() => _error = '');
    final success = await ref.read(securityProvider.notifier).verifyPin(pin);
    if (success) {
      _pinController.clear();
      setState(() => _error = '');
    } else {
      final updated = ref.read(securityProvider);
      setState(() {
        if (updated.isLockedOut) {
          _error = 'Too many attempts. Locked for ${updated.remainingLockoutSeconds}s';
        } else {
          _error = 'Incorrect PIN';
        }
        _pinController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final security = ref.watch(securityProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (!security.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Stack(
      children: [
        widget.child,

        if (security.isLocked) ...[
          Container(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            width: double.infinity,
            height: double.infinity,
          ),
          Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF09A3E).withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
                        size: 40,
                        color: Color(0xFFF09A3E),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'App Locked',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter your PIN to unlock MurihSpace',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 40),
                    Center(
                      child: Pinput(
                        controller: _pinController,
                        length: 6,
                        obscureText: true,
                        obscuringCharacter: '●',
                        onCompleted: _onPinCompleted,
                        autofocus: true,
                        enabled: !security.isLockedOut,
                        defaultPinTheme: PinTheme(
                          width: 48,
                          height: 52,
                          textStyle: TextStyle(
                            fontSize: 22,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                            ),
                            borderRadius: BorderRadius.circular(12),
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          ),
                        ),
                      ),
                    ),
                    if (_error.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: DesignTokens.danger,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                    if (security.useBiometrics && !security.isLockedOut) ...[
                      const SizedBox(height: 36),
                      Center(
                        child: TextButton.icon(
                          onPressed: _tryBiometrics,
                          icon: Icon(
                            security.biometricLabel == 'Face ID'
                                ? Icons.face_rounded
                                : Icons.fingerprint_rounded,
                            size: 28,
                            color: const Color(0xFFF09A3E),
                          ),
                          label: Text(
                            'Unlock with ${security.biometricLabel}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFF09A3E),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
