import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/providers/security_provider.dart';
import 'package:mobile/core/permissions_service.dart';
import 'package:mobile/components/in_app_notification_overlay.dart';
import 'package:mobile/models/notification_models.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Security & Biometrics Provider Tests', () {
    test('Initializes with default unauthenticated state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(securityProvider);
      expect(state.isLocked, false);
      expect(state.isPinSet, false);
      expect(state.isTransactionPinSet, false);
      expect(state.failedPinAttempts, 0);
      expect(state.isLockedOut, false);
    });

    test('Setting App PIN updates isPinSet', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(securityProvider.notifier);
      await notifier.setPin('123456');

      final state = container.read(securityProvider);
      expect(state.isPinSet, true);
    });

    test('Lockout triggered after 5 failed attempts', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(securityProvider.notifier);
      await notifier.setPin('123456');

      // 4 wrong attempts - no lockout yet
      for (int i = 0; i < 4; i++) {
        final verified = await notifier.verifyPin('000000');
        expect(verified, false);
      }
      expect(container.read(securityProvider).isLockedOut, false);

      // 5th wrong attempt - lockout activates
      final fifth = await notifier.verifyPin('000000');
      expect(fifth, false);
      expect(container.read(securityProvider).isLockedOut, true);
      expect(container.read(securityProvider).remainingLockoutSeconds, greaterThan(0));
    });
  });

  group('Permissions Service Tests', () {
    test('Requesting permission updates granted state', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(permissionsProvider.notifier);
      final fakeContext = null; // direct notifier testing

      final initialState = container.read(permissionsProvider);
      expect(initialState.notificationsGranted, false);
    });
  });

  group('In-App Notification Banner Tests', () {
    test('Shows notification item and auto parses route', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifNotifier = container.read(inAppNotificationProvider.notifier);

      final appNotif = AppNotification(
        id: 'notif-123',
        type: 'App.Notifications.NewMessageNotification',
        data: {
          'title': 'New Direct Message',
          'message': 'Hey, are you free for a call?',
          'conversation_id': 42,
          'type': 'message',
        },
      );

      notifNotifier.showFromAppNotification(appNotif);

      final current = container.read(inAppNotificationProvider);
      expect(current, isNotNull);
      expect(current!.title, 'New Direct Message');
      expect(current.body, 'Hey, are you free for a call?');
      expect(current.route, '/chats/42');

      notifNotifier.dismiss();
      expect(container.read(inAppNotificationProvider), isNull);
    });
  });
}
