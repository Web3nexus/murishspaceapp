import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../components/app_bottom_sheet.dart';
import '../components/ui_states.dart';
import '../providers/social_account_provider.dart';

/// Redesigned Connect Social Profiles & Creator Audience Verification Center.
class SocialAccountsScreen extends ConsumerStatefulWidget {
  const SocialAccountsScreen({super.key});

  @override
  ConsumerState<SocialAccountsScreen> createState() => _SocialAccountsScreenState();
}

class _SocialAccountsScreenState extends ConsumerState<SocialAccountsScreen> {
  static const _platforms = [
    {
      'id': 'instagram',
      'label': 'Instagram',
      'subtitle': 'Reels, Photo Posts & Stories',
      'icon': Icons.camera_alt_rounded,
      'color': Color(0xFFE1306C),
    },
    {
      'id': 'tiktok',
      'label': 'TikTok',
      'subtitle': 'Short-form Video & Creator Stats',
      'icon': Icons.music_note_rounded,
      'color': Color(0xFF000000),
    },
    {
      'id': 'youtube',
      'label': 'YouTube',
      'subtitle': 'Long-form Video & Subscribers',
      'icon': Icons.play_circle_fill_rounded,
      'color': Color(0xFFFF0000),
    },
    {
      'id': 'x',
      'label': 'X (Twitter)',
      'subtitle': 'Verified Badge & Updates',
      'icon': Icons.tag_rounded,
      'color': Color(0xFF1DA1F2),
    },
    {
      'id': 'facebook',
      'label': 'Facebook',
      'subtitle': 'Page & Community Followers',
      'icon': Icons.facebook_rounded,
      'color': Color(0xFF1877F2),
    },
    {
      'id': 'linkedin',
      'label': 'LinkedIn',
      'subtitle': 'Professional & Vendor Store',
      'icon': Icons.business_rounded,
      'color': Color(0xFF0A66C2),
    },
  ];

