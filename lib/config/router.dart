import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../components/navigation_shell.dart';
import '../providers/auth_provider.dart';
import '../screens/chats_screen.dart';
import '../screens/communities_screen.dart';
import '../screens/community_detail_screen.dart';
import '../screens/conversation_screen.dart';
import '../screens/create_screen.dart';
import '../screens/discover_screen.dart';
import '../screens/forgot_password_screen.dart';
import '../screens/gifts_screen.dart';
import '../screens/kyc_screen.dart';
import '../screens/login_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/register_screen.dart';
import '../screens/saved_posts_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/wallet_screen.dart';
import '../screens/you_screen.dart';

/// Notifies the router whenever auth state changes so redirects re-evaluate.
final _routerRefresh = _RouterRefresh();
class _RouterRefresh extends ChangeNotifier {
  void refresh() => notifyListeners();
}

final appRouterProvider = Provider<GoRouter>((ref) {
  ref.listen(authProvider, (_, _) => _routerRefresh.refresh());

  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: _routerRefresh,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final path = state.uri.path;
      final loggedIn = auth.token != null;

      // Keep the splash on screen while auto-login resolves.
      if (auth.loading) return null;

      final isAuthEntry = path == '/onboarding' || path.startsWith('/auth/');
      if (loggedIn && (isAuthEntry || path == '/splash')) return '/app/chats';
      if (!loggedIn && (path.startsWith('/app') || path == '/wallet' || path == '/gifts' || path == '/profile' || path == '/kyc')) {
        return '/auth/login';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, _) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (_, _) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/auth/login',
        builder: (_, _) => const LoginScreen(),
      ),
      GoRoute(
        path: '/auth/register',
        builder: (_, _) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/auth/forgot-password',
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/wallet',
        builder: (_, _) => const WalletScreen(),
      ),
      GoRoute(
        path: '/gifts',
        builder: (_, _) => const GiftsScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (_, _) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/kyc',
        builder: (_, _) => const KycScreen(),
      ),
      GoRoute(
        path: '/app/conversation/:id',
        builder: (_, state) => ConversationScreen(
          conversationId: int.parse(state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/app/community/:slug',
        builder: (_, state) => CommunityDetailScreen(
          slug: state.pathParameters['slug']!,
        ),
      ),
      GoRoute(
        path: '/app/notifications',
        builder: (_, _) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/app/saved',
        builder: (_, _) => const SavedPostsScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(
          navigationShell: navigationShell,
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/chats',
                builder: (_, _) => const ChatsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/communities',
                builder: (_, _) => const CommunitiesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/create',
                builder: (_, _) => const CreateScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/discover',
                builder: (_, _) => const DiscoverScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/you',
                builder: (_, _) => const YouScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  return router;
});
