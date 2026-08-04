import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

import '../components/brand.dart';
import '../components/inline_field_error.dart';
import '../core/design_tokens.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  // Tabs
  int _tabIndex = 0; // 0 for Phone, 1 for Email

  // Phone OTP Flow
  final _phoneFormKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  
  bool _otpStep = false;
  String _phoneE164 = '';
  String _maskedPhone = '';
  String? _phoneError;
  String? _otpError;
  bool _noAccount = false;
  int _resendIn = 0;
  Timer? _resendTimer;

  // Email Flow
  final _emailFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _otpController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendCooldown(int seconds) {
    _resendTimer?.cancel();
    setState(() => _resendIn = seconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendIn <= 1) {
        timer.cancel();
        setState(() => _resendIn = 0);
      } else {
        setState(() => _resendIn--);
      }
    });
  }

  // --- Phone Flow ---
  Future<void> _requestPhoneOtp() async {
    if (!(_phoneFormKey.currentState?.validate() ?? false)) return;
    if (_phoneE164.isEmpty) return;

    setState(() {
      _phoneError = null;
      _noAccount = false;
    });

    final data = await ref.read(authProvider.notifier).requestOtp(
          intent: 'login',
          phoneE164: _phoneE164,
        );

    if (data != null) {
      setState(() {
        _maskedPhone = data['masked_phone'] as String? ?? _phoneE164;
        _otpStep = true;
      });
      _otpController.clear();
      _startResendCooldown((data['resend_after_seconds'] as num?)?.toInt() ?? 60);
    }
  }

  Future<void> _verifyPhoneOtp() async {
    if (!(_otpFormKey.currentState?.validate() ?? false)) return;
    setState(() {
      _otpError = null;
      _noAccount = false;
    });

    final data = await ref.read(authProvider.notifier).verifyOtp(
          intent: 'login',
          phoneE164: _phoneE164,
          code: _otpController.text,
        );

    if (data != null) {
      if (data['account_exists'] != true) {
        setState(() => _noAccount = true);
        return;
      }
      if (data['token'] != null && mounted) {
        context.go('/app');
      }
    }
  }

  Future<void> _resendOtp() async {
    if (_resendIn > 0) return;
    setState(() => _otpError = null);
    _otpController.clear();
    final data = await ref.read(authProvider.notifier).requestOtp(
          intent: 'login',
          phoneE164: _phoneE164,
        );
    if (data != null) {
      _startResendCooldown((data['resend_after_seconds'] as num?)?.toInt() ?? 60);
    }
  }

  // --- Email Flow ---
  Future<void> _submitEmail() async {
    setState(() {
      _emailError = null;
      _passwordError = null;
    });

    if (_emailFormKey.currentState?.validate() ?? false) {
      final success = await ref.read(authProvider.notifier).login(
            _emailController.text.trim(),
            _passwordController.text,
          );
      if (success && mounted) {
        context.go('/app');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const BrandLogo(height: 34),
                const SizedBox(height: 20),
                const Text(
                  'Welcome back',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: DesignTokens.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _tabIndex == 0 ? 'We\'ll text you a code to verify it\'s you.' : 'Enter your credentials to access your account.',
                  style: const TextStyle(color: DesignTokens.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                
                // Tabs
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: DesignTokens.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: DesignTokens.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _tabIndex = 0;
                            _otpStep = false;
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _tabIndex == 0 ? DesignTokens.primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Phone',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _tabIndex == 0 ? Colors.white : DesignTokens.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _tabIndex = 1;
                            _otpStep = false;
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _tabIndex == 1 ? DesignTokens.primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Email & Password',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _tabIndex == 1 ? Colors.white : DesignTokens.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                if (authState.errorMessage != null && !_noAccount && _otpError == null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: DesignTokens.danger.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      authState.errorMessage!,
                      style: const TextStyle(color: DesignTokens.danger),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Flow Forms
                if (_tabIndex == 0) 
                  _otpStep ? _buildOtpForm(authState.loading) : _buildPhoneForm(authState.loading)
                else 
                  _buildEmailForm(authState.loading),
                
                const SizedBox(height: 24),

                // Divider
                const Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('OR', style: TextStyle(color: DesignTokens.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 16),

                // Social Logins Placeholders
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // TODO: Implement Google Sign In natively or via webview
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Google sign in is coming soon.')),
                          );
                        },
                        icon: const Text('G', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        label: const Text('Google'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // TODO: Implement Apple Sign In natively or via webview
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Apple sign in is coming soon.')),
                          );
                        },
                        icon: const Text('A', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        label: const Text('Apple'),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: () => context.go('/auth/register'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: DesignTokens.primary,
                    side: const BorderSide(color: DesignTokens.primary, width: 2),
                  ),
                  child: const Text('Create new account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneForm(bool loading) {
    return Form(
      key: _phoneFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IntlPhoneField(
            decoration: const InputDecoration(
              labelText: 'Mobile number',
              border: OutlineInputBorder(borderSide: BorderSide()),
            ),
            initialCountryCode: 'NG',
            onChanged: (phone) {
              _phoneE164 = phone.completeNumber;
              if (_phoneError != null) setState(() => _phoneError = null);
            },
          ),
          InlineFieldError(error: _phoneError),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: loading || _phoneE164.isEmpty ? null : _requestPhoneOtp,
            child: loading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpForm(bool loading) {
    return Form(
      key: _otpFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: DesignTokens.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: DesignTokens.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'We sent a 6-digit code to $_maskedPhone.',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(
              labelText: '6-digit Code',
              prefixIcon: Icon(Icons.security),
            ),
            validator: (v) => v == null || v.length < 6 ? 'Enter full code' : null,
            onChanged: (_) {
              if (_otpError != null) setState(() => _otpError = null);
            },
          ),
          InlineFieldError(error: _otpError ?? ref.read(authProvider).errorMessage),
          
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
                children: [
                  const Text(
                    'No account is linked to this number.',
                    style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () => context.go('/auth/register', extra: {'phoneE164': _phoneE164}),
                    style: FilledButton.styleFrom(backgroundColor: DesignTokens.primary),
                    child: const Text('Create an account with this number'),
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
                  onPressed: loading ? null : () => setState(() => _otpStep = false),
                  child: const Text('Change number', style: TextStyle(fontSize: 13)),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: (loading || _resendIn > 0) ? null : _resendOtp,
                  child: Text(
                    _resendIn > 0 ? 'Resend in ${_resendIn}s' : 'Resend code',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: loading ? null : _verifyPhoneOtp,
            child: loading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Log in'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailForm(bool loading) {
    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email Address',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (val) {
              if (val == null || val.isEmpty) return 'Email is required';
              if (!val.contains('@')) return 'Enter a valid email';
              return null;
            },
            onChanged: (_) {
              if (_emailError != null) setState(() => _emailError = null);
            },
          ),
          InlineFieldError(error: _emailError),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            decoration: const InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            obscureText: true,
            validator: (val) {
              if (val == null || val.isEmpty) return 'Password is required';
              return null;
            },
            onChanged: (_) {
              if (_passwordError != null) setState(() => _passwordError = null);
            },
          ),
          InlineFieldError(error: _passwordError),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => context.push('/auth/forgot-password'),
              child: const Text('Forgot password?'),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: loading ? null : _submitEmail,
            child: loading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Sign In'),
          ),
        ],
      ),
    );
  }
}
