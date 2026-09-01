import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';
import '../providers/security_provider.dart';
import '../core/design_tokens.dart';

class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  String? _firstPin;
  String _error = '';
  final _pinController = TextEditingController();

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _onPinCompleted(String pin) {
    if (_firstPin == null) {
      // Move to confirm step
      setState(() {
        _firstPin = pin;
        _pinController.clear();
        _error = '';
      });
    } else {
      // Confirm step
      if (pin == _firstPin) {
        ref.read(securityProvider.notifier).setPin(pin);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('App Lock enabled successfully')),
          );
          context.pop(); // Go back to settings
        }
      } else {
        // Pins do not match
        setState(() {
          _error = 'PINs do not match. Try again.';
          _pinController.clear();
          _firstPin = null; // Reset completely
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultPinTheme = PinTheme(
      width: 56,
      height: 56,
      textStyle: TextStyle(fontSize: 22, color: DesignTokens.textPrimaryOf(isDark), fontWeight: FontWeight.w600),
      decoration: BoxDecoration(
        border: Border.all(color: DesignTokens.borderOf(isDark)),
        borderRadius: BorderRadius.circular(12),
        color: DesignTokens.surfaceOf(isDark),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(_firstPin == null ? 'Set PIN' : 'Confirm PIN'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              const Icon(Icons.lock_outline, size: 48, color: DesignTokens.primary),
              const SizedBox(height: 24),
              Text(
                _firstPin == null ? 'Create a 6-digit PIN' : 'Confirm your PIN',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _firstPin == null
                    ? 'This PIN will be used to unlock the app.'
                    : 'Enter the PIN again to confirm.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: DesignTokens.textSecondary, fontSize: 16),
              ),
              const SizedBox(height: 48),
              Center(
                child: Pinput(
                  controller: _pinController,
                  length: 6,
                  obscureText: true,
                  obscuringCharacter: '●',
                  defaultPinTheme: defaultPinTheme,
                  focusedPinTheme: defaultPinTheme.copyWith(
                    decoration: defaultPinTheme.decoration?.copyWith(
                      border: Border.all(color: DesignTokens.primary, width: 2),
                    ),
                  ),
                  onCompleted: _onPinCompleted,
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
            ],
          ),
        ),
      ),
    );
  }
}