  void _proceedToApp() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/app');
    }
  }

  void _showConnectDialog(Map<String, dynamic> platform, SocialAccount? existingAccount) {
    final usernameCtrl = TextEditingController(text: existingAccount?.username ?? '');
    final followersCtrl = TextEditingController(
      text: existingAccount != null ? existingAccount.followerCount.toString() : '1000',
    );
    bool isSaving = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1C1C1E)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final textPrimary = isDark ? Colors.white : Colors.black;
        final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];
        final brandColor = platform['color'] as Color;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[700] : Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Header Row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: brandColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(platform['icon'] as IconData, color: brandColor, size: 26),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${existingAccount != null ? 'Edit' : 'Connect'} ${platform['label']}',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textPrimary),
                              ),
                              Text(
                                platform['subtitle'] as String,
                                style: TextStyle(fontSize: 12, color: textSecondary),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: Icon(Icons.close_rounded, color: textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Handle/Username Input
                    TextField(
                      controller: usernameCtrl,
                      style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        prefixText: '@ ',
                        prefixStyle: TextStyle(color: brandColor, fontWeight: FontWeight.bold, fontSize: 16),
                        labelText: 'Social Handle / Username',
                        hintText: 'e.g. yourname',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Followers Input
                    TextField(
                      controller: followersCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.people_rounded),
                        labelText: 'Verified Follower Count',
                        hintText: 'e.g. 5000',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Benefits Banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF007AFF).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF007AFF).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.verified_rounded, color: Color(0xFF007AFF), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Verified followers populate your Creator Media Kit & unlock tier 1 escrow limits.',
                              style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[300] : Colors.grey[700]),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Connect CTA Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brandColor == const Color(0xFF000000) && isDark ? Colors.white : brandColor,
                          foregroundColor: brandColor == const Color(0xFF000000) && isDark ? Colors.black : Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: isSaving
                            ? null
                            : () async {
                                final handle = usernameCtrl.text.trim().replaceAll('@', '');
                                final followers = int.tryParse(followersCtrl.text.trim()) ?? 0;
                                if (handle.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please enter a valid handle.')),
                                  );
                                  return;
                                }

                                setModalState(() => isSaving = true);
                                final ok = await ref.read(socialAccountProvider.notifier).addManual(
                                      provider: platform['id'] as String,
                                      username: handle,
                                      followerCount: followers,
                                    );

                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      ok
                                          ? '${platform['label']} profile @$handle connected!'
                                          : 'Could not connect account.',
                                    ),
                                    backgroundColor: const Color(0xFF34C759),
                                  ),
                                );
                              },
                        child: isSaving
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(
                                '${existingAccount != null ? 'Update' : 'Verify & Link'} ${platform['label']}',
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(socialAccountProvider);
    final notifier = ref.read(socialAccountProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : const Color(0xFFEFF1F5);
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

    final summary = state.summary;
    final totalFollowers = summary?.combinedFollowers ?? 0;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Connect Social Profiles',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _proceedToApp,
            child: const Text(
              'Done',
              style: TextStyle(
                color: Color(0xFF007AFF),
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => notifier.refresh(),
        child: state.loading && state.accounts.isEmpty
            ? const LoadingStateWidget(message: 'Loading social channels…')
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Hero Combined Followers Counter Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF007AFF).withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.verified_user_rounded, color: Colors.white, size: 22),
                            SizedBox(width: 8),
                            Text(
                              'VERIFIED CREATOR AUDIENCE',
                              style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.0),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '$totalFollowers',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Text(
                          'Combined Followers & Subscribers',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        if (state.accounts.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: state.accounts.map((acc) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '@${acc.username ?? acc.provider} · ${acc.followerCount}',
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Section Title
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 10),
                    child: Text(
                      'AVAILABLE NETWORKS & PLATFORMS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),

                  // Platform Cards List
                  ..._platforms.map((plat) {
                    final platformId = plat['id'] as String;
                    final brandColor = plat['color'] as Color;
                    final existingAcc = state.accounts.firstWhere(
                      (acc) => acc.provider.toLowerCase() == platformId,
                      orElse: () => const SocialAccount(id: 0, provider: '', followerCount: 0, followingCount: 0, verifiedOnProvider: false),
                    );
                    final isConnected = existingAcc.id != 0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(18),
                        border: isConnected ? Border.all(color: const Color(0xFF34C759).withValues(alpha: 0.5), width: 1.5) : null,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: brandColor.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(plat['icon'] as IconData, color: brandColor, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      plat['label'] as String,
                                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: textPrimary),
                                    ),
                                    const SizedBox(width: 8),
                                    if (isConnected)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF34C759).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Text(
                                          'LINKED',
                                          style: TextStyle(color: Color(0xFF34C759), fontWeight: FontWeight.w900, fontSize: 10),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isConnected
                                      ? '@${existingAcc.username} · ${existingAcc.followerCount} followers'
                                      : plat['subtitle'] as String,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isConnected ? const Color(0xFF34C759) : textSecondary,
                                    fontWeight: isConnected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isConnected) ...[
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF3B30), size: 20),
                              onPressed: () async {
                                final ok = await AppBottomSheet.showConfirmation(
                                  context: context,
                                  title: 'Disconnect ${plat['label']}?',
                                  message: 'This handle will be removed from your Creator Media Kit.',
                                  confirmText: 'Disconnect',
                                  isDestructive: true,
                                  icon: Icons.link_off_rounded,
                                );
                                if (ok == true) {
                                  notifier.remove(existingAcc.id);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('${plat['label']} account disconnected.')),
                                  );
                                }
                              },
                            ),
                          ] else ...[
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF007AFF),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              ),
                              onPressed: () => _showConnectDialog(plat, null),
                              child: const Text('Connect', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 16),

                  // Bottom CTA
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF007AFF),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _proceedToApp,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Continue to MurihSpace', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
      ),
    );
  }
}
