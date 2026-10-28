/// Feature flags and wire constants for end-to-end encryption. Read here and nowhere else.
library;

/// Encrypt text in 1:1 direct chats. Off unless the app is built with
/// `--dart-define=E2EE_DIRECT_MESSAGES=true`, so direct text keeps the plaintext path.
/// Mirrors VITE_E2EE_DIRECT_MESSAGES on the web. Receiving does not depend on it.
const bool e2eeDirectMessagesEnabled = bool.fromEnvironment('E2EE_DIRECT_MESSAGES', defaultValue: false);

/// Value of `encryption` on an encrypted message, as the backend expects it.
const String e2eeSignalEncryption = 'signal_v1';

/// Shown in place of an encrypted message this device cannot read.
const String e2eeUnreadableText = 'Encrypted message';
