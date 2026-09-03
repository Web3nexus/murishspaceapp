import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:pinput/pinput.dart';

import '../core/api_client.dart';
import '../providers/auth_provider.dart';

class ChangePhoneScreen extends ConsumerStatefulWidget {
  const ChangePhoneScreen({super.key});

  @override
  ConsumerState<ChangePhoneScreen> createState() => _ChangePhoneScreenState();
}

class _ChangePhoneScreenState extends ConsumerState<ChangePhoneScreen> {
  int _step = 1; // 1: Enter Phone, 2: Enter OTP
  String _completePhoneNumber = '';
  final TextEditingController _pinController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  int _resendCountdown = 60;
  Timer? _countdownTimer;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pinController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _resendCountdown = 60;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        if (mounted) setState(() => _resendCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _requestVerificationCode() async {
    if (_completePhoneNumber.isEmpty) {
      setState(() => _errorMessage = 'Please enter a valid mobile number.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post('/auth/phone/change-request', data: {
        'phone': _completePhoneNumber,
      });

      if (mounted) {
        setState(() {
          _isLoading = false;
          _step = 2;
        });
        _startResendTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.data['message'] ?? 'Verification code sent!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  Future<void> _verifyOtp(String code) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post('/auth/phone/verify-change', data: {
        'code': code,
      });

      // Refresh auth user state
      await ref.read(authProvider.notifier).refreshProfile();

      HapticFeedback.mediumImpact();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF34C759),
            content: Text(res.data['message'] ?? 'Phone number updated successfully!'),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : const Color(0xFFF2F2F7);
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Change Mobile Number',
          style: TextStyle(fontWeight: FontWeight.w800, color: textPrimary),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF007AFF).withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.phone_iphone_rounded, color: Color(0xFF007AFF), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Current Verified Number', style: TextStyle(fontSize: 12, color: textSecondary)),
                        Text(
                          authState.user?.phone ?? 'No number registered',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textPrimary),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          if (_step == 1) ...[
            Text(
              'Enter New Mobile Number',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'We will send a 6-digit verification code to confirm ownership.',
              style: TextStyle(fontSize: 13, color: textSecondary),
            ),
            const SizedBox(height: 16),
            IntlPhoneField(
              decoration: InputDecoration(
                labelText: 'New Phone Number',
                filled: true,
                fillColor: cardBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
              initialCountryCode: 'NG',
              onChanged: (phone) {
                _completePhoneNumber = phone.completeNumber;
              },
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Color(0xFFFF3B30), fontSize: 13),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007AFF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _isLoading ? null : _requestVerificationCode,
                child: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Send Verification Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ] else ...[
            Text(
              'Verify New Number',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'Enter the 6-digit code sent to $_completePhoneNumber',
              style: TextStyle(fontSize: 13, color: textSecondary),
            ),
            const SizedBox(height: 24),
            Center(
              child: Pinput(
                length: 6,
                controller: _pinController,
                onCompleted: _verifyOtp,
                defaultPinTheme: PinTheme(
                  width: 48,
                  height: 54,
                  textStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textPrimary),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? const Color(0xFF3A3A3C) : const Color(0xFFD1D1D6)),
                  ),
                ),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 14),
              Center(
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Color(0xFFFF3B30), fontSize: 13),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Center(
              child: TextButton(
                onPressed: _resendCountdown == 0 ? _requestVerificationCode : null,
                child: Text(
                  _resendCountdown > 0
                      ? 'Resend code in ${_resendCountdown}s'
                      : 'Resend Verification Code',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _resendCountdown > 0 ? textSecondary : const Color(0xFF007AFF),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
