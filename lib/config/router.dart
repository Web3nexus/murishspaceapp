import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../screens/admin_moderation_screen.dart';
import '../screens/appearance_screen.dart';
import '../screens/ads_manager_screen.dart';
import '../screens/brand_deals_screen.dart';
import '../screens/calls_screen.dart';
import '../screens/chat_backup_screen.dart';
import '../screens/chat_folders_screen.dart';
import '../screens/devices_screen.dart';
import '../screens/friends_screen.dart';
import '../screens/home_screen.dart';
import '../screens/language_screen.dart';
import '../screens/marketplace_screen.dart';
import '../components/navigation_shell.dart';
import '../providers/auth_provider.dart';
import '../screens/chats_screen.dart';
import '../screens/communities_screen.dart';
import '../screens/community_detail_screen.dart';
import '../screens/community_create_dialog.dart';
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
import '../screens/social_accounts_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/upgrade_account_screen.dart';
import '../screens/verification_badge_screen.dart';
import '../screens/wallet_screen.dart';
import '../screens/you_screen.dart';
import '../screens/security_settings_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/pin_setup_screen.dart';
import '../screens/conference_meeting_screen.dart';
import '../screens/live_stream_screen.dart';
import '../screens/link_in_bio_screen.dart';
import '../screens/user_profile_screen.dart';
import '../core/roles.dart';

/// Notifies the router whenever auth state changes so redirects re-evaluate.
class _RouterRefresh extends ChangeNotifier {
  void refresh() => notifyListeners();
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefresh();
  ref.onDispose(refreshNotifier.dispose);

  ref.listen(authProvider, (_, __) => refreshNotifier.refresh());

  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final path = state.uri.path;
      final loggedIn = auth.token != null;

      if (path == '/') return loggedIn ? '/app/chats' : '/splash';

      // Keep the splash on screen while auto-login resolves.
      if (auth.loading) return null;

