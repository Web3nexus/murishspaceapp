import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../components/brand.dart';
import '../core/api_client.dart';
import '../core/design_tokens.dart';
import '../core/roles.dart';
import '../providers/auth_provider.dart';

enum _UsernameCheck { idle, checking, available, taken, invalid }

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  UserRole _role = UserRole.member;

  _UsernameCheck _usernameCheck = _UsernameCheck.idle;
  Timer? _usernameDebounce;

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_onUsernameChanged);
  }

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _usernameController.removeListener(_onUsernameChanged);
    _nameController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

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
          _usernameCheck = available
              ? _UsernameCheck.available
              : _UsernameCheck.taken;
        }
      });
    });
  }

  Future<bool?> _checkUsername(String username) async {
    try {
      final response = await ApiClient.instance.dio.get(
        '/check-username/$username',
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return data['available'] as bool? ?? false;
      }
    } catch (_) {
      // Network failure: fall back to server-side validation on submit.
    }
    return null;
  }

  Widget? _buildUsernameSuffix() {
    switch (_usernameCheck) {
      case _UsernameCheck.checking:
        return Padding(
          padding: const EdgeInsets.all(14),
          child: const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      case _UsernameCheck.available:
        return const Icon(Icons.check_circle, color: Colors.green, size: 22);
      case _UsernameCheck.taken:
        return const Icon(Icons.cancel, color: Colors.red, size: 22);
      case _UsernameCheck.invalid:
        return const Icon(Icons.info_outline, color: Colors.orange, size: 22);
      case _UsernameCheck.idle:
        return null;
    }
  }

  Color _usernameHelperColor() {
    switch (_usernameCheck) {
      case _UsernameCheck.available:
        return Colors.green.shade700;
      case _UsernameCheck.taken:
        return Colors.red.shade700;
      case _UsernameCheck.invalid:
        return Colors.orange.shade800;
      case _UsernameCheck.checking:
      case _UsernameCheck.idle:
        return DesignTokens.textSecondary;
    }
  }

  String? _buildUsernameHelper() {
    switch (_usernameCheck) {
      case _UsernameCheck.idle:
        return null;
      case _UsernameCheck.checking:
        return 'Checking availability…';
      case _UsernameCheck.available:
        return 'Username is available!';
      case _UsernameCheck.taken:
        return 'Username is taken. Try another one.';
      case _UsernameCheck.invalid:
        return '3–50 characters. Letters, numbers and underscores only.';
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_usernameCheck == _UsernameCheck.taken) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That username is already taken.')),
      );
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
      return;
    }

    final success = await ref
        .read(authProvider.notifier)
        .register(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          username: _usernameController.text.trim(),
          role: _role.apiValue,
          password: _passwordController.text,
          passwordConfirmation: _confirmPasswordController.text,
        );
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created successfully!')),
      );
      // The router redirects to /app/chats once the session is set.
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
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const BrandLogo(height: 36),
                  const SizedBox(height: 20),
                  const Text(
                    'Create Account',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: DesignTokens.navy,
                      letterSpacing: -0.5,
                      height: 1.1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Join MurihSpace ecosystem',
                    style: TextStyle(
                      color: DesignTokens.textSecondary,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  if (authState.errorMessage != null) ...[
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
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      hintText: 'e.g. johndoe',
                      prefixIcon: const Icon(Icons.alternate_email),
                      suffixIcon: _buildUsernameSuffix(),
                      helperText: _buildUsernameHelper(),
                      helperMaxLines: 2,
                      helperStyle: TextStyle(
                        fontSize: 12,
                        color: _usernameHelperColor(),
                        height: 1.25,
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Username is required';
                      if (v.length < 3) return 'At least 3 characters';
                      if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v)) {
                        return 'Letters, numbers and underscore only';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (val) {
                      if (val == null || val.isEmpty)
                        return 'Email is required';
                      if (!val.contains('@')) return 'Enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'I want to join as a',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: DesignTokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      for (final role in const [
                        UserRole.member,
                        UserRole.creator,
                        UserRole.vendor,
                      ])
                        Expanded(
                          child: _RoleChip(
                            role: role,
                            selected: _role == role,
                            onTap: () => setState(() => _role = role),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline),
                      helperText:
                          '8+ chars with upper, lower, number and symbol',
                      helperMaxLines: 2,
                    ),
                    obscureText: true,
                    validator: (val) {
                      if (val == null || val.isEmpty)
                        return 'Password is required';
                      if (val.length < 8) return 'At least 8 characters';
                      if (!RegExp(r'[A-Z]').hasMatch(val))
                        return 'Include an uppercase letter';
                      if (!RegExp(r'[a-z]').hasMatch(val))
                        return 'Include a lowercase letter';
                      if (!RegExp(r'[0-9]').hasMatch(val))
                        return 'Include a number';
                      if (!RegExp(r'[@$!%*#?&^_\-]').hasMatch(val))
                        return 'Include a symbol';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _confirmPasswordController,
                    decoration: const InputDecoration(
                      labelText: 'Confirm Password',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    obscureText: true,
                    validator: (val) {
                      if (val == null || val.isEmpty)
                        return 'Please confirm your password';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: authState.loading ? null : _submit,
                    child: authState.loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Register'),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => context.go('/auth/login'),
                    child: const Text('Already have an account? Sign In'),
                  ),
                ],
              ),
            ),
          ),
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
