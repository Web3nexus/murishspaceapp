import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/providers/platform_provider.dart';
import 'package:mobile/screens/forgot_password_screen.dart';

/// The password-reset screen used to render its email form unconditionally.
///
/// Gating the login form was not enough: the screen is reachable by route, so a
/// phone-only platform still showed an email field that the server rejects.
void main() {
  PlatformConfig configWithEmailLogin({required bool emailLogin}) {
    return PlatformConfig(
      primaryMethod: 'phone_otp',
      methods: {
        'phone_otp': AuthMethodConfig(login: true, registration: true),
        'email_password': AuthMethodConfig(
          login: emailLogin,
          registration: emailLogin,
        ),
      },
    );
  }

  Future<void> pump(WidgetTester tester, {required bool emailLogin}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          platformProvider.overrideWith(
            () => FakePlatformNotifier(configWithEmailLogin(emailLogin: emailLogin)),
          ),
        ],
        child: const MaterialApp(home: ForgotPasswordScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the email form when email/password login is enabled',
      (tester) async {
    await pump(tester, emailLogin: true);

    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.textContaining('unavailable'), findsNothing);
  });

  testWidgets('hides the email form when the platform is phone-only',
      (tester) async {
    await pump(tester, emailLogin: false);

    expect(find.byType(TextFormField), findsNothing);
    expect(find.textContaining('Password reset by email is currently unavailable'),
        findsOneWidget);
  });

  testWidgets('a loading config never flashes the email form', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          platformProvider.overrideWith(() => LoadingPlatformNotifier()),
        ],
        child: const MaterialApp(home: ForgotPasswordScreen()),
      ),
    );
    await tester.pump();

    expect(find.byType(TextFormField), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('a failed config fetch fails open so recovery stays reachable',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          platformProvider.overrideWith(() => NullConfigPlatformNotifier()),
        ],
        child: const MaterialApp(home: ForgotPasswordScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // No config could be loaded; a hard block here would lock every user out
    // of password recovery during a platform outage.
    expect(find.byType(TextFormField), findsOneWidget);
  });
}

class FakePlatformNotifier extends PlatformNotifier {
  final PlatformConfig _config;
  FakePlatformNotifier(this._config);

  @override
  PlatformState build() => PlatformState(config: _config);
}

class LoadingPlatformNotifier extends PlatformNotifier {
  @override
  PlatformState build() => PlatformState(isLoading: true);
}

class NullConfigPlatformNotifier extends PlatformNotifier {
  @override
  PlatformState build() =>
      PlatformState(error: 'network unreachable', config: null);
}