      final isAuthEntry = path.startsWith('/auth/');
      if (loggedIn && (isAuthEntry || path == '/splash')) {
        return '/app/chats';
      }
      if (loggedIn && path == '/app') return '/app/home';
      if (!loggedIn && (path.startsWith('/app') || path == '/wallet' || path == '/gifts' || path == '/profile' || path == '/kyc' || path == '/social-accounts')) {
        return '/auth/login';
      }
      if (loggedIn && path == '/social-accounts') {
        final role = auth.user?.role ?? UserRole.member;
        if (!Permissions.roleHas(role, 'ai_onboarding.access')) {
          return '/app/chats';
        }
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        redirect: (_, __) => '/splash',
      ),
      GoRoute(
        path: '/app',
        redirect: (_, __) => '/app/chats',
      ),
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
        path: '/brand-deals',
        builder: (_, _) => const BrandDealsScreen(),
      ),
      GoRoute(
        path: '/ads-manager',
        builder: (_, _) => const AdsManagerScreen(),
      ),
      GoRoute(
        path: '/app/ads-manager',
        builder: (_, _) => const AdsManagerScreen(),
      ),
      GoRoute(
        path: '/ads',
        builder: (_, _) => const AdsManagerScreen(),
      ),
      GoRoute(
        path: '/app/ads',
        builder: (_, _) => const AdsManagerScreen(),
      ),
      GoRoute(
        path: '/create',
        builder: (_, _) => const CreateScreen(),
      ),
      GoRoute(
        path: '/create-community',
        builder: (context, _) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            showCreateCommunityDialog(context);
          });
          return const Scaffold(backgroundColor: Colors.transparent);
        },
      ),
      GoRoute(
        path: '/crreate-community',
        builder: (context, _) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            showCreateCommunityDialog(context);
          });
          return const Scaffold(backgroundColor: Colors.transparent);
        },
      ),
      GoRoute(
        path: '/create-broadcast',
        builder: (context, _) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            showCreateCommunityDialog(context);
          });
          return const Scaffold(backgroundColor: Colors.transparent);
        },
      ),
      GoRoute(
        path: '/create-channel',
        builder: (context, _) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            showCreateCommunityDialog(context);
          });
          return const Scaffold(backgroundColor: Colors.transparent);
        },
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
        path: '/admin/moderation',
        builder: (_, _) => const AdminModerationScreen(),
      ),
      GoRoute(
        path: '/profile/security',
        builder: (_, _) => const SecuritySettingsScreen(),
      ),
      GoRoute(
        path: '/security-settings',
        builder: (_, _) => const SecuritySettingsScreen(),
      ),
      GoRoute(
        path: '/profile/security/setup-pin',
        builder: (_, _) => const PinSetupScreen(),
      ),
      GoRoute(
        path: '/profile/devices',
        builder: (_, _) => const DevicesScreen(),
      ),
      GoRoute(
        path: '/profile/appearance',
        builder: (_, _) => const AppearanceScreen(),
      ),
      GoRoute(
        path: '/profile/chat-folders',
        builder: (_, _) => const ChatFoldersScreen(),
      ),
      GoRoute(
        path: '/profile/chat-backup',
        builder: (_, _) => const ChatBackupScreen(),
      ),
      GoRoute(
        path: '/profile/language',
        builder: (_, _) => const LanguageScreen(),
      ),
      GoRoute(
        path: '/app/calls',
        builder: (_, _) => const CallsScreen(),
      ),
      GoRoute(
        path: '/profile/notifications',
        builder: (_, _) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/kyc',
        builder: (_, _) => const KycScreen(),
      ),
      GoRoute(
        path: '/upgrade-account',
        builder: (_, _) => const UpgradeAccountScreen(),
      ),
      GoRoute(
        path: '/verification-badge',
        builder: (_, _) => const VerificationBadgeScreen(),
      ),
      GoRoute(
        path: '/social-accounts',
        builder: (_, _) => const SocialAccountsScreen(),
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
        path: '/friends',
        builder: (_, _) => const FriendsScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, _) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/profile/user/:id',
        builder: (_, state) => UserProfileScreen(
          userId: int.tryParse(state.pathParameters['id'] ?? '1') ?? 1,
          name: state.uri.queryParameters['name'] ?? 'Friend User',
          username: state.uri.queryParameters['username'] ?? 'friend_user',
        ),
      ),
      GoRoute(
        path: '/app/conference',
        builder: (_, _) => const ConferenceMeetingScreen(),
      ),
      GoRoute(
        path: '/app/live',
        builder: (_, _) => const LiveStreamScreen(),
      ),
      GoRoute(
        path: '/link-in-bio',
        builder: (_, _) => const LinkInBioScreen(),
      ),
      GoRoute(
        path: '/app/notifications',
        builder: (_, _) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/app/saved',
        builder: (_, _) => const SavedPostsScreen(),
      ),
      GoRoute(
        path: '/saved-posts',
        builder: (_, _) => const SavedPostsScreen(),
      ),
      GoRoute(
        path: '/app/communities',
        builder: (_, _) => const CommunitiesScreen(),
      ),
      GoRoute(
        path: '/app/marketplace',
        builder: (_, _) => const MarketplaceScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(
          navigationShell: navigationShell,
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/home',
                builder: (context, _) => HomeScreen(
                  onOpenMessages: () {
                    final shell = StatefulNavigationShell.of(context);
                    shell.goBranch(1);
                  },
                ),
              ),
            ],
          ),
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
                path: '/app/create',
                builder: (_, _) => const CreateScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/tab-4',
                builder: (_, _) => const _RoleAwareFourthBranchScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/profile',
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

class _RoleAwareFourthBranchScreen extends ConsumerWidget {
  const _RoleAwareFourthBranchScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final role = user?.role ?? UserRole.member;

    if (role == UserRole.creator) {
      return const CommunitiesScreen();
    }
    return const MarketplaceScreen();
  }
}
