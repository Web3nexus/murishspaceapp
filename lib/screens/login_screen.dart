import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:pinput/pinput.dart';

import '../components/brand.dart';
import '../components/inline_field_error.dart';
import '../core/design_tokens.dart';
import '../core/roles.dart';
import '../providers/auth_provider.dart';
import '../providers/platform_provider.dart';

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
  bool _obscurePassword = true;
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
    if (ref.read(authProvider).loading) return;
    final code = _otpController.text.trim();
    if (code.length != 6) {
      setState(() => _otpError = 'Enter the 6-digit code.');
      return;
    }
    setState(() {
      _otpError = null;
      _noAccount = false;
    });

    final data = await ref.read(authProvider.notifier).verifyOtp(
          intent: 'login',
          phoneE164: _phoneE164,
          code: code,
        );

    if (data != null) {
      if (data['account_exists'] != true) {
        setState(() => _noAccount = true);
        return;
      }
      if (data['token'] != null && mounted) {
        context.go('/app/home');
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
        final role = ref.read(authProvider).user?.role;
        if (role == UserRole.admin) {
          await ref.read(authProvider.notifier).logout();
          if (!mounted) return;
          showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF007AFF), size: 28),
                  SizedBox(width: 8),
                  Text('Admin Web Portal Only', style: TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
              content: const Text(
                'Admin accounts manage ecosystem growth, KYC approvals, fee configurations, and dispute releases exclusively on the Web Admin Dashboard.\n\nPlease log in at https://murihspace.com/admin on a browser.',
                style: TextStyle(fontSize: 13, height: 1.45),
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Understood'),
                ),
              ],
            ),
          );
          return;
        }
        context.go('/app/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final platformState = ref.watch(platformProvider);

    if (platformState.isLoading && platformState.config == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final config = platformState.config;
    final phoneEnabled = config?.isLoginEnabled('phone_otp') ?? true;
    final emailEnabled = config?.isLoginEnabled('email_password') ?? true;
    final googleEnabled = config?.isLoginEnabled('google') ?? true;
    final appleEnabled = config?.isLoginEnabled('apple') ?? true;
    
    // Ensure we don't land on a disabled tab
    if (_tabIndex == 0 && !phoneEnabled && emailEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _tabIndex = 1);
      });
    } else if (_tabIndex == 1 && !emailEnabled && phoneEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _tabIndex = 0);
      });
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const BrandLogo(height: 42),
                const SizedBox(height: 24),
                const Text(
                  'Connect Safely.',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: DesignTokens.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _tabIndex == 0 ? 'We\'ll text you a code to verify it\'s you.' : 'Enter your credentials to access your account.',
                  style: const TextStyle(color: DesignTokens.textSecondary, fontSize: 15),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                
                // Tabs
                if (phoneEnabled && emailEnabled)
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
                  )
                else if (!phoneEnabled && !emailEnabled)
                  const Text('Login is currently disabled.', textAlign: TextAlign.center, style: TextStyle(color: DesignTokens.danger)),
                
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
                if (_tabIndex == 0 && phoneEnabled) 
                  _otpStep ? _buildOtpForm(authState.loading) : _buildPhoneForm(authState.loading)
                else if (_tabIndex == 1 && emailEnabled)
                  _buildEmailForm(authState.loading),
                
                if (googleEnabled || appleEnabled) ...[
                  const SizedBox(height: 24),
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
                  Row(
                    children: [
                      if (googleEnabled)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final success = await ref.read(authProvider.notifier).loginWithGoogle();
                              if (success && mounted) {
                                context.go('/app/home');
                              }
                            },
                            icon: const Text('G', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                            label: const Text('Google'),
                          ),
                        ),
                      if (googleEnabled && appleEnabled) const SizedBox(width: 12),
                      if (appleEnabled)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final success = await ref.read(authProvider.notifier).loginWithApple();
                              if (success && mounted) {
                                context.go('/app/home');
                              }
                            },
                            icon: const Text('A', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                            label: const Text('Apple'),
                          ),
                        ),
                    ],
                  ),
                ],
                
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
              setState(() {
                _phoneE164 = phone.completeNumber;
                if (_phoneError != null) _phoneError = null;
              });
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
          Pinput(
            controller: _otpController,
            length: 6,
            defaultPinTheme: PinTheme(
              width: 48,
              height: 56,
              textStyle: const TextStyle(fontSize: 22, color: DesignTokens.textPrimary, fontWeight: FontWeight.w600),
              decoration: BoxDecoration(
                border: Border.all(color: DesignTokens.border),
                borderRadius: BorderRadius.circular(12),
                color: DesignTokens.surface,
              ),
            ),
            focusedPinTheme: PinTheme(
              width: 48,
              height: 56,
              textStyle: const TextStyle(fontSize: 22, color: DesignTokens.textPrimary, fontWeight: FontWeight.w600),
              decoration: BoxDecoration(
                border: Border.all(color: DesignTokens.primary, width: 2),
                borderRadius: BorderRadius.circular(12),
                color: DesignTokens.surface,
              ),
            ),
            onChanged: (_) {
              if (_otpError != null) setState(() => _otpError = null);
            },
            onCompleted: (_) => _verifyPhoneOtp(),
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
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
            obscureText: _obscurePassword,
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
