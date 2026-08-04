import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/env.dart';
import 'config/router.dart';
import 'config/theme.dart';

void main() {
  runApp(
    const ProviderScope(
      child: MurihSpaceApp(),
    ),
  );
}

class MurihSpaceApp extends ConsumerWidget {
  const MurihSpaceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: Env.appName,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      // Dark theme is not fully implemented yet (partial scaffold/appbar only).
      // Keep the app in light mode until dark-mode tokens are complete.
      themeMode: ThemeMode.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
