import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';

import 'config/env.dart';
import 'config/router.dart';
import 'config/theme.dart';
import 'providers/security_provider.dart';
import 'components/app_lock_overlay.dart';
import 'components/gift_animation_overlay.dart';
import 'components/in_app_notification_overlay.dart';
import 'components/incoming_call_overlay.dart';
import 'components/floating_call_overlay.dart';
import 'components/floating_live_overlay.dart';
import 'core/api_client.dart';
import 'package:go_router/go_router.dart';
import 'models/notification_models.dart';
import 'providers/appearance_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/calls_provider.dart';
import 'providers/messages_provider.dart';
import 'providers/notifications_provider.dart';
import 'providers/realtime_provider.dart';
import 'services/sound_service.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/push_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await PushService.handleBackgroundMessage(message);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await PushService.instance.initialize();
  } catch (e) {
    debugPrint('[Firebase] Initialization error: $e');
  }
  try {
    await LiveKitClient.initialize(
      initialAudioSessionOptions: const AudioSessionOptions.communication(),
    );
  } catch (e) {
    debugPrint('[LiveKitClient] Initialization error: $e');
  }
  final savedEnv = await ApiClient.readApiEnv();
  if (savedEnv != null && savedEnv.isNotEmpty) {
    Env.setRuntimeEnv(savedEnv);
    ApiClient.instance.updateBaseUrl(Env.apiBaseUrl);
  }
  runApp(
    const ProviderScope(
      child: MurihSpaceApp(),
    ),
  );
}

class MurihSpaceApp extends ConsumerStatefulWidget {
  const MurihSpaceApp({super.key});

  @override
  ConsumerState<MurihSpaceApp> createState() => _MurihSpaceAppState();
}

class _MurihSpaceAppState extends ConsumerState<MurihSpaceApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Surface an in-app ringing banner when a call push arrives while the app
    // is foregrounded (realtime socket is usually the primary path, but this
    // covers the case where it missed the broadcast).
    PushService.instance.onIncomingCallForeground = _handleForegroundCallData;
    // Clear any in-app call state when the call is declined/ended from the OS
    // call UI.
    PushService.instance.onExternalCallEnded = _handleExternalCallEnded;

    // Handle regular push notifications while foregrounded
    PushService.instance.onNotificationForeground = _handleForegroundNotification;
    // Handle tapping an OS push notification to open the app
    PushService.instance.onNotificationOpened = _handleNotificationOpened;

    // If the app was cold-started by answering a CallKit call, the navigator
    // is not mounted when the accept event arrives; replay it after first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PushService.instance.processPendingAcceptedCall();
    });
  }

  void _handleForegroundNotification(Map<String, dynamic> data, RemoteNotification? notification) {
    final title = notification?.title ?? data['title']?.toString() ?? '';
    final body = notification?.body ?? data['body']?.toString() ?? data['message']?.toString() ?? '';
    final notif = AppNotification.fromJson({
      ...data,
      if (data['title'] == null && title.isNotEmpty) 'title': title,
      if (data['body'] == null && body.isNotEmpty) 'body': body,
    });

    // Play alert sound
    SoundService.instance.playNotification();

    // Show in-app banner
    ref.read(inAppNotificationProvider.notifier).showFromAppNotification(notif);

    // Optimistically update notifications provider and sync
    ref.read(notificationsProvider.notifier).addNotification(notif);
    ref.read(notificationsProvider.notifier).sync();
  }

  void _handleNotificationOpened(Map<String, dynamic> data) {
    ref.read(notificationsProvider.notifier).sync();
    final route = data['route']?.toString() ?? data['action_url']?.toString();
    final ctx = rootNavigatorKey.currentContext;
    if (ctx != null && ctx.mounted) {
      if (route != null && route.isNotEmpty) {
        ctx.push(route);
      } else {
        ctx.push('/profile/notifications');
      }
    }
  }

  void _handleForegroundCallData(Map<String, dynamic> data) {
    final callId = int.tryParse((data['call_id'] ?? '').toString());
    if (callId == null || callId <= 0) return;
    ref.read(callsProvider.notifier).handleIncomingCall({
      'call': {
        'id': callId,
        'room_name': data['room_name'],
        'caller_id': int.tryParse((data['caller_id'] ?? '').toString()),
        'type': (data['is_video'] == 'true' || data['is_video'] == true) ? 'video' : 'audio',
        'conversation_id': int.tryParse((data['conversation_id'] ?? '').toString()),
      },
      'caller': {
        'name': data['caller_name'],
        'avatar_url': data['caller_avatar'],
      },
      'livekit_token': data['livekit_token'],
      'livekit_host': data['livekit_host'],
    });
  }

  void _handleExternalCallEnded(Map<String, dynamic> extra) {
    final callId = int.tryParse((extra['call_id'] ?? '').toString());
    final active = ref.read(callsProvider).activeCall;
    if (active == null) return;
    if (callId != null && active.callId != callId) return;
    // When only a CallKit UUID is available (unparseable), end the call only if
    // it is still incoming — never mid-conversation over an ambiguous signal.
    if (callId == null && active.status != 'incoming') return;
    ref.read(callsProvider.notifier).handleCallEnded({'call': {'id': active.callId}});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      ref.read(securityProvider.notifier).onAppBackgrounded();
    } else if (state == AppLifecycleState.resumed) {
      ref.read(securityProvider.notifier).onAppForegrounded();
      ref.read(realtimeProvider).onAppResume();
      ref.read(conversationsProvider.notifier).refresh();
      ref.read(notificationsProvider.notifier).sync();
      final activeId = ref.read(realtimeProvider).activeConversationId;
      if (activeId != null) {
        ref.read(conversationMessagesProvider(activeId).notifier).catchUp();
      }
      PushService.instance.processPendingAcceptedCall();
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

    // Automatically manage real-time notifications for authenticated user
    ref.listen(authProvider, (previous, next) {
      final user = next.user;
      if (user != null) {
        ref.read(realtimeProvider).listenToUser(user.id);
        PushService.instance.syncToken();
      } else {
        ref.read(realtimeProvider).dispose();
      }
    });

    final currentUser = ref.watch(authProvider).user;
    if (currentUser != null) {
      ref.read(realtimeProvider).listenToUser(currentUser.id);
      PushService.instance.syncToken();
    }

    final appearance = ref.watch(appearanceProvider);

    return MaterialApp.router(
      title: Env.appName,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: appearance.flutterThemeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        return AppLockOverlay(
          child: IncomingCallOverlay(
            child: InAppNotificationOverlay(
              child: GiftAnimationOverlay(
                child: FloatingCallOverlay(
                  child: FloatingLiveOverlay(child: child),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
