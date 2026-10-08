import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/api_client.dart';
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
/// Checks if the meeting is active via the link preview resolver, showing a
/// clear ended screen when the room has closed rather than bouncing into an
/// empty/failing conference room.
class MeetingLinkScreen extends ConsumerStatefulWidget {
  final String roomCode;

  const MeetingLinkScreen({super.key, required this.roomCode});

  @override
  ConsumerState<MeetingLinkScreen> createState() => _MeetingLinkScreenState();
}

class _MeetingLinkScreenState extends ConsumerState<MeetingLinkScreen> {
  bool _loading = true;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    _checkMeeting();
  }

  Future<void> _checkMeeting() async {
    final code = widget.roomCode.trim().toLowerCase();
    if (!_isRoomCode(code)) {
      setState(() => _loading = false);
      return;
    }

    try {
      final api = ref.read(apiClientProvider);
      final response = await api.get(
        '/link-preview',
        queryParameters: {'url': '/m/$code'},
      );
      final payload =
          ApiClient.instance.unwrap(response) as Map<String, dynamic>;
      // Only an explicit false means the room is closed. An absent field
      // leaves the meeting joinable, matching message_bubble.dart.
      final active = payload['is_active'] != false;
      if (!mounted) return;
      setState(() {
        _isActive = active;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final code = widget.roomCode.trim().toLowerCase();
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

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Meeting invite')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isActive) {
      return Scaffold(
        appBar: AppBar(title: const Text('Meeting invite')),
        body: _CenteredMessage(
          icon: Icons.videocam_off_rounded,
          title: 'This meeting has ended',
          message:
              'Meeting room "$code" is no longer active or the invite has expired. '
              'Ask the host for a fresh invite link.',
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
      final target = '/app/meeting/${Uri.encodeComponent(widget.roomCode.trim())}';
      if (context.canPop()) {
        context.pushReplacement(target);
      } else {
        context.push(target);
      }
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
