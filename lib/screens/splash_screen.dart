import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../components/brand.dart';
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
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.35),
      end: Offset.zero,
    ).chain(CurveTween(curve: Curves.easeOutBack)).animate(_controller);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = ref.watch(authProvider);
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF081826) : Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/brand/app_splash.png',
                width: 200,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 24),
              SlideTransition(
                position: _slide,
                child: Column(
                  children: [
                    Text(
                      'Connect. Create. Sell. Belong.',
                      style: TextStyle(
                        color: isDark
                            ? Colors.white60
                            : DesignTokens.textSecondary,
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
    );
  }
}
