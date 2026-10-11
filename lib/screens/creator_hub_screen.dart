import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../components/murih_icon.dart';
import '../core/api_client.dart';
import '../core/design_tokens.dart';
import '../providers/auth_provider.dart';
import '../providers/wallet_provider.dart';
import 'brand_deals_help_screen.dart';

/// Complete Redesigned Creator Hub (Page B) matching MurihSpace visual reference:
/// Header ("Creator Hub", "Create. Grow. Earn.", notifications & settings shortcuts) ·
/// Creator Profile summary card · Total Earnings card with trend badge & wallet shortcut ·
/// 3-column performance metrics · Quick Actions (Brand Deals, My Campaigns, Analytics, Link in Bio) ·
/// Recent Activity Feed · Brand Deals Marketplace with escrow protection.
class CreatorHubScreen extends ConsumerStatefulWidget {
  const CreatorHubScreen({super.key});

  @override
  ConsumerState<CreatorHubScreen> createState() => _CreatorHubScreenState();
}

class _CreatorHubScreenState extends ConsumerState<CreatorHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 4, vsync: this);
  final String _selectedPeriod = 'Last 30 Days';

  final List<Map<String, dynamic>> _campaigns = [
    {
      'id': 'c1',
      'brand': 'Nike',
      'logo': 'https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=150',
      'title': 'Nike Summer Running Campaign',
      'budget': 1200.0,
      'daysLeft': 3,
      'requirements': '1 Reel + 2 Stories',
      'category': 'Sport & Fitness',
      'status': 'Open',
      'applied': false,
    },
    {
      'id': 'c2',
      'brand': 'Coca-Cola',
      'logo': 'https://images.unsplash.com/photo-1554866585-cd94860890b7?w=150',
      'title': 'Coca-Cola Zero Refresh Challenge',
      'budget': 850.0,
      'daysLeft': 5,
      'requirements': '1 Short Video (30s)',
      'category': 'Food & Beverage',
      'status': 'Open',
      'applied': true,
    },
    {
      'id': 'c3',
      'brand': 'Samsung',
      'logo': 'https://images.unsplash.com/photo-1610945265064-0e34e5519bbf?w=150',
      'title': 'Samsung Galaxy S24 Glow Up Series',
      'budget': 2500.0,
      'daysLeft': 7,
      'requirements': '2 Reels + 1 Photo Post',
      'category': 'Tech & Innovation',
      'status': 'Open',
      'applied': false,
    },
    {
      'id': 'c4',
      'brand': 'Spotify',
      'logo': 'https://images.unsplash.com/photo-1614680376593-902f749f7ffc?w=150',
      'title': 'MurihSpace Beats Creator Spotlight',
      'budget': 1800.0,
      'daysLeft': 10,
      'requirements': '1 Audio Playlist + 1 Video Review',
      'category': 'Music & Entertainment',
      'status': 'Open',
      'applied': false,
    },
  ];

  final List<Map<String, dynamic>> _activities = [
    {
      'type': 'deal',
      'title': 'New brand deal available',
      'subtitle': 'Nike Summer Running Campaign',
      'time': '2h ago',
      'icon': Icons.local_offer_rounded,
      'color': DesignTokens.primary,
    },
    {
      'type': 'approved',
      'title': 'Campaign application approved',
      'subtitle': 'Coca-Cola Zero Refresh Challenge',
      'time': '1d ago',
      'icon': Icons.check_circle_rounded,
      'color': Color(0xFF16A34A),
    },
    {
      'type': 'payment',
      'title': 'You received a payment',
      'subtitle': '\$850.00 from Samsung Campaign Escrow',
      'time': '3d ago',
      'icon': Icons.account_balance_wallet_rounded,
      'color': Color(0xFF16A34A),
    },
    {
      'type': 'message',
      'title': 'New message from Brand',
      'subtitle': 'Spotify Creator Team sent you brief guidelines',
      'time': '4d ago',
      'icon': Icons.chat_bubble_rounded,
      'color': Color(0xFFD97706),
    },
  ];

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _showApplyModal(Map<String, dynamic> campaign) {
    final proposalCtrl = TextEditingController();
    final sampleUrlCtrl = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF161B26)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final textPrimary = isDark ? Colors.white : const Color(0xFF17202B);
        final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085);

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
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
                          color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE4E7EC),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: DesignTokens.primary.withValues(alpha: 0.1),
                          backgroundImage: CachedNetworkImageProvider(campaign['logo'] as String),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                campaign['brand'] as String,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: textSecondary,
                                ),
                              ),
                              Text(
                                campaign['title'] as String,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '\$${(campaign['budget'] as num).toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: DesignTokens.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: DesignTokens.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: DesignTokens.primary.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.shield_rounded, color: DesignTokens.primary, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Funds are 100% held in MurihPay Escrow and automatically released upon deliverable approval.',
                              style: TextStyle(
                                fontSize: 12,
                                color: textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Your Pitch / Creative Concept',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textPrimary),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: proposalCtrl,
                      maxLines: 3,
                      style: TextStyle(color: textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Briefly explain how you plan to showcase the brand to your audience...',
                        hintStyle: TextStyle(color: textSecondary, fontSize: 13),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E2638) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE4E7EC)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE4E7EC)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: DesignTokens.primary, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Sample Content URL (Optional)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textPrimary),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: sampleUrlCtrl,
                      style: TextStyle(color: textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'e.g. https://murihspace.com/p/your-best-reel',
                        hintStyle: TextStyle(color: textSecondary, fontSize: 13),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E2638) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE4E7EC)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE4E7EC)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: DesignTokens.primary, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DesignTokens.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                if (proposalCtrl.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please enter your pitch.')),
                                  );
                                  return;
                                }
                                setModalState(() => isSubmitting = true);
                                await Future.delayed(const Duration(milliseconds: 600));
                                if (!mounted) return;
                                setState(() {
                                  campaign['applied'] = true;
                                });
                                if (!ctx.mounted) return;
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Application submitted to ${campaign['brand']}!'),
                                    backgroundColor: const Color(0xFF16A34A),
                                  ),
                                );
                              },
                        child: isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                'Submit Application',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
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
    final user = ref.watch(authProvider).user;
    final wallet = ref.watch(walletProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F1319) : const Color(0xFFF3F5F8);
    final cardBg = isDark ? const Color(0xFF161B26) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF17202B);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085);
    final borderColor = isDark ? const Color(0xFF2E384D) : const Color(0xFFE4E7EC);

    final rawBalance = wallet.creatorBalance > 0 ? wallet.creatorBalance : wallet.systemBalance;
    final displayEarnings = '\$${rawBalance.toStringAsFixed(2)}';
    final followersCount = user?.followersCount ?? 0;

    final authorName = user?.name.isNotEmpty == true ? user!.name : 'Creator';
    final authorUsername = user?.username.isNotEmpty == true ? user!.username : 'creator';
    final rawAvatar = user?.avatarUrl;
    final resolvedAvatar = rawAvatar != null ? ApiClient.resolveUrl(rawAvatar) : null;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: textPrimary,
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/app/home');
            }
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Creator Hub',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
            Text(
              'Create. Grow. Earn.',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BrandDealsHelpScreen()),
              );
            },
            icon: const Icon(Icons.help_outline_rounded),
            color: textPrimary,
            tooltip: 'Creator Guide',
          ),
          IconButton(
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
            color: textPrimary,
            tooltip: 'Settings',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Creator Profile Summary Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: DesignTokens.primary,
                    backgroundImage: resolvedAvatar != null ? CachedNetworkImageProvider(resolvedAvatar) : null,
                    child: resolvedAvatar == null
                        ? Text(
                            authorName.isNotEmpty ? authorName[0].toUpperCase() : 'U',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                authorName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.verified_rounded, size: 16, color: DesignTokens.primary),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '@$authorUsername · $followersCount followers',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () => context.push('/app/profile'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      side: const BorderSide(color: DesignTokens.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text(
                      'View Profile',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: DesignTokens.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. Total Earnings Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A68D4), Color(0xFF1555AD)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1A68D4).withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Earnings',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFE8F1FD),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.trending_up_rounded, color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text(
                              '+18.4% Last 30 days',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        displayEarnings,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      IconButton(
                        onPressed: () => context.push('/app/finances'),
                        icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 24),
                        tooltip: 'View Wallet & Payouts',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. Creator Analytics 3-Column Grid
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Performance Overview',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      Text(
                        _selectedPeriod,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: DesignTokens.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _metricBox(
                          title: 'Video Views',
                          value: '1.2M',
                          trend: '+12.4%',
                          trendUp: true,
                          isDark: isDark,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _metricBox(
                          title: 'Engagements',
                          value: '96.4K',
                          trend: '+8.2%',
                          trendUp: true,
                          isDark: isDark,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _metricBox(
                          title: 'New Followers',
                          value: '+12.3K',
                          trend: '+5.1%',
                          trendUp: true,
                          isDark: isDark,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 4. Quick Actions Row
            Row(
              children: [
                Expanded(
                  child: _quickActionTile(
                    iconName: 'Discovery',
                    label: 'Brand Deals',
                    badge: '3 New',
                    color: DesignTokens.primary,
                    isDark: isDark,
                    cardBg: cardBg,
                    borderColor: borderColor,
                    textPrimary: textPrimary,
                    onTap: () {},
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _quickActionTile(
                    iconName: 'Work',
                    label: 'My Campaigns',
                    badge: '1 Active',
                    color: const Color(0xFF16A34A),
                    isDark: isDark,
                    cardBg: cardBg,
                    borderColor: borderColor,
                    textPrimary: textPrimary,
                    onTap: () {},
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _quickActionTile(
                    iconName: 'Chart',
                    label: 'Analytics',
                    badge: null,
                    color: const Color(0xFF7C3AED),
                    isDark: isDark,
                    cardBg: cardBg,
                    borderColor: borderColor,
                    textPrimary: textPrimary,
                    onTap: () => context.push('/creator/studio'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _quickActionTile(
                    iconName: 'Scan',
                    label: 'Link in Bio',
                    badge: null,
                    color: const Color(0xFFD97706),
                    isDark: isDark,
                    cardBg: cardBg,
                    borderColor: borderColor,
                    textPrimary: textPrimary,
                    onTap: () => context.push('/app/profile'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 5. Recent Activity Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Activity',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text('See All', style: TextStyle(color: DesignTokens.primary, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _activities.length,
                separatorBuilder: (_, _) => Divider(height: 1, color: borderColor),
                itemBuilder: (ctx, i) {
                  final act = _activities[i];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (act['color'] as Color).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(act['icon'] as IconData, color: act['color'] as Color, size: 20),
                    ),
                    title: Text(
                      act['title'] as String,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textPrimary),
                    ),
                    subtitle: Text(
                      act['subtitle'] as String,
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                    trailing: Text(
                      act['time'] as String,
                      style: TextStyle(fontSize: 11, color: textSecondary, fontWeight: FontWeight.w500),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // 6. Brand Deals Marketplace Header & Tabs
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Brand Deals Marketplace',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      'Monetize with global brands securely via MurihPay Escrow',
                      style: TextStyle(
                        fontSize: 11,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => context.push('/brand-deals'),
                  icon: const Icon(Icons.open_in_new_rounded, size: 20, color: DesignTokens.primary),
                  tooltip: 'Full Marketplace',
                ),
              ],
            ),
            const SizedBox(height: 12),

            TabBar(
              controller: _tab,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: DesignTokens.primary,
              unselectedLabelColor: textSecondary,
              indicatorColor: DesignTokens.primary,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              tabs: const [
                Tab(text: 'Available Deals (4)'),
                Tab(text: 'My Applications (1)'),
                Tab(text: 'Active (1)'),
                Tab(text: 'Completed (8)'),
              ],
            ),
            const SizedBox(height: 14),

            // Brand Deal Campaign Cards
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _campaigns.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                final c = _campaigns[i];
                final isApplied = c['applied'] as bool? ?? false;

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: DesignTokens.primary.withValues(alpha: 0.1),
                            backgroundImage: CachedNetworkImageProvider(c['logo'] as String),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c['brand'] as String,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: textSecondary,
                                  ),
                                ),
                                Text(
                                  c['title'] as String,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '\$${(c['budget'] as num).toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: DesignTokens.primary,
                                ),
                              ),
                              Text(
                                '${c['daysLeft']} days left',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: (c['daysLeft'] as num) <= 3 ? const Color(0xFFDC2626) : textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E2638) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              c['requirements'] as String,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textSecondary),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.lock_rounded, size: 10, color: Color(0xFF16A34A)),
                                SizedBox(width: 4),
                                Text(
                                  'Escrow Protected',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF16A34A)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _showApplyModal(c),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: borderColor),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              child: Text(
                                'View Brief',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textPrimary),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: isApplied ? null : () => _showApplyModal(c),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isApplied ? const Color(0xFF16A34A) : DesignTokens.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              child: Text(
                                isApplied ? 'Applied ✓' : 'Apply Now',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _metricBox({
    required String title,
    required String value,
    required String trend,
    required bool trendUp,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2638) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textPrimary),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                trendUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                size: 11,
                color: const Color(0xFF16A34A),
              ),
              const SizedBox(width: 2),
              Text(
                trend,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF16A34A)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickActionTile({
    required String iconName,
    required String label,
    required String? badge,
    required Color color,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: MurihIcon(iconName, size: 18, color: color),
                ),
                if (badge != null)
                  Positioned(
                    top: -4,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: DesignTokens.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
