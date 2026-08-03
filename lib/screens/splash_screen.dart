import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/design_tokens.dart';
import '../providers/auth_provider.dart';

/// Branded splash: animated logo + wordmark, then routes based on auth state.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.35), end: Offset.zero)
        .chain(CurveTween(curve: Curves.easeOutBack))
        .animate(_controller);
    _controller.forward();

    _timer = Timer(const Duration(milliseconds: 1600), _maybeRoute);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _maybeRoute() {
    if (!mounted) return;
    final auth = ref.read(authProvider);
    if (auth.loading) {
      _timer = Timer(const Duration(milliseconds: 120), _maybeRoute);
      return;
    }
    context.go(auth.token != null ? '/app/chats' : '/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, DesignTokens.primarySoft],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: DesignTokens.primary,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: DesignTokens.primary.withValues(alpha: 0.35),
                        blurRadius: 28,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.forum, color: Colors.white, size: 52),
                ),
                const SizedBox(height: 24),
                SlideTransition(
                  position: _slide,
                  child: Column(
                    children: [
                      Text(
                        'MurihSpace',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: DesignTokens.navy,
                              fontSize: 30,
                              letterSpacing: -0.5,
                            ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Connect. Create. Sell. Belong.',
                        style: TextStyle(
                          color: DesignTokens.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
