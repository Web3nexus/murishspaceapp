import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';

class GreetingState {
  final bool isEnabled;
  final String message;
  final int delaySeconds;

  const GreetingState({
    this.isEnabled = false,
    this.message = 'Hi {name}! Thanks for reaching out. How can we help you today?',
    this.delaySeconds = 0,
  });

  GreetingState copyWith({
    bool? isEnabled,
    String? message,
    int? delaySeconds,
  }) {
    return GreetingState(
      isEnabled: isEnabled ?? this.isEnabled,
      message: message ?? this.message,
      delaySeconds: delaySeconds ?? this.delaySeconds,
    );
  }
}

class GreetingNotifier extends Notifier<GreetingState> {
  static const String _keyEnabled = 'auto_greeting_enabled';
  static const String _keyMessage = 'auto_greeting_message';
  static const String _keyDelay = 'auto_greeting_delay';

  @override
  GreetingState build() {
    _loadSettings();
    return const GreetingState();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_keyEnabled) ?? false;
    final msg = prefs.getString(_keyMessage) ??
        'Hi {name}! Thanks for reaching out. How can we help you today?';
    final delay = prefs.getInt(_keyDelay) ?? 0;

    state = GreetingState(
      isEnabled: enabled,
      message: msg,
      delaySeconds: delay,
    );
  }

  Future<void> updateSettings({
    required bool isEnabled,
    required String message,
    int delaySeconds = 0,
  }) async {
    state = state.copyWith(
      isEnabled: isEnabled,
      message: message,
      delaySeconds: delaySeconds,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, isEnabled);
    await prefs.setString(_keyMessage, message);
    await prefs.setInt(_keyDelay, delaySeconds);

    // Optionally sync with backend if online
    try {
      await ApiClient.instance.dio.post('/user/settings/greeting', data: {
        'auto_greeting_enabled': isEnabled,
        'auto_greeting_message': message,
        'auto_greeting_delay_seconds': delaySeconds,
      });
    } catch (_) {
      // Optimistic offline save succeeded
    }
  }
}

final greetingProvider = NotifierProvider<GreetingNotifier, GreetingState>(
  GreetingNotifier.new,
);
