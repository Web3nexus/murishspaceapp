import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinput/pinput.dart';
import '../providers/security_provider.dart';
import '../core/design_tokens.dart';

class TransactionPinDialog extends ConsumerStatefulWidget {
  final String title;
  final String description;

  const TransactionPinDialog({
    super.key,
    this.title = 'Confirm Transaction',
    this.description = 'Enter your PIN to confirm this action.',
  });

  /// Displays the dialog and returns true if the PIN was successfully verified.
  static Future<bool> show(BuildContext context, {String? title, String? description}) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => TransactionPinDialog(
        title: title ?? 'Confirm Transaction',
        description: description ?? 'Enter your PIN to confirm this action.',
      ),
    );
    return result ?? false;
  }

  @override
  ConsumerState<TransactionPinDialog> createState() => _TransactionPinDialogState();
}

class _TransactionPinDialogState extends ConsumerState<TransactionPinDialog> {
  final _pinController = TextEditingController();
  String _error = '';
  bool _isLoading = false;

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
    if (security.useBiometrics) {
      final success = await ref.read(securityProvider.notifier).authenticateWithBiometrics();
      if (success && mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  void _onPinCompleted(String pin) async {
    setState(() {
      _error = '';
      _isLoading = true;
    });

    final success = await ref.read(securityProvider.notifier).verifyPin(pin);
    
    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        Navigator.pop(context, true);
      } else {
        setState(() {
          _error = 'Incorrect PIN';
          _pinController.clear();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(widget.title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.description, textAlign: TextAlign.center, style: const TextStyle(color: DesignTokens.textSecondary)),
          const SizedBox(height: 24),
          if (_isLoading)
            const CircularProgressIndicator()
          else
            Pinput(
              controller: _pinController,
              length: 6,
              obscureText: true,
              obscuringCharacter: '●',
              autofocus: true,
              onCompleted: _onPinCompleted,
              defaultPinTheme: PinTheme(
                width: 44,
                height: 48,
                textStyle: const TextStyle(fontSize: 20, color: DesignTokens.textPrimary, fontWeight: FontWeight.w600),
                decoration: BoxDecoration(
                  border: Border.all(color: DesignTokens.border),
                  borderRadius: BorderRadius.circular(8),
                  color: DesignTokens.surface,
                ),
              ),
            ),
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              _error,
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel', style: TextStyle(color: DesignTokens.textSecondary)),
        ),
      ],
    );
  }
}
