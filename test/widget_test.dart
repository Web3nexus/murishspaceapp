import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/roles.dart';
import 'package:mobile/main.dart';
import 'package:mobile/providers/auth_provider.dart';

void main() {
  testWidgets('App routes to onboarding when signed out', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(() => _SignedOutAuthNotifier()),
        ],
        child: const MurihSpaceApp(),
      ),
    );

    // Let the splash animation and auto-login resolve, and the splash timer fire.
    await tester.pump(const Duration(milliseconds: 2000));
    await tester.pumpAndSettle();

    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
  });

  testWidgets('App routes to the shell when signed in', (tester) async {
    final user = UserProfile(
      id: 1,
      name: 'Vincent Paul',
      email: 'vp@example.com',
      username: 'vincentpaul',
      role: UserRole.creator,
      kycStatus: 'verified',
      emailVerified: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(() => _SignedInAuthNotifier(user)),
        ],
        child: const MurihSpaceApp(),
      ),
    );

    // Redirect lands on the shell immediately; advance past the splash timer.
    await tester.pump(const Duration(milliseconds: 2000));
    await tester.pumpAndSettle();

    expect(find.text('Chats'), findsWidgets);
    expect(find.text('Communities'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
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
