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
  bool _biometricsFailed = false;

  @override
  void initState() {
    super.initState();
    // Try biometrics on init if locked
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
    if (security.isLocked && security.useBiometrics) {
      final success = await ref.read(securityProvider.notifier).authenticateWithBiometrics();
      if (!success && mounted) {
        setState(() => _biometricsFailed = true);
      }
    }
  }

  void _onPinCompleted(String pin) async {
    setState(() => _error = '');
    final success = await ref.read(securityProvider.notifier).verifyPin(pin);
    if (success) {
      _pinController.clear();
      _error = '';
      _biometricsFailed = false;
    } else {
      setState(() {
        _error = 'Incorrect PIN';
        _pinController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final security = ref.watch(securityProvider);

    if (!security.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Stack(
      children: [
        widget.child, // The actual app behind the lock

        if (security.isLocked) ...[
          // Semi-transparent or fully opaque background
          Container(
            color: Theme.of(context).scaffoldBackgroundColor, // Fully opaque for privacy
            width: double.infinity,
            height: double.infinity,
          ),
          Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.lock, size: 64, color: DesignTokens.primary),
                    const SizedBox(height: 24),
                    const Text(
                      'App Locked',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Enter your PIN to unlock MurihSpace',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: DesignTokens.textSecondary, fontSize: 16),
                    ),
                    const SizedBox(height: 48),
                    Center(
                      child: Pinput(
                        controller: _pinController,
                        length: 6,
                        obscureText: true,
                        obscuringCharacter: '●',
                        onCompleted: _onPinCompleted,
                        autofocus: true,
                        defaultPinTheme: PinTheme(
                          width: 56,
                          height: 56,
                          textStyle: const TextStyle(fontSize: 22, color: DesignTokens.textPrimary, fontWeight: FontWeight.w600),
                          decoration: BoxDecoration(
                            border: Border.all(color: DesignTokens.border),
                            borderRadius: BorderRadius.circular(12),
                            color: DesignTokens.surface,
                          ),
                        ),
                      ),
                    ),
                    if (_error.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ],
                    if (security.useBiometrics) ...[
                      const SizedBox(height: 32),
                      Center(
                        child: TextButton.icon(
                          onPressed: _tryBiometrics,
                          icon: const Icon(Icons.fingerprint, size: 28),
                          label: const Text('Use Biometrics'),
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
