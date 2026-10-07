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
import '../screens/chat_settings_screen.dart';
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
import '../screens/change_phone_screen.dart';
import '../screens/conference_meeting_screen.dart';
import '../screens/live_stream_screen.dart';
import '../screens/live_link_screen.dart';
import '../screens/meeting_link_screen.dart';
import '../screens/event_detail_screen.dart';
import '../screens/product_link_screen.dart';
import '../screens/storefront_link_screen.dart';
import '../screens/events_screen.dart';
import '../screens/link_in_bio_screen.dart';
import '../screens/user_profile_screen.dart';
import '../core/roles.dart';
import 'deep_links.dart';

/// Notifies the router whenever auth state changes so redirects re-evaluate.
class _RouterRefresh extends ChangeNotifier {
  void refresh() => notifyListeners();
}

/// Global navigator key to allow reliable navigation from outside the GoRouter context
/// (e.g. background call banners, in-app overlays, push notification handlers).
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Paths that are unusable without a session.
///
/// Deep-link landing pages are split deliberately. A public page (`/live`,
/// `/e`, `/p`, `/c`, `/u`, `/l`) resolves and renders for anyone and prompts
/// for sign-in only at the point of action, while a private one (`/m`,
/// `/chat`) sends the visitor through login first and then hands them
/// straight back to the shared content.
///
/// Everything under `/app/*` is private too, but that is already enforced by
/// the `/app` prefix check in the redirect, so it is not repeated here.
const Set<String> _authRequiredExactPaths = <String>{
  '/wallet',
  '/gifts',
  '/profile',
  '/kyc',
  '/social-accounts',
  '/friends',
  '/settings',
  '/create',
  '/create-community',
  '/create-channel',
  '/create-broadcast',
  '/ads',
  '/ads-manager',
  '/brand-deals',
  '/upgrade-account',
  '/verification-badge',
  '/link-in-bio',
  '/admin/moderation',
  '/security-settings',
  '/communities/create',
  '/saved-posts',
};

const List<String> _authRequiredPrefixes = <String>[
  '/app/meeting/',
  '/app/conversation/',
  '/app/community/',
  '/app/saved',
  '/app/notifications',
  '/profile/',
  '/m/',
  '/chat/',
  '/conversation/',
];

bool _requiresAuth(String path) {
  final lower = path.toLowerCase();
  if (_authRequiredExactPaths.contains(lower)) return true;
  for (final prefix in _authRequiredPrefixes) {
    if (lower.startsWith(prefix)) return true;
  }
  return false;
}

/// Prefixes the router already declares a [GoRoute] for, so they are never
/// treated as aliases.
///
/// Rewriting these would be actively destructive: `/app/meeting/:code` is what
/// [MeetingLinkScreen] itself navigates to in order to join a room, so
/// rewriting it back to `/m/:code` would return the operator to the landing
/// screen they just left and make joining impossible. The conversation and
/// community routes have a screen of their own for the same reason.
const List<String> _ownRoutePrefixes = <String>[
  '/app/meeting/',
  '/app/conversation/',
  '/app/community/',
];

