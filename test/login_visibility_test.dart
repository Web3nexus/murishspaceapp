import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/screens/login_visibility.dart';

/// Guards the requirement that disabling `email_password` removes the option
/// from the mobile login screen. Admins are unaffected on mobile: they use the
/// Securegate web portal, not the app.
void main() {
  LoginMethodVisibility v({
    bool phone = true,
    bool email = true,
    bool google = false,
    bool apple = false,
  }) => LoginMethodVisibility(
        phoneEnabled: phone,
        emailEnabled: email,
        googleEnabled: google,
        appleEnabled: apple,
      );

  group('email_password disabled', () {
    test('email/password form and its tab are hidden', () {
      final m = v(email: false);
      expect(m.showEmailPassword, isFalse);
      expect(m.showTabSwitcher, isFalse);
    });

    test('phone stays usable', () {
      final m = v(email: false);
      expect(m.showPhone, isTrue);
      expect(m.anyMethodEnabled, isTrue);
    });

    test('landing on the email tab redirects to phone', () {
      expect(v(email: false).resolveTabIndex(1), 0);
    });

    test('staying on the phone tab is stable (no feedback loop)', () {
      expect(v(email: false).resolveTabIndex(0), 0);
    });
  });

  group('phone_otp disabled', () {
    test('phone form hidden and landing on phone redirects to email', () {
      final m = v(phone: false);
      expect(m.showPhone, isFalse);
      expect(m.resolveTabIndex(0), 1);
      expect(m.showTabSwitcher, isFalse);
    });

    test('email alone still counts as an available method', () {
      // Guards the reverse direction: with phone off, email/password is the
      // only way in, so the screen must not claim login is unavailable.
      final m = v(phone: false);
      expect(m.anyMethodEnabled, isTrue);
      expect(m.showEmailPassword, isTrue);
    });
  });

  group('all methods disabled', () {
    test('reports the disabled notice instead of a form', () {
      final m = v(phone: false, email: false);
      expect(m.anyMethodEnabled, isFalse);
      expect(m.showTabSwitcher, isFalse);
    });

    test('resolveTabIndex does not thrash between frames', () {
      final m = v(phone: false, email: false);
      expect(m.resolveTabIndex(0), 0);
      expect(m.resolveTabIndex(1), 1);
    });
  });

  group('both enabled', () {
    test('tab switcher shown and no redirect', () {
      final m = v();
      expect(m.showTabSwitcher, isTrue);
      expect(m.resolveTabIndex(0), 0);
      expect(m.resolveTabIndex(1), 1);
    });
  });

  group('social', () {
    test('hidden when both providers are disabled', () {
      expect(v().showSocial, isFalse);
    });

    test('shown when either provider is enabled', () {
      expect(v(google: true).showSocial, isTrue);
      expect(v(apple: true).showSocial, isTrue);
    });

    test('does not resurrect a disabled email method', () {
      final m = v(email: false, google: true);
      expect(m.showSocial, isTrue);
      expect(m.showEmailPassword, isFalse);
    });
  });

  group('social-only login', () {
    // Regression guard: the "Login is currently disabled" notice is driven by
    // anyMethodEnabled while the buttons are driven by showSocial. If the two
    // disagree, a social-only config shows a working Google button underneath
    // a bogus "login is disabled" message.
    test('is still considered an available method', () {
      final m = v(phone: false, email: false, google: true);
      expect(m.showSocial, isTrue);
      expect(m.anyMethodEnabled, isTrue);
    });

    test('agrees with showSocial in every combination', () {
      for (final google in [true, false]) {
        for (final apple in [true, false]) {
          final m = v(phone: false, email: false, google: google, apple: apple);
          expect(
            m.anyMethodEnabled,
            m.showSocial,
            reason: 'google=$google apple=$apple must not disagree',
          );
        }
      }
    });

    test('apple alone also counts', () {
      expect(v(phone: false, email: false, apple: true).anyMethodEnabled, isTrue);
    });
  });
}
