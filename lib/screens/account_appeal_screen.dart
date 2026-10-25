import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/api_client.dart';
import '../core/design_tokens.dart';

/// Shown instead of the code screen when the number belongs to a suspended account.
/// Nothing is sent to the phone; the person explains why the account should be reinstated.
class AccountAppealScreen extends StatefulWidget {
  const AccountAppealScreen({super.key, required this.phoneE164});

  final String phoneE164;

  @override
  State<AccountAppealScreen> createState() => _AccountAppealScreenState();
}

class _AccountAppealScreenState extends State<AccountAppealScreen> {
  final _emailController = TextEditingController();
  final _controller = TextEditingController();
  bool _sending = false;
  bool _sent = false;
  String? _emailError;
  String? _messageError;

  @override
  void dispose() {
    _emailController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final message = _controller.text.trim();
    if (!email.contains('@')) {
      setState(() => _emailError = 'Enter the email address on your account.');
      return;
    }
    if (message.length < 20) {
      setState(
        () => _messageError = 'Please explain in at least 20 characters.',
      );
      return;
    }

    setState(() {
      _sending = true;
      _emailError = null;
      _messageError = null;
    });

    try {
      await ApiClient.instance.dio.post(
        '/auth/account/appeals',
        data: {
          'phone_e164': widget.phoneE164,
          'email': email,
          'message': message,
        },
      );
      if (mounted) {
        setState(() {
          _sending = false;
          _sent = true;
        });
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      final serverMessage = data is Map && data['message'] is String
          ? data['message'] as String
          : null;
      if (mounted) {
        setState(() {
          _sending = false;
          _messageError =
              serverMessage ?? 'Could not send your appeal. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      appBar: AppBar(title: const Text('Appeal suspension')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _sent ? _buildSent(textSecondary) : _buildForm(textSecondary),
        ),
      ),
    );
  }

  Widget _buildForm(Color textSecondary) {
    return ListView(
      children: [
        const Text(
          'Your account is suspended',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Text(
          'You cannot sign in while the suspension is in place. Tell our account team why your account should be reinstated. '
          'They will review it and email you the decision.',
          style: TextStyle(fontSize: 14, height: 1.4, color: textSecondary),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: 'Email on your account',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DesignTokens.rMd),
            ),
            errorText: _emailError,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _controller,
          maxLines: 6,
          maxLength: 2000,
          decoration: InputDecoration(
            hintText: 'Explain what happened and why it should be reviewed',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DesignTokens.rMd),
            ),
            errorText: _messageError,
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _sending ? null : _submit,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            backgroundColor: DesignTokens.primary,
          ),
          child: Text(_sending ? 'Sending…' : 'Send appeal'),
        ),
      ],
    );
  }

  Widget _buildSent(Color textSecondary) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.check_circle_rounded,
          size: 56,
          color: DesignTokens.success,
        ),
        const SizedBox(height: 16),
        const Text(
          'Appeal received',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Text(
          'The account team will review it and email you the decision. You can sign in again once the suspension is lifted.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, height: 1.4, color: textSecondary),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => context.go('/auth/login'),
          child: const Text('Back to sign in'),
        ),
      ],
    );
  }
}
