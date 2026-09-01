import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/env.dart';
import 'config/router.dart';
import 'config/theme.dart';
import 'providers/security_provider.dart';
import 'components/app_lock_overlay.dart';
import 'components/in_app_notification_overlay.dart';

void main() {
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
          child: InAppNotificationOverlay(child: child),
        );
      },
    );
  }
}
