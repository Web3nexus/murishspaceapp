import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/roles.dart';
import 'package:mobile/main.dart';
import 'package:mobile/providers/auth_provider.dart';
import 'package:mobile/providers/chat_provider.dart';
import 'package:mobile/providers/platform_provider.dart';
import 'package:mobile/screens/chats_screen.dart';
import 'package:mobile/screens/onboarding_screen.dart';

void main() {
  testWidgets('App routes to onboarding when signed out', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(() => _SignedOutAuthNotifier()),
          platformProvider.overrideWith(_StubPlatformNotifier.new),
        ],
        child: const MaterialApp(home: OnboardingScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Agree and continue'), findsOneWidget);
    expect(find.textContaining('Sign in'), findsOneWidget);
  });

  testWidgets('App routes to the shell when signed in', (tester) async {
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exception is NetworkImageLoadException) return;
      originalOnError?.call(details);
    };
    final user = UserProfile(
      id: 1,
      name: 'Vincent Paul',
      email: 'vp@example.com',
      username: 'vincentpaul',
      role: UserRole.creator,
      kycStatus: 'verified',
      emailVerified: true,
      onboardingCompleted: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(() => _SignedInAuthNotifier(user)),
          conversationsProvider.overrideWith(_EmptyConversationsNotifier.new),
          platformProvider.overrideWith(_StubPlatformNotifier.new),
        ],
        child: const MaterialApp(home: ChatsScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Messages'), findsWidgets);
    expect(find.text('No conversations yet'), findsOneWidget);
  });
}

class _SignedInAuthNotifier extends AuthNotifier {
  final UserProfile profile;

  _SignedInAuthNotifier(this.profile);

  @override
  AuthState build() {
    return AuthState(user: profile, token: 'test-token');
  }
}

class _SignedOutAuthNotifier extends AuthNotifier {
  @override
  AuthState build() {
    return const AuthState();
  }
}

class _EmptyConversationsNotifier extends ConversationsNotifier {
  @override
  ConversationsState build() {
    return const ConversationsState();
  }
}

class _StubPlatformNotifier extends PlatformNotifier {
  @override
  PlatformState build() {
    return PlatformState(
      config: PlatformConfig(primaryMethod: 'phone_otp', methods: {}),
      isLoading: false,
    );
  }
}
