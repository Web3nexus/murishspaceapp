import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../config/deep_links.dart';

/// Room codes are one URL-safe path segment.
///
/// No single shape is enforced when a meeting is created, so this stays
/// permissive on purpose — a stricter pattern would reject real invites and
/// dead-end a shared link. `instant` is the reserved "start now" route rather
/// than a room.
final RegExp _roomCodePattern = RegExp(r'^[A-Za-z0-9_-]{3,64}$');

bool _isRoomCode(String code) {
  return code != 'instant' && _roomCodePattern.hasMatch(code);
}

/// Landing page for a shared meeting invite (`/m/:code`).
///
/// Every meeting endpoint is authenticated, so this cannot fetch room details
/// without a session. Instead it presents the invite, hands the code straight
/// to the room screen when the visitor is signed in, and otherwise routes them
/// through login with a `returnTo` so they land back here — and from here into
/// the room — once authenticated.
///
/// That round trip is the whole point: a meeting link pasted into a chat app
/// used to dead-end for anyone who was not already signed in.
class MeetingLinkScreen extends ConsumerWidget {
  final String roomCode;

  const MeetingLinkScreen({super.key, required this.roomCode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final code = roomCode.trim().toLowerCase();
    final isValid = _isRoomCode(code);
    final isAuthenticated = ref.watch(authProvider).token != null;

    // The canonical path, used both for the login round trip and for sharing.
    final canonicalPath = isValid
        ? DeepLinks.meeting(code)
        : DeepLinks.meetingPath;

    if (!isValid) {
      return Scaffold(
        appBar: AppBar(title: const Text('Meeting invite')),
        body: _CenteredMessage(
          icon: Icons.link_off_rounded,
          title: 'This meeting link is not valid',
          message:
              'Meeting links end in a room code. Ask the host to share '
              'the link again.',
          primaryLabel: 'Go to meetings',
          onPrimary: () => context.go('/app/conference'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Meeting invite')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.videocam_rounded,
                    size: 44,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "You're invited to a meeting",
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'The host shared a MurihSpace video meeting with you.',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                _RoomCodeChip(code: code),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: () => _join(context, ref, canonicalPath),
                  icon: Icon(
                    isAuthenticated
                        ? Icons.videocam_rounded
                        : Icons.login_rounded,
                  ),
                  label: Text(
                    isAuthenticated ? 'Join meeting' : 'Sign in to join',
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Meetings are private. You need a MurihSpace account to enter.',
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _join(BuildContext context, WidgetRef ref, String canonicalPath) {
    if (ref.read(authProvider).token != null) {
      context.go('/app/meeting/${Uri.encodeComponent(roomCode.trim())}');
      return;
    }
    // The router guard already redirects /m/* to login; doing it here too keeps
    // the intent explicit and survives a change to the guard's allow-list.
    context.go(
      '/auth/login?returnTo=${Uri.encodeQueryComponent(canonicalPath)}',
    );
  }
}

class _RoomCodeChip extends StatelessWidget {
  final String code;

  const _RoomCodeChip({required this.code});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: code));
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Room code copied')));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              code,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 2.5,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              Icons.copy_rounded,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimary;

  const _CenteredMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            OutlinedButton(onPressed: onPrimary, child: Text(primaryLabel)),
          ],
        ),
      ),
    );
  }
}
