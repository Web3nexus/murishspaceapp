import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/broadcast_provider.dart';

/// Interactive SMS OTP Authorization sheet for high-value wallet withdrawals & escrow deals.
class OtpVerificationDialog extends ConsumerStatefulWidget {
  final String title;
  final String amountText;
  final String phoneNumber;
  final Function(String otp) onVerified;

  const OtpVerificationDialog({
    super.key,
    required this.title,
    required this.amountText,
    this.phoneNumber = '+234 812 *** 4567',
    required this.onVerified,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String amountText,
    String phoneNumber = '+234 812 *** 4567',
    required Function(String otp) onVerified,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1C1C1E)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => OtpVerificationDialog(
        title: title,
        amountText: amountText,
        phoneNumber: phoneNumber,
        onVerified: onVerified,
      ),
    );
  }

  @override
  ConsumerState<OtpVerificationDialog> createState() => _OtpVerificationDialogState();
}

class _OtpVerificationDialogState extends ConsumerState<OtpVerificationDialog> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  int _secondsRemaining = 45;
  Timer? _timer;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsRemaining = 45);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        t.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _otpCode => _controllers.map((c) => c.text).join();

  void _resendSms() {
    _startTimer();
    final newCode = '${100000 + (DateTime.now().millisecondsSinceEpoch % 899999)}';
    ref.read(broadcastProvider.notifier).addBroadcastMessage(
          BroadcastMessage(
            id: 'otp_${DateTime.now().millisecondsSinceEpoch}',
            title: '💬 New Transaction OTP Code',
            body: 'Your SMS OTP for ${widget.amountText} is $newCode. Sent to ${widget.phoneNumber}.',
            timestamp: DateTime.now(),
            type: BroadcastType.transactionOtp,
            otpCode: newCode,
          ),
        );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('New OTP sent via SMS to ${widget.phoneNumber}!'),
        backgroundColor: const Color(0xFF007AFF),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9500).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.sms_rounded, color: Color(0xFFFF9500), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textPrimary)),
                    Text('SMS Verification for ${widget.amountText}', style: TextStyle(fontSize: 12, color: textSecondary)),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context, false),
                icon: Icon(Icons.close_rounded, color: textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Subtitle message
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.phone_iphone_rounded, size: 20, color: Color(0xFF007AFF)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'We sent a 6-digit authorization OTP to ${widget.phoneNumber}.',
                    style: TextStyle(fontSize: 12, color: textPrimary, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 6 PIN Input Fields Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(6, (idx) {
              return SizedBox(
                width: 44,
                height: 52,
                child: TextField(
                  controller: _controllers[idx],
                  focusNode: _focusNodes[idx],
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 1,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: textPrimary),
                  decoration: InputDecoration(
                    counterText: '',
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFFF9500), width: 2),
                    ),
                  ),
                  onChanged: (val) {
                    if (val.isNotEmpty && idx < 5) {
                      _focusNodes[idx + 1].requestFocus();
                    } else if (val.isEmpty && idx > 0) {
                      _focusNodes[idx - 1].requestFocus();
                    }
                  },
                ),
              );
            }),
          ),
          const SizedBox(height: 18),

          // Resend Timer Row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _secondsRemaining > 0
                    ? 'Resend SMS code in 0:${_secondsRemaining.toString().padLeft(2, '0')}'
                    : 'Didn\'t receive the code? ',
                style: TextStyle(fontSize: 13, color: textSecondary),
              ),
              if (_secondsRemaining == 0)
                GestureDetector(
                  onTap: _resendSms,
                  child: const Text(
                    'Resend SMS',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF007AFF)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Authorize CTA
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9500),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _isVerifying || _otpCode.length < 6
                  ? null
                  : () async {
                      setState(() => _isVerifying = true);
                      await Future.delayed(const Duration(milliseconds: 600));
                      widget.onVerified(_otpCode);
                      if (mounted) Navigator.pop(context, true);
                    },
              child: _isVerifying
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Authorize Transaction', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
