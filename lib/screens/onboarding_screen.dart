import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../components/brand.dart';
import '../core/design_tokens.dart';

const _secureStorage = FlutterSecureStorage();
const _onboardingSeenKey = 'murihspace_onboarding_seen';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final TapGestureRecognizer _privacyRecognizer;
  late final TapGestureRecognizer _termsRecognizer;

  @override
  void initState() {
    super.initState();
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () => _launchUrl(context, 'https://murihspace.com/legal/privacy');
    _termsRecognizer = TapGestureRecognizer()
      ..onTap = () => _launchUrl(context, 'https://murihspace.com/legal/terms');
  }

  @override
  void dispose() {
    _privacyRecognizer.dispose();
    _termsRecognizer.dispose();
    super.dispose();
  }

  Future<void> _markSeen() async {
    try {
      await _secureStorage.write(key: _onboardingSeenKey, value: 'true');
    } catch (_) {}
  }

  Future<void> _agreeAndContinue(BuildContext context) async {
    await _markSeen();
    if (context.mounted) context.go('/auth/register');
  }

  Future<void> _signIn(BuildContext context) async {
    await _markSeen();
    if (context.mounted) context.go('/auth/login');
  }

  Future<void> _launchUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (opened || !context.mounted) return;
    } catch (_) {
      if (!context.mounted) return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open the link.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF081826) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF102840);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF61758A);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // App Icon / Logo
              BrandLogo(height: 60, isDark: isDark),
              const SizedBox(height: 24),

              // Headline
              Text(
                'Welcome to MurihSpace',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: textPrimary,
                  height: 1.2,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Connect Safely.',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: DesignTokens.primary,
                ),
                textAlign: TextAlign.center,
              ),

              const Spacer(flex: 3),

              // Privacy / Terms Text
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 13,
                    color: textSecondary,
                    height: 1.6,
                  ),
                  children: [
                    const TextSpan(text: 'Read our '),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: const TextStyle(
                        color: DesignTokens.primary,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                      recognizer: _privacyRecognizer,
                    ),
                    const TextSpan(
                      text: '. Tap \'Agree and continue\' to accept the ',
                    ),
                    TextSpan(
                      text: 'Terms of Service',
                      style: const TextStyle(
                        color: DesignTokens.primary,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                      recognizer: _termsRecognizer,
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Agree and Continue CTA
              FilledButton(
                onPressed: () => _agreeAndContinue(context),
                style: FilledButton.styleFrom(
                  backgroundColor: DesignTokens.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('Agree and continue'),
              ),
              const SizedBox(height: 16),

              // Sign In link
              TextButton(
                onPressed: () => _signIn(context),
                child: Text(
                  'Already have an account? Sign in',
                  style: TextStyle(
                    fontSize: 14,
                    color: textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
