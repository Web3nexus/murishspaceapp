import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:pinput/pinput.dart';

import '../components/brand.dart';
import '../components/inline_field_error.dart';
import '../core/api_client.dart';
import '../core/design_tokens.dart';
import '../core/roles.dart';
import '../providers/auth_provider.dart';
import '../providers/platform_provider.dart';

enum _UsernameCheck { idle, checking, available, taken, invalid }

class RegisterScreen extends ConsumerStatefulWidget {
  final String? initialPhoneE164;
  final String? initialCountryIso2;

  const RegisterScreen({
    super.key,
    this.initialPhoneE164,
    this.initialCountryIso2,
  });

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _pageController = PageController();
  int _step = 1; // 1 to 6

  // Step 1: Phone
  final _phoneFormKey = GlobalKey<FormState>();
  String _phoneE164 = '';
  String _maskedPhone = '';
  String? _phoneError;

  // Step 2: OTP
  final _otpFormKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  String? _otpError;
  String _registrationSessionId = '';
  int _resendIn = 0;
  Timer? _resendTimer;

  // Step 3: Username
  final _usernameFormKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  _UsernameCheck _usernameCheck = _UsernameCheck.idle;
  Timer? _usernameDebounce;

  // Step 4: Name
  final _nameFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  // Step 5: Password
  final _passwordFormKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _passwordError;
  String? _confirmPasswordError;

  // Step 6: Role
  UserRole _role = UserRole.member;

