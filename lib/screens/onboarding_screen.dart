import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

import '../core/design_tokens.dart';

const _secureStorage = FlutterSecureStorage();
const _onboardingSeenKey = 'murihspace_onboarding_seen';

class _Slide {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _Slide(this.icon, this.title, this.description, this.color);
}

const _slides = [
  _Slide(
    Icons.forum,
    'Conversations that bring people together.',
    'Private chats, group conversations, voice notes, reactions and calls.',
    DesignTokens.primary,
  ),
  _Slide(
    Icons.groups,
    'Create spaces your audience belongs to.',
    'Communities, channels, events, audio rooms and live sessions.',
    Color(0xFF8B5CF6),
  ),
  _Slide(
    Icons.payments_outlined,
    'Turn your ideas and audience into income.',
    'Gifts, subscriptions, digital products, physical products and coaching.',
    Color(0xFF22A06B),
  ),
  _Slide(
    Icons.storefront_outlined,
    'Everything in one space.',
    'Your people, content, store and business — together.',
    Color(0xFF237DA7),
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _markSeen() async {
    try {
      await _secureStorage.write(key: _onboardingSeenKey, value: 'true');
    } catch (_) {
      // Non-fatal: user may see onboarding again.
    }
  }

  Future<void> _createAccount() async {
    await _markSeen();
    if (mounted) context.go('/auth/register');
  }

  Future<void> _signIn() async {
    await _markSeen();
    if (mounted) context.go('/auth/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.surface,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _signIn,
                child: const Text('Skip'),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (ctx, i) {
                  final slide = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 36),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: slide.color.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(slide.icon, size: 56, color: slide.color),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          slide.title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: DesignTokens.textPrimary,
                            height: 1.25,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          slide.description,
                          style: const TextStyle(
                            fontSize: 15,
                            color: DesignTokens.textSecondary,
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _slides.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _page ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _page ? DesignTokens.primary : DesignTokens.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: _page == _slides.length - 1
                        ? _createAccount
                        : () {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                            );
                          },
                    child: Text(
                      _page == _slides.length - 1 ? 'Create account' : 'Continue',
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _signIn,
                    child: const Text('Sign in'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
