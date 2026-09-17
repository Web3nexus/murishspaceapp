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
import 'core/api_client.dart';
import 'providers/auth_provider.dart';
import 'providers/realtime_provider.dart';

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
      } else {
        ref.read(realtimeProvider).dispose();
      }
    });

    final currentUser = ref.watch(authProvider).user;
    if (currentUser != null) {
      ref.read(realtimeProvider).listenToUser(currentUser.id);
    }

    return MaterialApp.router(
      title: Env.appName,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        return AppLockOverlay(
          child: IncomingCallOverlay(
            child: InAppNotificationOverlay(
              child: GiftAnimationOverlay(child: child),
            ),
          ),
        );
      },
    );
  }
}