  @override
  void initState() {
    super.initState();
    _phoneE164 = widget.initialPhoneE164 ?? '';
    _usernameController.addListener(_onUsernameChanged);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _resendTimer?.cancel();
    _usernameDebounce?.cancel();
    _usernameController.removeListener(_onUsernameChanged);
    _otpController.dispose();
    _usernameController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_step < 6) {
      setState(() => _step++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _prevStep() {
    if (_step > 1) {
      setState(() => _step--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
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

  // --- Step 1: Phone Logic ---
  Future<void> _handleRequestOtp() async {
    if (!(_phoneFormKey.currentState?.validate() ?? false)) return;
    if (_phoneE164.isEmpty) return;

    setState(() => _phoneError = null);
    final data = await ref.read(authProvider.notifier).requestOtp(
          intent: 'register',
          phoneE164: _phoneE164,
        );

    if (data != null) {
      setState(() {
        _maskedPhone = data['masked_phone'] as String? ?? _phoneE164;
      });
      _otpController.clear();
      _startResendCooldown((data['resend_after_seconds'] as num?)?.toInt() ?? 60);
      _nextStep();
    }
  }

  // --- Step 2: OTP Logic ---
  Future<void> _handleVerifyOtp() async {
    if (ref.read(authProvider).loading) return;
    final code = _otpController.text.trim();
    if (code.length != 6) {
      setState(() => _otpError = 'Enter the 6-digit code.');
      return;
    }
    setState(() => _otpError = null);

    final data = await ref.read(authProvider.notifier).verifyOtp(
          intent: 'register',
          phoneE164: _phoneE164,
          code: code,
        );

    if (data != null) {
      final sessionId = data['registration_session_id'] as String?;
      if (sessionId == null) {
        setState(() => _otpError = 'Unable to continue registration.');
        return;
      }
      _registrationSessionId = sessionId;
      _nextStep();
    }
  }

  Future<void> _resendOtp() async {
    if (_resendIn > 0) return;
    setState(() => _otpError = null);
    _otpController.clear();
    final data = await ref.read(authProvider.notifier).requestOtp(
          intent: 'register',
          phoneE164: _phoneE164,
        );
    if (data != null) {
      _startResendCooldown((data['resend_after_seconds'] as num?)?.toInt() ?? 60);
    }
  }

  // --- Step 3: Username Logic ---
  static final _usernameRegex = RegExp(r'^[a-zA-Z0-9_]+$');

  void _onUsernameChanged() {
    _usernameDebounce?.cancel();
    final value = _usernameController.text.trim();
    if (value.isEmpty || value.length < 3) {
      setState(() => _usernameCheck = _UsernameCheck.idle);
      return;
    }
    if (!_usernameRegex.hasMatch(value) || value.length > 50) {
      setState(() => _usernameCheck = _UsernameCheck.invalid);
      return;
    }
    setState(() => _usernameCheck = _UsernameCheck.checking);
    _usernameDebounce = Timer(const Duration(milliseconds: 450), () async {
      final available = await _checkUsername(value);
      if (!mounted) return;
      if (_usernameController.text.trim() != value) return;
      setState(() {
        if (available == null) {
          _usernameCheck = _UsernameCheck.idle;
        } else {
          _usernameCheck = available ? _UsernameCheck.available : _UsernameCheck.taken;
        }
      });
    });
  }

  Future<bool?> _checkUsername(String username) async {
    try {
      final response = await ApiClient.instance.dio.get('/auth/check-username/$username');
      final data = response.data;
      if (data is Map<String, dynamic>) {
        if (data.containsKey('success') && data['success'] == true) {
          return data['data']['available'] as bool? ?? false;
        }
        return data['available'] as bool? ?? false;
      }
    } catch (_) {}
    return null;
  }

  void _handleNextUsername() {
    if (_usernameCheck == _UsernameCheck.available) {
      _nextStep();
    }
  }

  // --- Step 4: Name Logic ---
  void _handleNextName() {
    if (_nameFormKey.currentState?.validate() ?? false) {
      _nextStep();
    }
  }

  // --- Step 5: Password & Registration Logic ---
  Future<void> _handleNextPassword() async {
    setState(() {
      _passwordError = null;
      _confirmPasswordError = null;
    });
    if (!(_passwordFormKey.currentState?.validate() ?? false)) return;

    final pass = _passwordController.text;
    final conf = _confirmPasswordController.text;

    if (pass.length < 8 ||
        !RegExp(r'[A-Z]').hasMatch(pass) ||
        !RegExp(r'[a-z]').hasMatch(pass) ||
        !RegExp(r'[0-9]').hasMatch(pass)) {
      setState(() => _passwordError = 'Please ensure your password meets all requirements');
      return;
    }
    if (pass != conf) {
      setState(() => _confirmPasswordError = 'Passwords do not match');
      return;
    }

    await _submitRegister();
  }

  Future<void> _submitRegister() async {
    final success = await ref.read(authProvider.notifier).register(
          name: _nameController.text.trim(),
          email: '',
          username: _usernameController.text.trim(),
          role: UserRole.member.apiValue,
          password: _passwordController.text,
          passwordConfirmation: _confirmPasswordController.text,
          registrationSessionId: _registrationSessionId,
        );

    if (success && mounted) {
      context.go('/app');
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
    final phoneRegistrationEnabled = config?.isRegistrationEnabled('phone_otp') ?? true;

    final title = switch (_step) {
      1 => 'Verify your number',
      2 => 'Enter the code',
      3 => 'Claim your space',
      4 => 'What is your name?',
      5 => 'Secure your account',
      _ => 'Create Account',
    };

    final subtitle = switch (_step) {
      1 => 'We\'ll text you a code to verify your number.',
      2 => 'We sent a 6-digit code to $_maskedPhone.',
      3 => 'Choose your unique username to get started.',
      4 => 'This will be displayed on your profile.',
      5 => 'Choose a strong password.',
      _ => '',
    };

    return Scaffold(
      appBar: AppBar(
        leading: _step > 1
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: authState.loading ? null : _prevStep,
              )
            : IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => context.go('/auth/login'),
              ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (index) {
            final active = index + 1 <= _step;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              height: 4,
              width: active ? 24 : 12,
              decoration: BoxDecoration(
                color: active ? DesignTokens.primary : DesignTokens.border,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: DesignTokens.navy,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: DesignTokens.textSecondary,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            if (authState.errorMessage != null && _step != 2 && _step != 1) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Container(
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
              ),
              const SizedBox(height: 16),
            ],
            if (!phoneRegistrationEnabled && _step == 1)
              const Expanded(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Text(
                      'Registration via mobile number is currently disabled.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: DesignTokens.danger, fontSize: 16),
                    ),
                  ),
                ),
              )
            else
              Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1Phone(authState.loading),
                  _buildStep2Otp(authState.loading),
                  _buildStep3Username(authState.loading),
                  _buildStep4Name(authState.loading),
                  _buildStep5Password(authState.loading),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Step Builders ---

  Widget _buildStep1Phone(bool loading) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: _phoneFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IntlPhoneField(
              decoration: const InputDecoration(
                labelText: 'Mobile number',
                border: OutlineInputBorder(
                  borderSide: BorderSide(),
                ),
              ),
              initialCountryCode: widget.initialCountryIso2 ?? 'NG',
              onChanged: (phone) {
                setState(() {
                  _phoneE164 = phone.completeNumber;
                  if (_phoneError != null) _phoneError = null;
                });
              },
            ),
            InlineFieldError(error: _phoneError ?? ref.watch(authProvider).errorMessage),
            const SizedBox(height: 16),
            const Text(
              'By continuing you agree to receive an SMS verification code. Standard message and data rates may apply.',
              style: TextStyle(fontSize: 11, color: DesignTokens.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: loading || _phoneE164.isEmpty ? null : _handleRequestOtp,
              icon: loading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const SizedBox.shrink(),
              label: const Text('Send verification code'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.go('/auth/login'),
              child: const Text('Already have an account? Sign In'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2Otp(bool loading) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: _otpFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
              onCompleted: (_) => _handleVerifyOtp(),
            ),
            InlineFieldError(error: _otpError ?? ref.read(authProvider).errorMessage),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: loading ? null : _prevStep,
                    child: const Text('Change number'),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: (loading || _resendIn > 0) ? null : _resendOtp,
                    child: Text(_resendIn > 0 ? 'Resend in ${_resendIn}s' : 'Resend code'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: loading ? null : _handleVerifyOtp,
              child: loading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Verify number'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep3Username(bool loading) {
    Widget? suffix;
    String? helper;
    Color helperColor = DesignTokens.textSecondary;

    switch (_usernameCheck) {
      case _UsernameCheck.checking:
        suffix = const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)));
        helper = 'Checking availability…';
        break;
      case _UsernameCheck.available:
        suffix = const Icon(Icons.check_circle, color: Colors.green, size: 22);
        helper = 'Username is available!';
        helperColor = Colors.green.shade700;
        break;
      case _UsernameCheck.taken:
        suffix = const Icon(Icons.cancel, color: Colors.red, size: 22);
        helper = 'Username is taken. Try another one.';
        helperColor = Colors.red.shade700;
        break;
      case _UsernameCheck.invalid:
        suffix = const Icon(Icons.info_outline, color: Colors.orange, size: 22);
        helper = '3–50 characters. Letters, numbers and underscores only.';
        helperColor = Colors.orange.shade800;
        break;
      case _UsernameCheck.idle:
        break;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: _usernameFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: 'Username',
                hintText: 'e.g. johndoe',
                prefixText: '@ ',
                suffixIcon: suffix,
                helperText: helper,
                helperMaxLines: 2,
                helperStyle: TextStyle(fontSize: 12, color: helperColor, height: 1.25),
              ),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _usernameCheck == _UsernameCheck.available ? _handleNextUsername : null,
              child: const Text('Claim Username'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep4Name(bool loading) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: _nameFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _handleNextName,
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep5Password(bool loading) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: _passwordFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              onChanged: (_) {
                setState(() {
                  if (_passwordError != null) _passwordError = null;
                });
              },
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PASSWORD REQUIREMENTS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _RequirementItem(
                    label: 'At least 8 characters',
                    isMet: _passwordController.text.length >= 8,
                  ),
                  const SizedBox(height: 4),
                  _RequirementItem(
                    label: 'One uppercase letter',
                    isMet: RegExp(r'[A-Z]').hasMatch(_passwordController.text),
                  ),
                  const SizedBox(height: 4),
                  _RequirementItem(
                    label: 'One lowercase letter',
                    isMet: RegExp(r'[a-z]').hasMatch(_passwordController.text),
                  ),
                  const SizedBox(height: 4),
                  _RequirementItem(
                    label: 'One number',
                    isMet: RegExp(r'[0-9]').hasMatch(_passwordController.text),
                  ),
                ],
              ),
            ),
            InlineFieldError(error: _passwordError),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm Password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              onChanged: (_) {
                if (_confirmPasswordError != null) setState(() => _confirmPasswordError = null);
              },
            ),
            InlineFieldError(error: _confirmPasswordError),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: loading ? null : _handleNextPassword,
              child: loading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Create Account'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final UserRole role;
  final bool selected;
  final VoidCallback onTap;

  const _RoleChip({
    required this.role,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? DesignTokens.primary : DesignTokens.surface,
            border: Border.all(
              color: selected ? DesignTokens.primary : DesignTokens.border,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(
                switch (role) {
                  UserRole.member => Icons.person_outline,
                  UserRole.creator => Icons.brush_outlined,
                  UserRole.vendor => Icons.storefront_outlined,
                  UserRole.admin => Icons.admin_panel_settings_outlined,
                },
                size: 22,
                color: selected ? Colors.white : DesignTokens.textSecondary,
              ),
              const SizedBox(height: 6),
              Text(
                role.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : DesignTokens.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequirementItem extends StatelessWidget {
  final String label;
  final bool isMet;

  const _RequirementItem({required this.label, required this.isMet});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          isMet ? Icons.check_circle : Icons.cancel,
          size: 14,
          color: isMet ? Colors.green : Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isMet ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