/// Rewrites a legacy (or non-canonical) link to the canonical in-app route.
///
/// Returns null when the path is already canonical, already has a route of its
/// own, or is unrecognised, so the normal redirect logic continues. Going
/// through [DeepLinks.resolve] keeps the accepted shapes in one place, shared
/// with the web SPA and the backend link resolver, instead of being
/// re-implemented as route aliases here.
String? _canonicalAlias(Uri uri) {
  final path = uri.path;
  final lower = path.toLowerCase();
  for (final prefix in _ownRoutePrefixes) {
    if (lower.startsWith(prefix)) return null;
  }

  final canonical = DeepLinks.resolve(path, query: true);
  if (canonical.isUnknown) return null;

  final target = canonical.appRoute;
  // Preserve the original query string: the resolver echoes `uri.query` back
  // for most types, but tracking parameters must survive regardless.
  final suffix = uri.hasQuery && !target.contains('?') ? '?${uri.query}' : '';
  final rewritten = '$target$suffix';
  // Compare against the whole location, query included. `uri.path` carries no
  // query, so comparing paths alone made every canonical URL that already
  // had one — `/e/12?ref=x` — resolve to itself and redirect forever.
  final current = uri.hasQuery ? '$path?${uri.query}' : path;
  return rewritten == current ? null : rewritten;
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefresh();
  ref.onDispose(refreshNotifier.dispose);

  ref.listen(authProvider, (_, _) => refreshNotifier.refresh());

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final path = state.uri.path;
      final loggedIn = auth.token != null;

      // Legacy aliases are claimed in the OS association files, so the app has
      // to honour every one of them. Rewriting them to the canonical shape here
      // means only one route per content type has to exist and stay correct,
      // instead of duplicating `/meeting/*`, `/events/*`, `/products/*` and
      // friends as their own GoRoutes. Unknown paths fall through untouched.
      final alias = _canonicalAlias(state.uri);
      if (alias != null) return alias;

      if (path == '/') return loggedIn ? '/app/chats' : '/splash';

      // Keep the splash on screen while auto-login resolves.
      if (auth.loading) return null;

      final isAuthEntry = path.startsWith('/auth/');
      final returnTo = DeepLinks.sanitiseReturnTo(
        state.uri.queryParameters['returnTo'],
      );

      // A login screen carrying a returnTo is a legitimate destination: it
      // exists precisely so the user can authenticate and come back to the
      // shared content they opened. Only allow it when the target is still
      // valid, so a tampered link cannot use the login screen as a trampoline.
      if (loggedIn && isAuthEntry && returnTo != null) {
        return returnTo;
      }
      if (loggedIn && (isAuthEntry || path == '/splash')) {
        return '/app/chats';
      }
      if (loggedIn && path == '/app') return '/app/home';

      // Anything the app cannot show without a session goes to login first and
      // is handed straight back afterwards. This covers the deep-link landing
      // pages (`/m`, `/chat`, plus the protected parts of `/app/*`) as well as
      // the settings and wallet routes, which previously fell through the guard
      // and rendered signed-out.
      if (!loggedIn && (_requiresAuth(path) || path.startsWith('/app'))) {
        final target = state.uri.hasQuery ? '$path?${state.uri.query}' : path;
        return '/auth/login?returnTo=${Uri.encodeQueryComponent(target)}';
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
      GoRoute(path: '/', redirect: (_, _) => '/splash'),
      GoRoute(path: '/app', redirect: (_, _) => '/app/chats'),
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      GoRoute(path: '/auth/login', builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: '/auth/register',
        builder: (_, _) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/auth/forgot-password',
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      GoRoute(path: '/wallet', builder: (_, _) => const WalletScreen()),
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
      GoRoute(path: '/ads', builder: (_, _) => const AdsManagerScreen()),
      GoRoute(path: '/app/ads', builder: (_, _) => const AdsManagerScreen()),
      GoRoute(path: '/create', builder: (_, _) => const CreateScreen()),
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
            showCreateBroadcastChannelDialog(context);
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
      GoRoute(path: '/gifts', builder: (_, _) => const GiftsScreen()),
      GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
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
        path: '/profile/security/change-phone',
        builder: (_, _) => const ChangePhoneScreen(),
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
        path: '/profile/chat-settings',
        builder: (_, _) => const ChatSettingsScreen(),
      ),
      GoRoute(
        path: '/profile/chat-backup',
        builder: (_, _) => const ChatBackupScreen(),
      ),
      GoRoute(
        path: '/profile/language',
        builder: (_, _) => const LanguageScreen(),
      ),
      GoRoute(path: '/app/calls', builder: (_, _) => const CallsScreen()),
      GoRoute(
        path: '/profile/notifications',
        builder: (_, _) => const NotificationsScreen(),
      ),
      GoRoute(path: '/kyc', builder: (_, _) => const KycScreen()),
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
        builder: (_, state) =>
            CommunityDetailScreen(slug: state.pathParameters['slug']!),
      ),
      GoRoute(
        path: '/c/:slug',
        builder: (_, state) =>
            CommunityDetailScreen(slug: state.pathParameters['slug']!),
      ),
      GoRoute(
        path: '/communities/:slug',
        builder: (_, state) =>
            CommunityDetailScreen(slug: state.pathParameters['slug']!),
      ),
      GoRoute(
        path: '/u/:username',
        builder: (_, state) => UserProfileScreen(
          userId: 0,
          name: state.pathParameters['username'] ?? 'User',
          username: state.pathParameters['username'] ?? 'user',
        ),
      ),
      GoRoute(path: '/friends', builder: (_, _) => const FriendsScreen()),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
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
        builder: (_, state) => ConferenceMeetingScreen(
          joinCode: state.uri.queryParameters['code'],
        ),
      ),
      GoRoute(
        path: '/app/meeting/:code',
        builder: (_, state) =>
            ConferenceMeetingScreen(joinCode: state.pathParameters['code']),
      ),
      GoRoute(
        path: '/app/live',
        builder: (_, state) {
          final streamId = int.tryParse(
            state.uri.queryParameters['streamId'] ?? '',
          );
          final trackingId = state.uri.queryParameters['trackingId'];
          final title = state.uri.queryParameters['title'] ?? 'Live Broadcast';
          final hostName = state.uri.queryParameters['hostName'] ?? 'Creator';
          final communityName = state.uri.queryParameters['communityName'];
          final isHost = state.uri.queryParameters['isHost'] != 'false';
          return LiveStreamScreen(
            streamId: streamId,
            trackingId: trackingId,
            streamTitle: title,
            hostName: hostName,
            communityName: communityName,
            isHost: isHost,
          );
        },
      ),
      GoRoute(
        path: '/live/:trackingId',
        builder: (_, state) => LiveLinkScreen(
          trackingId: state.pathParameters['trackingId']!,
          queryParameters: state.uri.queryParameters,
        ),
      ),

      // ── Shared deep-link landing pages ─────────────────────────────
      // Each of these is opened from a MurihSpace link shared in chat, a post
      // or the OS share sheet. The canonical paths live in
      // `DeepLinks` so the app, the web SPA and the backend link resolver
      // all agree on one shape per content type.
      GoRoute(
        path: '/m/:code',
        builder: (_, state) =>
            MeetingLinkScreen(roomCode: state.pathParameters['code'] ?? ''),
      ),
      GoRoute(
        path: '/e/:id',
        builder: (_, state) =>
            EventDetailScreen(eventId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: '/p/:id',
        builder: (_, state) =>
            ProductLinkScreen(productId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: '/chat/:id',
        builder: (_, state) => ConversationScreen(
          conversationId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: '/l/:username',
        // The app has no public link-in-bio viewer — `/link-in-bio` edits the
        // signed-in user's own page — so a shared bio link opens the owner's
        // public profile instead of showing the wrong person's editor.
        builder: (_, state) => UserProfileScreen(
          userId: 0,
          name: state.pathParameters['username'] ?? 'User',
          username: state.pathParameters['username'] ?? 'user',
        ),
      ),
      GoRoute(
        path: '/store/:shortCode',
        builder: (_, state) => StorefrontLinkScreen(
          shortCode: state.pathParameters['shortCode'] ?? '',
        ),
      ),
      GoRoute(path: '/link-in-bio', builder: (_, _) => const LinkInBioScreen()),

      // ── Events ─────────────────────────────────────────────────────
      GoRoute(path: '/app/events', builder: (_, _) => const EventsScreen()),
      GoRoute(
        path: '/app/notifications',
        builder: (_, _) => const NotificationsScreen(),
      ),
      GoRoute(path: '/app/saved', builder: (_, _) => const SavedPostsScreen()),
      GoRoute(
        path: '/saved-posts',
        builder: (_, _) => const SavedPostsScreen(),
      ),
      GoRoute(
        path: '/app/communities',
        builder: (_, _) => const CommunitiesScreen(),
      ),
      GoRoute(
        path: '/communities/create',
        builder: (_, _) => const CommunitiesScreen(),
      ),
      GoRoute(
        path: '/app/marketplace',
        builder: (_, _) => const MarketplaceScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
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
