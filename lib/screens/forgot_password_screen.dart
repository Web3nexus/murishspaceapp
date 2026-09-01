import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/design_tokens.dart';

/// Requests a password-reset link for an email address.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _sent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ApiClient.instance.dio.post(
        '/auth/forgot-password',
        data: {'email': _emailController.text.trim()},
      );
      ApiClient.instance.unwrap(response);
      if (mounted) setState(() => _sent = true);
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.response?.data is Map<String, dynamic>
              ? (e.response?.data as Map<String, dynamic>)['message'] as String?
              : 'Could not send the reset link.';
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Network error. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot Password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _sent ? _sentView() : _formView(),
        ),
      ),
    );
  }

  Widget _formView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = DesignTokens.textPrimaryOf(isDark);
    final textSecondary = DesignTokens.textSecondaryOf(isDark);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.lock_reset, size: 56, color: DesignTokens.primary),
          const SizedBox(height: 20),
          Text(
            'Reset your password',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Enter your email address and we will send you a secure link to choose a new password.',
            style: TextStyle(color: textSecondary, height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: DesignTokens.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_error!, style: const TextStyle(color: DesignTokens.danger)),
            ),
            const SizedBox(height: 16),
          ],
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email Address',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Email is required';
              if (!v.contains('@')) return 'Enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Send reset link'),
          ),
        ],
      ),
    );
  }

  Widget _sentView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.mark_email_read_outlined, size: 56, color: DesignTokens.success),
        const SizedBox(height: 20),
        const Text(
          'Check your inbox',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: DesignTokens.textPrimary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'If an account exists for ${_emailController.text.trim()}, a reset link is on its way.',
          style: const TextStyle(color: DesignTokens.textSecondary, height: 1.4),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('Back to sign in'),
        ),
      ],
    );
  }
}
