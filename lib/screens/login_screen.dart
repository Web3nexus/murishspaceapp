import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:pinput/pinput.dart';

import '../components/app_bottom_sheet.dart';
import '../components/brand.dart';
import '../components/inline_field_error.dart';
import '../config/env.dart';
import '../config/deep_links.dart';
import '../core/design_tokens.dart';
import '../core/roles.dart';
import '../providers/auth_provider.dart';
import '../providers/platform_provider.dart';
import 'login_visibility.dart';

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
  String? _otpChannel;
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

  /// Where to send the user once they are authenticated.
  ///
  /// A shared link that needs an account (a meeting invite, a chat, a protected
  /// area) lands on `/auth/login?returnTo=…`, and the point of that parameter
  /// is to finish the job: the user signs in and continues to the content they
  /// originally opened. It is validated rather than trusted, so a crafted link
  /// cannot use the login screen to bounce someone off to another origin.
  String _postAuthLocation() {
    final returnTo = DeepLinks.sanitiseReturnTo(
      GoRouterState.of(context).uri.queryParameters['returnTo'],
    );
    return returnTo ?? '/app/home';
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
  Future<void> _requestPhoneOtp({bool forceSms = false}) async {
    if (!(_phoneFormKey.currentState?.validate() ?? false)) return;
    if (_phoneE164.isEmpty) return;

    setState(() {
      _phoneError = null;
      _noAccount = false;
    });

    final data = await ref
        .read(authProvider.notifier)
        .requestOtp(intent: 'login', phoneE164: _phoneE164, forceSms: forceSms);

    if (data != null) {
      setState(() {
        _maskedPhone = data['masked_phone'] as String? ?? _phoneE164;
        _otpChannel = data['channel'] as String? ?? (forceSms ? 'sms' : null);
        _otpStep = true;
      });
      _otpController.clear();
      _startResendCooldown(
        (data['resend_after_seconds'] as num?)?.toInt() ?? 60,
      );
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

    final data = await ref
        .read(authProvider.notifier)
        .verifyOtp(intent: 'login', phoneE164: _phoneE164, code: code);

    if (data != null) {
      if (data['account_exists'] != true) {
        setState(() => _noAccount = true);
        return;
      }
      if (data['token'] != null && mounted) {
        context.go(_postAuthLocation());
      }
    }
  }

  Future<void> _resendOtp() async {
    if (_resendIn > 0) return;
    setState(() => _otpError = null);
    _otpController.clear();
    final data = await ref
        .read(authProvider.notifier)
        .requestOtp(
          intent: 'login',
          phoneE164: _phoneE164,
          forceSms: _otpChannel == 'sms',
        );
    if (data != null) {
      setState(() {
        _otpChannel = data['channel'] as String? ?? _otpChannel;
      });
      _startResendCooldown(
        (data['resend_after_seconds'] as num?)?.toInt() ?? 60,
      );
    }
  }

  // --- Email Flow ---
  Future<void> _submitEmail() async {
    setState(() {
      _emailError = null;
      _passwordError = null;
    });

    if (_emailFormKey.currentState?.validate() ?? false) {
      final result = await ref
          .read(authProvider.notifier)
          .loginWithDeviceCheck(
            _emailController.text.trim(),
            _passwordController.text,
          );

      if (!mounted) return;

      if (result['status'] == 'pending_device_approval') {
        final pendingReq = result['pending_request'] as Map<String, dynamic>?;
        final reqToken = pendingReq?['request_token'] as String? ?? '';
        _showPendingDeviceApprovalSheet(reqToken);
        return;
      }

      if (result['status'] == 'success') {
        final role = ref.read(authProvider).user?.role;
        if (role == UserRole.admin) {
          await ref.read(authProvider.notifier).logout();
          if (!mounted) return;
          await AppBottomSheet.showNotice(
            context: context,
            title: 'Admin Web Portal Only',
            message:
                'Admin accounts manage ecosystem growth, KYC approvals, fee configurations, and dispute releases exclusively on the Web Admin Dashboard.\n\nPlease log in at ${Env.absolute('/securegate/login')} on a browser.',
            actionText: 'Understood',
            icon: Icons.admin_panel_settings_rounded,
          );
          return;
        }
        context.go(_postAuthLocation());
      } else {
        setState(() {
          _passwordError = result['message'] as String? ?? 'Login failed';
        });
      }
    }
  }

  void _showPendingDeviceApprovalSheet(String requestToken) {
    Timer? pollTimer;
    final codeController = TextEditingController();
    String? codeError;
    bool verifyingCode = false;

    showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final textPrimary = DesignTokens.textPrimaryOf(isDark);
        final border = DesignTokens.borderOf(isDark);
        final surface = DesignTokens.surfaceOf(isDark);

        return StatefulBuilder(
          builder: (context, setSheetState) {
            pollTimer ??= Timer.periodic(const Duration(seconds: 2), (t) async {
              final approved = await ref
                  .read(authProvider.notifier)
                  .completeApprovedLogin(requestToken);
              if (approved && mounted) {
                t.cancel();
                if (ctx.mounted) Navigator.of(ctx).pop();
                context.go(_postAuthLocation());
              }
            });

            Future<void> submitCode(String pin) async {
              if (pin.trim().length != 6 || verifyingCode) return;
              setSheetState(() {
                verifyingCode = true;
                codeError = null;
              });
              final res = await ref
                  .read(authProvider.notifier)
                  .verifyDeviceLoginCode(requestToken, pin.trim());
              if (res['status'] == 'success' && mounted) {
                pollTimer?.cancel();
                if (ctx.mounted) Navigator.of(ctx).pop();
                context.go(_postAuthLocation());
              } else {
                if (ctx.mounted) {
                  setSheetState(() {
                    verifyingCode = false;
                    codeError =
                        res['message'] as String? ??
                        'Invalid verification code';
                  });
                }
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9500).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.security_update_good_rounded,
                        color: Color(0xFFFF9500),
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Verify New Device',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'We sent a 6-digit verification code to your other active device(s). Enter the code below or tap "Approve" on that device to sign in.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Pinput(
                      controller: codeController,
                      length: 6,
                      defaultPinTheme: PinTheme(
                        width: 44,
                        height: 52,
                        textStyle: TextStyle(
                          fontSize: 20,
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
                        width: 44,
                        height: 52,
                        textStyle: TextStyle(
                          fontSize: 20,
                          color: textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: DesignTokens.primary,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          color: surface,
                        ),
                      ),
                      onChanged: (_) {
                        if (codeError != null)
                          setSheetState(() => codeError = null);
                      },
                      onCompleted: submitCode,
                    ),
                    if (codeError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        codeError!,
                        style: const TextStyle(
                          color: DesignTokens.danger,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: verifyingCode
                            ? null
                            : () => submitCode(codeController.text),
                        child: verifyingCode
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Verify Code'),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator.adaptive(
                            strokeWidth: 2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Waiting for authorization prompt...',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        pollTimer?.cancel();
                        Navigator.of(ctx).pop();
                      },
                      child: const Text('Cancel Login Attempt'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      pollTimer?.cancel();
      codeController.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final platformState = ref.watch(platformProvider);

    if (platformState.isLoading && platformState.config == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final config = platformState.config;
    final methods = LoginMethodVisibility(
      phoneEnabled: config?.isLoginEnabled('phone_otp') ?? true,
      emailEnabled: config?.isLoginEnabled('email_password') ?? true,
      googleEnabled: config?.isLoginEnabled('google') ?? true,
      appleEnabled: config?.isLoginEnabled('apple') ?? true,
    );
    final phoneEnabled = methods.showPhone;
    final emailEnabled = methods.showEmailPassword;
    final googleEnabled = methods.googleEnabled;
    final appleEnabled = methods.appleEnabled;

    // Ensure we don't land on a disabled tab
    if (methods.resolveTabIndex(_tabIndex) != _tabIndex) {
      final target = methods.resolveTabIndex(_tabIndex);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _tabIndex = target);
      });
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = DesignTokens.textPrimaryOf(isDark);
    final textSecondary = DesignTokens.textSecondaryOf(isDark);
    final surface = DesignTokens.surfaceOf(isDark);
    final border = DesignTokens.borderOf(isDark);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BrandLogo(height: 42, isDark: isDark),
                const SizedBox(height: 18),
                Text(
                  'Connect Safely.',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _tabIndex == 0
                      ? 'We\'ll text you a code to verify it\'s you.'
                      : 'Enter your credentials to access your account.',
                  style: TextStyle(color: textSecondary, fontSize: 15),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Tabs
                if (methods.showTabSwitcher)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: border),
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
                                color: _tabIndex == 0
                                    ? DesignTokens.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Phone',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _tabIndex == 0
                                      ? Colors.white
                                      : textSecondary,
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
                                color: _tabIndex == 1
                                    ? DesignTokens.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Email & Password',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _tabIndex == 1
                                      ? Colors.white
                                      : textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (!methods.anyMethodEnabled)
                  const Text(
                    'Login is currently disabled.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: DesignTokens.danger),
                  ),

                const SizedBox(height: 24),

                if (authState.errorMessage != null &&
                    !_noAccount &&
                    _otpError == null) ...[
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
                  _otpStep
                      ? _buildOtpForm(authState.loading)
                      : _buildPhoneForm(authState.loading)
                else if (_tabIndex == 1 && emailEnabled)
                  _buildEmailForm(authState.loading),

                if (googleEnabled || appleEnabled) ...[
                  const SizedBox(height: 24),
                  const Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'OR',
                          style: TextStyle(
                            color: DesignTokens.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
                              final success = await ref
                                  .read(authProvider.notifier)
                                  .loginWithGoogle();
                              if (success && mounted) {
                                context.go(_postAuthLocation());
                              }
                            },
                            icon: const Text(
                              'G',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            label: const Text('Google'),
                          ),
                        ),
                      if (googleEnabled && appleEnabled)
                        const SizedBox(width: 12),
                      if (appleEnabled)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final success = await ref
                                  .read(authProvider.notifier)
                                  .loginWithApple();
                              if (success && mounted) {
                                context.go(_postAuthLocation());
                              }
                            },
                            icon: const Text(
                              'A',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
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
                    side: const BorderSide(
                      color: DesignTokens.primary,
                      width: 2,
                    ),
                  ),
                  child: const Text('Create new account'),
                ),
                const SizedBox(height: 8),
                Text(
                  '${Env.apiEnv} \u00b7 ${Uri.parse(Env.apiBaseUrl).host}',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: textSecondary),
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
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpForm(bool loading) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = DesignTokens.textPrimaryOf(isDark);
    final border = DesignTokens.borderOf(isDark);
    final surface = DesignTokens.surfaceOf(isDark);

    final isInApp = _otpChannel == 'in_app_active_device';

    return Form(
      key: _otpFormKey,
      child: Column(
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
                Icon(
                  isInApp ? Icons.devices_rounded : Icons.check_circle,
                  color: isInApp
                      ? const Color(0xFFFF9500)
                      : DesignTokens.primary,
                  size: 22,
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
                          color: isInApp
                              ? const Color(0xFFFF9500)
                              : DesignTokens.primary,
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
                onPressed: loading
                    ? null
                    : () => _requestPhoneOtp(forceSms: true),
                icon: const Icon(Icons.sms_outlined, size: 15),
                label: const Text(
                  'Send via SMS instead',
                  style: TextStyle(fontSize: 12),
                ),
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
              if (_otpError != null) setState(() => _otpError = null);
            },
            onCompleted: (_) => _verifyPhoneOtp(),
          ),
          InlineFieldError(
            error: _otpError ?? ref.read(authProvider).errorMessage,
          ),

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
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () => context.go(
                      '/auth/register',
                      extra: {'phoneE164': _phoneE164},
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: DesignTokens.primary,
                    ),
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
                  onPressed: loading
                      ? null
                      : () => setState(() => _otpStep = false),
                  child: const Text(
                    'Change number',
                    style: TextStyle(fontSize: 13),
                  ),
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
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
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
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Sign In'),
          ),
        ],
      ),
    );
  }
}
