/// Pure visibility rules for the login and registration screens.
///
/// Extracted from `LoginScreen.build` so the method matrix can be unit tested
/// without pumping a widget. `email_password` is a *member* method: when the
/// platform disables it the option must disappear entirely for app users.
/// Admins do not sign in through the app (the Securegate portal posts to the
/// web `/auth/login` endpoint), so no admin carve-out belongs here.
///
/// The same rules drive the register and forgot-password screens. Those were
/// previously ungated, so switching the platform to phone-only still showed
/// email fields on sign-up and password reset.
library;

class LoginMethodVisibility {
  const LoginMethodVisibility({
    required this.phoneEnabled,
    required this.emailEnabled,
    required this.googleEnabled,
    required this.appleEnabled,
  });

  final bool phoneEnabled;
  final bool emailEnabled;
  final bool googleEnabled;
  final bool appleEnabled;

  /// Resolves the effective tab, redirecting off a tab that is disabled.
  ///
  /// Returns 0 (phone) or 1 (email). When both are disabled there is nothing
  /// to show, so the current tab is returned unchanged and
  /// [anyMethodEnabled] reports false.
  int resolveTabIndex(int current) {
    if (current == 0 && !phoneEnabled && emailEnabled) return 1;
    if (current == 1 && !emailEnabled && phoneEnabled) return 0;
    return current;
  }

  /// True when at least one sign-in method is usable. When false the screen
  /// renders the "Login is currently disabled" notice.
  ///
  /// Social providers count: the social buttons are rendered from a separate
  /// [showSocial] check, so a social-only configuration must not be reported
  /// as unavailable while a working Google button sits below the notice.
  bool get anyMethodEnabled =>
      phoneEnabled || emailEnabled || googleEnabled || appleEnabled;

  /// The phone/email tab switcher is pointless with a single method.
  bool get showTabSwitcher => phoneEnabled && emailEnabled;

  /// True when the email + password form (and its tab) may be rendered.
  bool get showEmailPassword => emailEnabled;

  bool get showPhone => phoneEnabled;

  bool get showSocial => googleEnabled || appleEnabled;

  /// Password reset is only possible over email: the code is delivered by
  /// email. When email/password is disabled there is no reset link to send, so
  /// the screen must not offer the flow.
  bool get canResetPassword => emailEnabled;
}
