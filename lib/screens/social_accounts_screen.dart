import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/ui_states.dart';
import '../core/design_tokens.dart';
import '../providers/social_account_provider.dart';

/// Connected social accounts + combined verified follower summary
/// (Sprint 5 logic). Server-computed counts only.
class SocialAccountsScreen extends ConsumerStatefulWidget {
  const SocialAccountsScreen({super.key});

  @override
  ConsumerState<SocialAccountsScreen> createState() => _SocialAccountsScreenState();
}

class _SocialAccountsScreenState extends ConsumerState<SocialAccountsScreen> {
  final _providerController = TextEditingController();
  final _usernameController = TextEditingController();
  final _followersController = TextEditingController();
  bool _adding = false;

  @override
  void dispose() {
    _providerController.dispose();
    _usernameController.dispose();
    _followersController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(socialAccountProvider);
    final notifier = ref.read(socialAccountProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Social Accounts')),
      body: RefreshIndicator(
        onRefresh: () => notifier.refresh(),
        child: _body(context, state, notifier),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    SocialAccountState state,
    SocialAccountNotifier notifier,
  ) {
    if (state.loading && state.accounts.isEmpty) {
      return const LoadingStateWidget(message: 'Loading accounts…');
    }
    if (state.error != null && state.accounts.isEmpty) {
      return ErrorStateWidget(
        title: 'Could not load accounts',
        description: state.error!,
        onRetry: () => notifier.refresh(),
      );
    }

    final summary = state.summary;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Combined verified followers',
                  style: TextStyle(fontSize: 13, color: DesignTokens.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  summary?.combinedFollowers.toString() ?? '—',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: DesignTokens.navy,
                  ),
                ),
                if (summary != null && summary.providerBreakdown.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  for (final entry in summary.providerBreakdown.entries)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _providerLabel(entry.key),
                            style: const TextStyle(fontSize: 13),
                          ),
                          Text(
                            entry.value.toString(),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Connected accounts',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (state.accounts.isEmpty)
          const EmptyStateWidget(
            icon: Icons.alternate_email,
            title: 'No accounts connected',
            description:
                'Connect social profiles so MurihSpace can evaluate your combined audience.',
          )
        else
          for (final account in state.accounts)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: DesignTokens.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _providerIcon(account.provider),
                    size: 20,
                    color: DesignTokens.primaryDark,
                  ),
                ),
                title: Text(_providerLabel(account.provider)),
                subtitle: Text(
                  '@${account.username ?? '—'} · ${account.followerCount} followers',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: DesignTokens.danger),
                  tooltip: 'Remove',
                  onPressed: () => _remove(notifier, account.id),
                ),
              ),
            ),
        const SizedBox(height: 20),
        const Text(
          'Add a profile manually',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _providerController,
          decoration: const InputDecoration(
            labelText: 'Provider',
            hintText: 'e.g. instagram, tiktok, youtube',
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _usernameController,
          decoration: const InputDecoration(
            labelText: 'Username or handle',
            hintText: 'e.g. yourhandle',
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _followersController,
          decoration: const InputDecoration(
            labelText: 'Follower count',
            hintText: 'Verified follower count',
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: _adding ? null : () => _add(notifier),
          child: _adding
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add Account'),
        ),
      ],
    );
  }

  Future<void> _add(SocialAccountNotifier notifier) async {
    final provider = _providerController.text.trim().toLowerCase();
    final username = _usernameController.text.trim();
    final followers = int.tryParse(_followersController.text.trim()) ?? 0;
    if (provider.isEmpty || username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Provider and username are required.')),
      );
      return;
    }
    setState(() => _adding = true);
    final ok = await notifier.addManual(
      provider: provider,
      username: username,
      followerCount: followers,
    );
    if (!mounted) return;
    setState(() => _adding = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Account added.'
              : ref.read(socialAccountProvider).error ?? 'Could not add the account.',
        ),
      ),
    );
    if (ok) {
      _providerController.clear();
      _usernameController.clear();
      _followersController.clear();
    }
  }

  Future<void> _remove(SocialAccountNotifier notifier, int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove account?'),
        content: const Text('This profile will no longer count toward your combined followers.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await notifier.remove(id);
    }
  }

  String _providerLabel(String provider) {
    switch (provider.toLowerCase()) {
      case 'instagram':
        return 'Instagram';
      case 'tiktok':
        return 'TikTok';
      case 'youtube':
        return 'YouTube';
      case 'facebook':
        return 'Facebook';
      case 'x':
      case 'twitter':
        return 'X';
      case 'linkedin':
        return 'LinkedIn';
      case 'twitch':
        return 'Twitch';
      default:
        return provider;
    }
  }

  IconData _providerIcon(String provider) {
    switch (provider.toLowerCase()) {
      case 'instagram':
        return Icons.photo_camera_outlined;
      case 'tiktok':
        return Icons.music_note_outlined;
      case 'youtube':
        return Icons.play_circle_outline;
      case 'facebook':
        return Icons.facebook;
      case 'x':
      case 'twitter':
        return Icons.tag;
      case 'linkedin':
        return Icons.business;
      case 'twitch':
        return Icons.live_tv_outlined;
      default:
        return Icons.alternate_email;
    }
  }
}
