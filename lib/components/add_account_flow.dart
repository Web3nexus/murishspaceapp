import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:pinput/pinput.dart';

import '../core/design_tokens.dart';
import '../providers/auth_provider.dart';
import 'murih_icon.dart';

/// The account sign-in workflow: phone number → 6-digit code.
///
/// Shared by the standalone Add Account page and the inline add-account step
/// inside the switch-profile pop, so both screens use identical inputs and
/// icons. On success the freshly-added account is persisted in the fast-switch
/// list and [onSuccess] is called with the account's display name.
class AddAccountFlow extends ConsumerStatefulWidget {
  final ValueChanged<String>? onSuccess;

  const AddAccountFlow({super.key, this.onSuccess});

  @override
  ConsumerState<AddAccountFlow> createState() => _AddAccountFlowState();
}

class _AddAccountFlowState extends ConsumerState<AddAccountFlow> {
  final _otpController = TextEditingController();

  bool _otpStep = false;
  bool _sending = false;
  bool _verifying = false;
  String _phoneE164 = '';
  String _maskedPhone = '';
  String? _otpChannel;
  String? _error;
  bool _noAccount = false;
  int _resendIn = 0;
  Timer? _resendTimer;

  @override
  void dispose() {
    _otpController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendCooldown(int seconds) {
    _resendTimer?.cancel();
    setState(() => _resendIn = seconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendIn <= 1) {
        timer.cancel();
        setState(() => _resendIn = 0);
      } else {
        setState(() => _resendIn--);
      }
    });
  }

  Future<void> _requestOtp({bool forceSms = false}) async {
    if (_phoneE164.isEmpty) return;
    setState(() {
      _error = null;
      _noAccount = false;
      _sending = true;
    });

    final data = await ref.read(authProvider.notifier).requestOtp(
          intent: 'login',
          phoneE164: _phoneE164,
          forceSms: forceSms,
        );

    if (!mounted) return;
    setState(() => _sending = false);

    if (data == null) {
      setState(() {
        _error = ref.read(authProvider).errorMessage ?? 'Could not send the code. Try again.';
      });
      return;
    }

    setState(() {
      _maskedPhone = data['masked_phone'] as String? ?? _phoneE164;
      _otpChannel = data['channel'] as String? ?? (forceSms ? 'sms' : null);
      _otpStep = true;
    });
    _otpController.clear();
    _startResendCooldown((data['resend_after_seconds'] as num?)?.toInt() ?? 60);
  }

  Future<void> _resendOtp() async {
    if (_resendIn > 0) return;
    setState(() => _error = null);
    _otpController.clear();
    await _requestOtp(forceSms: _otpChannel == 'sms');
  }

  Future<void> _verifyOtp() async {
    final code = _otpController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code.');
      return;
    }
    setState(() {
      _error = null;
      _noAccount = false;
      _verifying = true;
    });

    final data = await ref.read(authProvider.notifier).verifyOtp(
          intent: 'login',
          phoneE164: _phoneE164,
          code: code,
        );

    if (!mounted) return;
    setState(() => _verifying = false);

    if (data == null) {
      setState(() {
        _error = ref.read(authProvider).errorMessage ?? 'Verification failed. Try again.';
      });
      return;
    }
    if (data['account_exists'] != true) {
      setState(() => _noAccount = true);
      return;
    }
    if (data['token'] == null) {
      setState(() => _error = 'Your account could not be switched. Try again.');
      return;
    }

    await ref.read(authProvider.notifier).refreshProfile();
    if (!mounted) return;
    final name = ref.read(authProvider).user?.name ?? 'account';
    widget.onSuccess?.call(name);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = DesignTokens.textPrimaryOf(isDark);
    final textSecondary = DesignTokens.textSecondaryOf(isDark);
    final surface = DesignTokens.surfaceOf(isDark);
    final border = DesignTokens.borderOf(isDark);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeaderCard(isInApp: _otpStep && _otpChannel == 'in_app_active_device'),
        const SizedBox(height: 20),
        if (!_otpStep)
          _buildPhoneStep(textPrimary, textSecondary, surface, border, isDark)
        else
          _buildOtpStep(textPrimary, textSecondary, surface, border, isDark),
      ],
    );
  }

  Widget _buildPhoneStep(Color textPrimary, Color textSecondary, Color surface, Color border, bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Mobile number',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textSecondary),
        ),
        const SizedBox(height: 6),
        IntlPhoneField(
          decoration: InputDecoration(
            hintText: 'e.g. 0803 123 4567',
            hintStyle: TextStyle(
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              fontSize: 14,
            ),
            filled: true,
            fillColor: surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: DesignTokens.primary, width: 1.5),
            ),
          ),
          initialCountryCode: 'NG',
          onChanged: (phone) {
            setState(() {
              _phoneE164 = phone.completeNumber;
              if (_error != null) _error = null;
            });
          },
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: DesignTokens.danger, fontSize: 12)),
        ],
        const SizedBox(height: 18),
        SizedBox(
          height: 52,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: DesignTokens.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _sending || _phoneE164.isEmpty ? null : _requestOtp,
            child: _sending
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                  )
                : const Text('Send code', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ),
      ],
    );
  }

  Widget _buildOtpStep(Color textPrimary, Color textSecondary, Color surface, Color border, bool isDark) {
    final isInApp = _otpChannel == 'in_app_active_device';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isInApp
                ? const Color(0xFFFF9500).withValues(alpha: 0.12)
                : DesignTokens.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isInApp
                  ? const Color(0xFFFF9500).withValues(alpha: 0.3)
                  : DesignTokens.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: MurihIcon(
                  isInApp ? 'Message' : 'Tick Square',
                  size: 22,
                  color: isInApp ? const Color(0xFFFF9500) : DesignTokens.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isInApp ? 'Sent to Active Device' : 'Code Sent',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isInApp ? const Color(0xFFFF9500) : DesignTokens.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isInApp
                          ? 'A 6-digit login code was sent to your active MurihSpace session (Web / Mobile). Check your active session notifications.'
                          : 'We sent a 6-digit code to $_maskedPhone.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                        color: isDark ? Colors.grey[300] : Colors.grey[800],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (isInApp) ...[
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _sending ? null : () => _requestOtp(forceSms: true),
              icon: const MurihIcon('Message', size: 15, color: DesignTokens.primary),
              label: const Text('Send via SMS instead', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Pinput(
          controller: _otpController,
          length: 6,
          defaultPinTheme: PinTheme(
            width: 48,
            height: 56,
            textStyle: TextStyle(
              fontSize: 22,
              color: textPrimary,
              fontWeight: FontWeight.w600,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: border),
              borderRadius: BorderRadius.circular(12),
              color: surface,
            ),
          ),
          focusedPinTheme: PinTheme(
            width: 48,
            height: 56,
            textStyle: TextStyle(
              fontSize: 22,
              color: textPrimary,
              fontWeight: FontWeight.w600,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: DesignTokens.primary, width: 2),
              borderRadius: BorderRadius.circular(12),
              color: surface,
            ),
          ),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          onCompleted: (_) => _verifyOtp(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: DesignTokens.danger, fontSize: 12)),
        ],
        if (_noAccount) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'No account is linked to this number.',
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Create the account on the login screen first, then add it here.',
                  style: TextStyle(color: Colors.orange, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: _sending || _verifying
                    ? null
                    : () => setState(() {
                          _otpStep = false;
                          _phoneE164 = '';
                          _error = null;
                          _noAccount = false;
                        }),
                child: const Text('Change number', style: TextStyle(fontSize: 13)),
              ),
            ),
            Expanded(
              child: TextButton(
                onPressed: (_sending || _verifying || _resendIn > 0) ? null : _resendOtp,
                child: Text(
                  _resendIn > 0 ? 'Resend in ${_resendIn}s' : 'Resend code',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 52,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: DesignTokens.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _verifying ? null : _verifyOtp,
            child: _verifying
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                  )
                : const Text('Add account', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ),
      ],
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final bool isInApp;

  const _HeaderCard({required this.isInApp});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = DesignTokens.textPrimaryOf(isDark);
    final textSecondary = DesignTokens.textSecondaryOf(isDark);
    final accent = isInApp ? const Color(0xFFFF9500) : DesignTokens.primary;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: MurihIcon(isInApp ? 'Message' : 'Calling', color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isInApp ? 'Confirm on your other device' : 'Sign in with your number',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  isInApp
                      ? 'Enter the code you received to add this account to this device.'
                      : 'Enter the mobile number of the account to add. A 6-digit code will be sent to verify it.',
                  style: TextStyle(fontSize: 12, height: 1.45, color: textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}