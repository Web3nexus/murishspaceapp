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

  /// Displays the dialog as a Telegram-style Bottom Sheet and returns true if PIN was verified.
  static Future<bool> show(BuildContext context, {String? title, String? description}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
    if (security.useBiometrics && !security.isLockedOut) {
      final success = await ref
          .read(securityProvider.notifier)
          .authenticateWithBiometrics(reason: 'Authorize transaction');
      if (success && mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  void _onPinCompleted(String pin) async {
    final security = ref.read(securityProvider);
    if (security.isLockedOut) {
      setState(() {
        _error = 'Too many failed attempts. Please wait ${security.remainingLockoutSeconds}s';
        _pinController.clear();
      });
      return;
    }

    setState(() {
      _error = '';
      _isLoading = true;
    });

    final notifier = ref.read(securityProvider.notifier);
    bool success = false;

    if (security.isTransactionPinSet) {
      success = await notifier.verifyTransactionPin(pin);
    } else {
      success = await notifier.verifyPin(pin);
    }

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        Navigator.pop(context, true);
      } else {
        final updatedSecurity = ref.read(securityProvider);
        setState(() {
          if (updatedSecurity.isLockedOut) {
            _error = 'Too many failed attempts. Locked for ${updatedSecurity.remainingLockoutSeconds}s';
          } else {
            _error = 'Incorrect PIN';
          }
          _pinController.clear();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? DesignTokens.darkSurface : DesignTokens.lightSurface;
    final textPrimary = isDark ? DesignTokens.darkTextPrimary : DesignTokens.lightTextPrimary;
    final textSecondary = isDark ? DesignTokens.darkTextSecondary : DesignTokens.lightTextSecondary;
    final pinBg = isDark ? DesignTokens.darkSurfaceSecondary : DesignTokens.lightSurfaceSecondary;
    final border = isDark ? DesignTokens.darkBorder : DesignTokens.lightBorder;
    final security = ref.watch(securityProvider);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white30 : Colors.black26,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 8),

          Text(
            widget.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 24),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            )
          else
            Pinput(
              controller: _pinController,
              length: 6,
              obscureText: true,
              obscuringCharacter: '●',
              autofocus: true,
              enabled: !security.isLockedOut,
              onCompleted: _onPinCompleted,
              defaultPinTheme: PinTheme(
                width: 44,
                height: 48,
                textStyle: TextStyle(
                  fontSize: 20,
                  color: textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: border),
                  borderRadius: BorderRadius.circular(10),
                  color: pinBg,
                ),
              ),
            ),

          if (_error.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              _error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: DesignTokens.danger,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],

          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (security.useBiometrics && !security.isLockedOut) ...[
                IconButton(
                  tooltip: 'Use ${security.biometricLabel}',
                  icon: Icon(
                    security.biometricLabel == 'Face ID'
                        ? Icons.face_rounded
                        : Icons.fingerprint_rounded,
                    color: const Color(0xFFF09A3E),
                    size: 32,
                  ),
                  onPressed: _tryBiometrics,
                ),
                const SizedBox(width: 16),
              ],
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
