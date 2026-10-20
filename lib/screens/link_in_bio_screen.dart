import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/profile_qr_dialog.dart';
import '../components/share_sheet.dart';
import '../config/env.dart';
import '../core/api_client.dart';
import '../core/design_tokens.dart';
import '../providers/auth_provider.dart';

enum LinkType { url, product, social }

class LinkItem {
  int id;
  String title;
  String url;
  String? category; // Service, Video, Booking, Resource
  String? badge; // Primary, Popular, Featured, Download
  double? price;
  String currency;
  String iconEmoji;
  String icon3d; // bags, camera, calendar, box, link, star
  bool isActive;
  int clickCount;
  int uniqueVisitors;
  int sortOrder;

  LinkItem({
    required this.id,
    required this.title,
    required this.url,
    this.category,
    this.badge,
    this.price,
    this.currency = '\$',
    this.iconEmoji = '🔗',
    this.icon3d = 'link',
    this.isActive = true,
    this.clickCount = 0,
    this.uniqueVisitors = 0,
    this.sortOrder = 0,
  });

  factory LinkItem.fromJson(Map<String, dynamic> json) {
    return LinkItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? 'Untitled Link',
      url: json['url'] as String? ?? '',
      category: json['category'] as String?,
      badge: json['badge'] as String?,
      price: json['price'] != null
          ? double.tryParse(json['price'].toString())
          : null,
      currency: json['currency'] as String? ?? '\$',
      iconEmoji: json['icon_emoji'] as String? ?? '🔗',
      icon3d: json['icon_3d'] as String? ?? 'link',
      isActive: json['is_active'] == true || json['is_active'] == 1,
      clickCount: (json['click_count'] as num?)?.toInt() ?? 0,
      uniqueVisitors: (json['unique_visitors'] as num?)?.toInt() ?? 0,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'url': url,
    'category': category,
    'badge': badge,
    'price': price,
    'currency': currency,
    'icon_emoji': iconEmoji,
    'icon_3d': icon3d,
    'is_active': isActive,
    'sort_order': sortOrder,
  };
}

class BioThemePreset {
  final String name;
  final List<Color> bgGradient;
  final Color cardBg;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;
  final bool isGlass;

  const BioThemePreset({
    required this.name,
    required this.bgGradient,
    required this.cardBg,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    this.isGlass = false,
  });
}

const List<BioThemePreset> bioThemes = [
  BioThemePreset(
    name: 'Bento Glass',
    bgGradient: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF334155)],
    cardBg: Color(0x26FFFFFF),
    textPrimary: Colors.white,
    textSecondary: Colors.white70,
    accent: Color(0xFF38BDF8),
    isGlass: true,
  ),
  BioThemePreset(
    name: 'Midnight Dark',
    bgGradient: [Color(0xFF000000), Color(0xFF1C1C1E)],
    cardBg: Color(0xFF2C2C2E),
    textPrimary: Colors.white,
    textSecondary: Colors.white60,
    accent: DesignTokens.primary,
  ),
  BioThemePreset(
    name: 'Sunset Velvet',
    bgGradient: [Color(0xFF4A00E0), Color(0xFF8E2DE2), Color(0xFFF000FF)],
    cardBg: Color(0x33FFFFFF),
    textPrimary: Colors.white,
    textSecondary: Colors.white70,
    accent: Color(0xFFFF9500),
    isGlass: true,
  ),
  BioThemePreset(
    name: 'Golden Luxury',
    bgGradient: [Color(0xFF1A1A1A), Color(0xFF2D251E)],
    cardBg: Color(0xFF3B3026),
    textPrimary: Color(0xFFFFD700),
    textSecondary: Color(0xFFD4AF37),
    accent: Color(0xFFFFD700),
  ),
  BioThemePreset(
    name: 'Neon Cyberpunk',
    bgGradient: [Color(0xFF0D0221), Color(0xFF0F084B)],
    cardBg: Color(0xFF261447),
    textPrimary: Color(0xFFFF007F),
    textSecondary: Color(0xFF00F5D4),
    accent: Color(0xFF00F5D4),
  ),
  BioThemePreset(
    name: 'Minimalist Pure',
    bgGradient: [Color(0xFFF8F9FA), Color(0xFFE9ECEF)],
    cardBg: Colors.white,
    textPrimary: Color(0xFF212529),
    textSecondary: Color(0xFF6C757D),
    accent: DesignTokens.primary,
  ),
];

/// Redesigned Link in Bio Studio matching the reference design layout.
class LinkInBioScreen extends ConsumerStatefulWidget {
  const LinkInBioScreen({super.key});

  @override
  ConsumerState<LinkInBioScreen> createState() => _LinkInBioScreenState();
}

class _LinkInBioScreenState extends ConsumerState<LinkInBioScreen> {
  int _activeNavIndex =
      0; // 0: Editor, 1: Live Preview, 2: Themes, 3: Analytics, 4: Settings
  final String _selectedPeriod = 'Last 30 Days';

  final _bioTitleCtrl = TextEditingController(
    text: 'Official Creator & Storefront Hub',
  );
  final _bioDescCtrl = TextEditingController(
    text:
        'Shop digital products, book 1-on-1 strategy sessions, and watch latest content.',
  );

  BioThemePreset _selectedTheme = bioThemes[0];

  bool _isLoading = false;
  List<LinkItem> _links = [];

  @override
  void initState() {
    super.initState();
    _loadBioData();
  }

  @override
  void dispose() {
    _bioTitleCtrl.dispose();
    _bioDescCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBioData() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiClient.instance.dio.get('/link-in-bio');
      final payload = ApiClient.instance.unwrap(res);

      if (payload is Map<String, dynamic>) {
        if (!mounted) return;
        setState(() {
          if (payload['profile_name'] != null) {
            _bioTitleCtrl.text = payload['profile_name'].toString();
          }
          if (payload['profile_bio'] != null) {
            _bioDescCtrl.text = payload['profile_bio'].toString();
          }
        });
        final linksRaw = payload['links'];
        if (linksRaw is List) {
          final loaded = linksRaw
              .whereType<Map<String, dynamic>>()
              .map((j) => LinkItem.fromJson(j))
              .toList();
          loaded.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
          setState(() {
            _links = loaded;
          });
          return;
        }
      }
    } catch (_) {
      // Fallback to default populated seed if API call encounters network issue
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleLinkActive(LinkItem link) async {
    final nextState = !link.isActive;
    setState(() => link.isActive = nextState);
    try {
      await ApiClient.instance.dio.patch(
        '/link-in-bio/${link.id}',
        data: {'is_active': nextState},
      );
    } catch (_) {
      // Revert if API failed
      if (mounted) setState(() => link.isActive = !nextState);
    }
  }

  Future<void> _deleteLink(int index) async {
    final link = _links[index];
    setState(() => _links.removeAt(index));
    try {
      await ApiClient.instance.dio.delete('/link-in-bio/${link.id}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Link deleted successfully')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _links.insert(index.clamp(0, _links.length), link));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not delete link. Please try again.'),
        ),
      );
    }
  }

  void _showAddLinkSheet([LinkItem? existing]) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final urlCtrl = TextEditingController(text: existing?.url ?? '');
    final priceCtrl = TextEditingController(
      text: existing?.price != null ? existing!.price.toString() : '',
    );
    String selectedCategory = existing?.category ?? 'Service';
    String selectedBadge = existing?.badge ?? 'Primary';
    String selected3d = existing?.icon3d ?? 'bags';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1E293B)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[700] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  existing == null ? 'Add New Link' : 'Edit Link Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 14),

                // 3D Visual Icon Selection
                const Text(
                  '3D Icon Graphic',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _build3DChoiceOption(
                        'bags',
                        'Shopping Bag',
                        selected3d,
                        (val) => setModalState(() => selected3d = val),
                      ),
                      const SizedBox(width: 8),
                      _build3DChoiceOption(
                        'camera',
                        'Video Camera',
                        selected3d,
                        (val) => setModalState(() => selected3d = val),
                      ),
                      const SizedBox(width: 8),
                      _build3DChoiceOption(
                        'calendar',
                        'Calendar Date',
                        selected3d,
                        (val) => setModalState(() => selected3d = val),
                      ),
                      const SizedBox(width: 8),
                      _build3DChoiceOption(
                        'box',
                        'Package Box',
                        selected3d,
                        (val) => setModalState(() => selected3d = val),
                      ),
                      const SizedBox(width: 8),
                      _build3DChoiceOption(
                        'link',
                        'Standard Link',
                        selected3d,
                        (val) => setModalState(() => selected3d = val),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: titleCtrl,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Link Title',
                    hintText: 'e.g. Full-Stack Services',
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: urlCtrl,
                  keyboardType: TextInputType.url,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    labelText: 'Destination URL',
                    hintText: 'https://...',
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Category & Badge tag fields
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedCategory,
                        dropdownColor: isDark
                            ? const Color(0xFF1E293B)
                            : Colors.white,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Category',
                          filled: true,
                          fillColor: isDark
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        items:
                            [
                                  'Service',
                                  'Video',
                                  'Booking',
                                  'Resource',
                                  'Shop',
                                  'Custom',
                                ]
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c),
                                  ),
                                )
                                .toList(),
                        onChanged: (val) {
                          if (val != null)
                            setModalState(() => selectedCategory = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedBadge,
                        dropdownColor: isDark
                            ? const Color(0xFF1E293B)
                            : Colors.white,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Badge Tag',
                          filled: true,
                          fillColor: isDark
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        items:
                            [
                                  'Primary',
                                  'Popular',
                                  'Featured',
                                  'Download',
                                  'New',
                                  'None',
                                ]
                                .map(
                                  (b) => DropdownMenuItem(
                                    value: b,
                                    child: Text(b),
                                  ),
                                )
                                .toList(),
                        onChanged: (val) {
                          if (val != null)
                            setModalState(() => selectedBadge = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Optional Price Badge',
                    hintText: '49.99',
                    prefixText: '\$ ',
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2164B6),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      final t = titleCtrl.text.trim();
                      final u = urlCtrl.text.trim();
                      final p = double.tryParse(priceCtrl.text.trim());
                      if (t.isEmpty || u.isEmpty) return;

                      final linkData = {
                        'title': t,
                        'url': u,
                        'category': selectedCategory,
                        'badge': selectedBadge == 'None' ? null : selectedBadge,
                        'price': p,
                        'currency': '\$',
                        'icon_3d': selected3d,
                        'is_active': existing?.isActive ?? true,
                      };

                      bool success = false;
                      if (existing != null) {
                        final prevTitle = existing.title;
                        final prevUrl = existing.url;
                        final prevCategory = existing.category;
                        final prevBadge = existing.badge;
                        final prevPrice = existing.price;
                        final prev3d = existing.icon3d;

                        setState(() {
                          existing.title = t;
                          existing.url = u;
                          existing.category = selectedCategory;
                          existing.badge = selectedBadge == 'None'
                              ? null
                              : selectedBadge;
                          existing.price = p;
                          existing.icon3d = selected3d;
                        });
                        try {
                          await ApiClient.instance.dio.patch(
                            '/link-in-bio/${existing.id}',
                            data: linkData,
                          );
                          success = true;
                        } catch (_) {
                          if (mounted) {
                            setState(() {
                              existing.title = prevTitle;
                              existing.url = prevUrl;
                              existing.category = prevCategory;
                              existing.badge = prevBadge;
                              existing.price = prevPrice;
                              existing.icon3d = prev3d;
                            });
                          }
                        }
                      } else {
                        final newLink = LinkItem(
                          id: 0,
                          title: t,
                          url: u,
                          category: selectedCategory,
                          badge: selectedBadge == 'None' ? null : selectedBadge,
                          price: p,
                          currency: '\$',
                          icon3d: selected3d,
                          clickCount: 0,
                          uniqueVisitors: 0,
                          sortOrder: _links.length + 1,
                        );
                        try {
                          final res = await ApiClient.instance.dio.post(
                            '/link-in-bio',
                            data: linkData,
                          );
                          final payload = ApiClient.instance.unwrap(res);
                          if (payload is Map<String, dynamic>) {
                            final linkObj =
                                (payload['link'] ?? payload['data'] ?? payload)
                                    as Map<String, dynamic>?;
                            final rawId = linkObj?['id'] ?? payload['id'];
                            final serverId = (rawId as num?)?.toInt();
                            if (serverId != null) {
                              newLink.id = serverId;
                            }
                          }
                          if (mounted) setState(() => _links.add(newLink));
                          success = true;
                        } catch (_) {
                          success = false;
                        }
                      }
                      if (context.mounted) {
                        if (success) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                existing == null
                                    ? 'New link added!'
                                    : 'Link updated!',
                              ),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Failed to save link. Please try again.',
                              ),
                            ),
                          );
                        }
                      }
                    },
                    child: Text(
                      existing == null ? 'Add Link to Bio' : 'Save Changes',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _build3DChoiceOption(
    String key,
    String label,
    String currentSelected,
    ValueChanged<String> onSelect,
  ) {
    final isSelected = key == currentSelected;
    return GestureDetector(
      onTap: () => onSelect(key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2164B6).withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF2164B6)
                : Colors.grey.withValues(alpha: 0.3),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _build3DIconBadge(key, size: 28),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQrCodeModal(String username, String bioUrl) {
    final user = ref.read(authProvider).user;
    final name = user?.name ?? username;
    final avatarUrl = user?.avatarUrl;
    ProfileQrSheet.show(
      context,
      name: name,
      username: username,
      avatarUrl: avatarUrl,
      url: bioUrl.startsWith('http') ? bioUrl : 'https://$bioUrl',
      title: 'Bio Link QR Code',
      subtitle: 'Scan to open @$username bio hub',
      sharePrompt: 'Check out my links and profile on MurihSpace:',
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final username = user?.username ?? 'user';
    final name = user?.name ?? 'User';
    // Two separate links on the canonical domain: the profile (/@handle) and the
    // link-in-bio page (/l/handle). Neither uses the main website.
    final profileLink = Env.profileUrl(username);
    final bioLink = Env.linkInBioUrl(username);
    final bioUrl = bioLink.replaceFirst(RegExp(r'^https?://'), '');

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    final totalClicks = _links.fold<int>(0, (sum, l) => sum + l.clickCount);
    final activeCount = _links.where((l) => l.isActive).length;
    final totalVisitors = _links.fold<int>(
      0,
      (sum, l) => sum + l.uniqueVisitors,
    );

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Link in Bio Studio',
              style: TextStyle(
                color: textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: bioLink));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link copied to clipboard!')),
                );
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      bioUrl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF2164B6),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.copy_rounded,
                    size: 12,
                    color: Color(0xFF2164B6),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.qr_code_rounded, color: textPrimary),
            tooltip: 'QR Code',
            onPressed: () => _showQrCodeModal(username, bioLink),
          ),
          IconButton(
            icon: Icon(Icons.share_outlined, color: textPrimary),
            tooltip: 'Share Bio Link',
            onPressed: () {
              AppShare.share(
                context,
                text: 'Check out my links on MurihSpace: $bioLink',
                title: '$name - Link in Bio',
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.more_vert_rounded, color: textPrimary),
            onPressed: () {},
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Top Hero / Live Phone Mockup Banner
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: _buildHeroCard(name, username, bioUrl, isDark),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _linkRow(
                      label: 'Profile link',
                      url: profileLink,
                      isDark: isDark,
                    ),
                  ),
                ),

                // Performance Overview Metric Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: _buildPerformanceOverview(
                      totalClicks: totalClicks,
                      activeLinks: activeCount,
                      uniqueVisitors: totalVisitors,
                      currentTheme: _selectedTheme.name,
                      cardBg: cardBg,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),
                  ),
                ),

                // Studio Section Tabs (Editor, Live Preview, Themes, Analytics, Settings)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 12),
                    child: _buildNavigationTabs(textPrimary, textSecondary),
                  ),
                ),

                // Active Tab Content
                if (_activeNavIndex == 0) ...[
                  // EDITOR VIEW (Your Links List)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your Links',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Drag to reorder • Toggle to show/hide • Tap to edit',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2164B6),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            onPressed: () => _showAddLinkSheet(),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text(
                              'Add New Link',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Reorderable Link Cards
                  if (_links.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 32,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.link_off_rounded,
                                size: 48,
                                color: textSecondary.withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No links added yet',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Add your first link to start showcasing your content.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((ctx, index) {
                          final link = _links[index];
                          return _buildLinkCardItem(
                            link: link,
                            index: index + 1,
                            cardBg: cardBg,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            isDark: isDark,
                          );
                        }, childCount: _links.length),
                      ),
                    ),
                ] else if (_activeNavIndex == 1) ...[
                  // LIVE PREVIEW VIEW
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: _buildPhoneLivePreview(name, username, isDark),
                      ),
                    ),
                  ),
                ] else if (_activeNavIndex == 2) ...[
                  // THEMES VIEW
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _buildThemesGrid(
                        cardBg,
                        textPrimary,
                        textSecondary,
                      ),
                    ),
                  ),
                ] else if (_activeNavIndex == 3) ...[
                  // DETAILED ANALYTICS VIEW
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _buildDetailedAnalytics(
                        cardBg,
                        textPrimary,
                        textSecondary,
                      ),
                    ),
                  ),
                ] else ...[
                  // SETTINGS VIEW
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _buildBioSettings(
                        cardBg,
                        textPrimary,
                        textSecondary,
                      ),
                    ),
                  ),
                ],

                const SliverToBoxAdapter(child: SizedBox(height: 60)),
              ],
            ),
    );
  }

  /// A labelled link with a copy action. Used for the profile link, which is
  /// kept apart from the link-in-bio.
  Widget _linkRow({
    required String label,
    required String url,
    required bool isDark,
  }) {
    final display = url.replaceFirst(RegExp(r'^https?://'), '');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                ),
                Text(
                  display.isEmpty ? 'Unavailable' : display,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copy profile link',
            icon: const Icon(Icons.copy_rounded, size: 18),
            onPressed: url.isEmpty
                ? null
                : () {
                    Clipboard.setData(ClipboardData(text: url));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Profile link copied!')),
                    );
                  },
          ),
        ],
      ),
    );
  }

  // ── HERO CARD WITH PHONE MOCKUP PREVIEW ─────────────────────────
  Widget _buildHeroCard(
    String name,
    String username,
    String bioUrl,
    bool isDark,
  ) {
    final hasBadge =
        ref.read(authProvider).user?.hasActiveVerificationBadge == true;
    return Container(
      height: 190,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF8EC5FC), Color(0xFFE0C3FC), Color(0xFF93C5FD)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2164B6).withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background soft landscape or aurora glow
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Opacity(
                opacity: 0.35,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF2563EB),
                        Color(0xFF7C3AED),
                        Color(0xFFDB2777),
                      ],
                      begin: Alignment.bottomLeft,
                      end: Alignment.topRight,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Content Left side
          Positioned(
            left: 18,
            top: 18,
            bottom: 18,
            right: 140,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    // Avatar circle with initial or photo
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Color(0xFF2164B6),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'V',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  style: const TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              if (hasBadge)
                                const Icon(
                                  Icons.verified_rounded,
                                  color: Color(0xFF2164B6),
                                  size: 16,
                                ),
                            ],
                          ),
                          Text(
                            '@$username',
                            style: const TextStyle(
                              color: Color(0xFF334155),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Copy URL pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          bioUrl,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.copy_rounded,
                        size: 12,
                        color: Color(0xFF0F172A),
                      ),
                    ],
                  ),
                ),

                // Action buttons: View Live Page & Customize
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.8),
                          foregroundColor: const Color(0xFF0F172A),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          setState(() => _activeNavIndex = 1);
                        },
                        icon: const Icon(Icons.visibility_outlined, size: 14),
                        label: const Text(
                          'View Live Page',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2164B6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          setState(() => _activeNavIndex = 2);
                        },
                        icon: const Icon(Icons.edit_outlined, size: 14),
                        label: const Text(
                          'Customize',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Mini Phone Mockup Frame on Right
          Positioned(
            right: 14,
            top: 14,
            bottom: 0,
            child: Container(
              width: 124,
              decoration: BoxDecoration(
                color: const Color(0xFF0B1220),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(22),
                ),
                border: Border.all(color: const Color(0xFF334155), width: 3),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black38,
                    blurRadius: 10,
                    offset: Offset(-2, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(6),
              child: Column(
                children: [
                  // Phone speaker pill
                  Container(
                    width: 24,
                    height: 3,
                    decoration: BoxDecoration(
                      color: Colors.white30,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Avatar
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2164B6),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text(
                        'V',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                  ),
                  Text(
                    '@$username',
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 6.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Mini social icons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.play_circle_fill, size: 9, color: Colors.red),
                      SizedBox(width: 3),
                      Icon(Icons.camera_alt, size: 8, color: Colors.pink),
                      SizedBox(width: 3),
                      Icon(Icons.music_note, size: 8, color: Colors.cyan),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Mini pill links
                  ..._links
                      .take(3)
                      .map(
                        (l) => Container(
                          margin: const EdgeInsets.only(bottom: 3),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  l.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 6,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right,
                                size: 8,
                                color: Colors.white70,
                              ),
                            ],
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ),

          // Floating "Edit Theme" pill top-right
          Positioned(
            right: 20,
            top: 20,
            child: GestureDetector(
              onTap: () => setState(() => _activeNavIndex = 2),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 4),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.palette_outlined,
                      size: 11,
                      color: Color(0xFF0F172A),
                    ),
                    SizedBox(width: 3),
                    Text(
                      'Edit Theme',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── PERFORMANCE OVERVIEW 4-COLUMN CARDS ─────────────────────────
  Widget _buildPerformanceOverview({
    required int totalClicks,
    required int activeLinks,
    required int uniqueVisitors,
    required String currentTheme,
    required Color cardBg,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2164B6).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.bar_chart_rounded,
                    size: 16,
                    color: Color(0xFF2164B6),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Performance Overview',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
            // Period Filter Dropdown Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF2164B6).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF2164B6).withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    size: 12,
                    color: Color(0xFF2164B6),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _selectedPeriod,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2164B6),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 14,
                    color: Color(0xFF2164B6),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 4 Stat Cards Row
        Row(
          children: [
            // Card 1: Total Clicks
            Expanded(
              child: _buildMetricTile(
                icon: Icons.navigation_rounded,
                iconColor: const Color(0xFF2164B6),
                iconBg: const Color(0xFF2164B6).withValues(alpha: 0.12),
                value: '$totalClicks',
                label: 'Total Clicks',
                trend: '+18.4%',
                isPositive: true,
                cardBg: cardBg,
                textPrimary: textPrimary,
              ),
            ),
            const SizedBox(width: 8),

            // Card 2: Active Links
            Expanded(
              child: _buildMetricTile(
                icon: Icons.link_rounded,
                iconColor: const Color(0xFF10B981),
                iconBg: const Color(0xFF10B981).withValues(alpha: 0.12),
                value: '$activeLinks',
                label: 'Active Links',
                trend: '+0%',
                isPositive: true,
                cardBg: cardBg,
                textPrimary: textPrimary,
              ),
            ),
            const SizedBox(width: 8),

            // Card 3: Unique Visitors
            Expanded(
              child: _buildMetricTile(
                icon: Icons.person_outline_rounded,
                iconColor: const Color(0xFFF43F5E),
                iconBg: const Color(0xFFF43F5E).withValues(alpha: 0.12),
                value: uniqueVisitors >= 1000
                    ? '${(uniqueVisitors / 1000).toStringAsFixed(1)}K'
                    : '$uniqueVisitors',
                label: 'Unique Visitors',
                trend: '+12.3%',
                isPositive: true,
                cardBg: cardBg,
                textPrimary: textPrimary,
              ),
            ),
            const SizedBox(width: 8),

            // Card 4: Bento Glass Theme
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _activeNavIndex = 2),
                child: Container(
                  height: 104,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFA855F7,
                          ).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.palette_rounded,
                          size: 14,
                          color: Color(0xFFA855F7),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  currentTheme,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right,
                                size: 14,
                                color: Colors.grey,
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Current Theme',
                            style: TextStyle(
                              fontSize: 9.5,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String value,
    required String label,
    required String trend,
    required bool isPositive,
    required Color cardBg,
    required Color textPrimary,
  }) {
    return Container(
      height: 104,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, size: 14, color: iconColor),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 9.5,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(
                    isPositive
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                    size: 11,
                    color: isPositive ? const Color(0xFF10B981) : Colors.red,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    trend,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: isPositive ? const Color(0xFF10B981) : Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── STUDIO NAVIGATION TABS (Editor, Live Preview, Themes, Analytics, Settings) ──
  Widget _buildNavigationTabs(Color textPrimary, Color textSecondary) {
    final tabs = [
      {'label': 'Editor', 'icon': Icons.tab_rounded},
      {'label': 'Live Preview', 'icon': Icons.phone_android_rounded},
      {'label': 'Themes', 'icon': Icons.palette_outlined},
      {'label': 'Analytics', 'icon': Icons.bar_chart_rounded},
      {'label': 'Settings', 'icon': Icons.settings_outlined},
    ];

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: List.generate(tabs.length, (idx) {
            final t = tabs[idx];
            final isSelected = _activeNavIndex == idx;
            return GestureDetector(
              onTap: () => setState(() => _activeNavIndex = idx),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected
                          ? const Color(0xFF2164B6)
                          : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      t['icon'] as IconData,
                      size: 15,
                      color: isSelected
                          ? const Color(0xFF2164B6)
                          : textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      t['label'] as String,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.w900
                            : FontWeight.w600,
                        color: isSelected
                            ? const Color(0xFF2164B6)
                            : textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ── LINK CARD ITEM WITH 3D GRAPHIC & STATS ────────────────────────
  Widget _buildLinkCardItem({
    required LinkItem link,
    required int index,
    required Color cardBg,
    required Color textPrimary,
    required Color textSecondary,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Drag handle icon
          const Icon(
            Icons.drag_indicator_rounded,
            color: Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 4),

          // Number Circle Pill (e.g. 1, 2, 3, 4)
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: const Color(0xFF2164B6).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$index',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF2164B6),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // 3D Graphic Container (bags, camera, calendar, box)
          _build3DIconBadge(link.icon3d, size: 54),
          const SizedBox(width: 12),

          // Middle info (Title, Price, URL, Category tags, Click metrics)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title + Price badge
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        link.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (link.price != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF10B981,
                          ).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${link.currency}${link.price!.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),

                // Destination URL
                Text(
                  link.url,
                  style: TextStyle(fontSize: 11, color: textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),

                // Category & Badge Chips Row
                Row(
                  children: [
                    if (link.category != null)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFA855F7,
                          ).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          link.category!,
                          style: const TextStyle(
                            color: Color(0xFFA855F7),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    if (link.badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF2164B6,
                          ).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          link.badge!,
                          style: const TextStyle(
                            color: Color(0xFF2164B6),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),

                // Metrics row: Clicks, Unique, Trend
                Row(
                  children: [
                    const Icon(
                      Icons.link_rounded,
                      size: 12,
                      color: Color(0xFF2164B6),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${link.clickCount} clicks',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2164B6),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.bar_chart_rounded,
                      size: 12,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${link.uniqueVisitors} unique',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.trending_up_rounded,
                      size: 12,
                      color: Color(0xFF10B981),
                    ),
                    const SizedBox(width: 2),
                    const Text(
                      '+16%',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Active switch toggle
          Switch(
            value: link.isActive,
            activeThumbColor: const Color(0xFF2164B6),
            onChanged: (val) => _toggleLinkActive(link),
          ),

          // Tap to edit chevron
          IconButton(
            icon: const Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey,
              size: 20,
            ),
            onPressed: () => _showAddLinkSheet(link),
          ),

          // More popup menu (delete, duplicate)
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert_rounded,
              color: Colors.grey,
              size: 18,
            ),
            onSelected: (val) {
              if (val == 'edit') {
                _showAddLinkSheet(link);
              } else if (val == 'delete') {
                _deleteLink(index - 1);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit Link')),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete Link', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 3D VOLUMETRIC ICON GLYPH RENDERER ───────────────────────────
  Widget _build3DIconBadge(String type, {double size = 50}) {
    List<Color> gradientColors;
    IconData icon;

    switch (type.toLowerCase()) {
      case 'bags':
      case 'bag':
      case 'shop':
        gradientColors = [
          const Color(0xFFFDE8E8),
          const Color(0xFFFBCFE8),
          const Color(0xFFF472B6),
        ];
        icon = Icons.shopping_bag_rounded;
        break;
      case 'camera':
      case 'video':
        gradientColors = [
          const Color(0xFFE0E7FF),
          const Color(0xFFC7D2FE),
          const Color(0xFF818CF8),
        ];
        icon = Icons.videocam_rounded;
        break;
      case 'calendar':
      case 'booking':
        gradientColors = [
          const Color(0xFFFEE2E2),
          const Color(0xFFFECACA),
          const Color(0xFFF87171),
        ];
        icon = Icons.calendar_month_rounded;
        break;
      case 'box':
      case 'resource':
        gradientColors = [
          const Color(0xFFFEF3C7),
          const Color(0xFFFDE68A),
          const Color(0xFFF59E0B),
        ];
        icon = Icons.inventory_2_rounded;
        break;
      default:
        gradientColors = [
          const Color(0xFFE0F2FE),
          const Color(0xFFBAE6FD),
          const Color(0xFF38BDF8),
        ];
        icon = Icons.link_rounded;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.32),
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: gradientColors.last.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.7),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Icon(icon, size: size * 0.52, color: const Color(0xFF1E293B)),
      ),
    );
  }

  // ── PHONE LIVE PREVIEW CONTAINER ────────────────────────────────
  Widget _buildPhoneLivePreview(String name, String username, bool isDark) {
    final hasBadge =
        ref.read(authProvider).user?.hasActiveVerificationBadge == true;
    return Container(
      width: 320,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _selectedTheme.bgGradient,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(38),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.4), width: 6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 24,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Speaker notch
          Container(
            width: 56,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 18),

          // Avatar
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: Color(0xFF2164B6),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'V',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 26,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                name,
                style: TextStyle(
                  color: _selectedTheme.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const SizedBox(width: 4),
              if (hasBadge)
                const Icon(
                  Icons.verified_rounded,
                  color: Color(0xFF2164B6),
                  size: 16,
                ),
            ],
          ),
          Text(
            '@$username',
            style: TextStyle(color: _selectedTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            _bioDescCtrl.text,
            style: TextStyle(color: _selectedTheme.textSecondary, fontSize: 11),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Social icons bar
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _socialBubble(Icons.play_circle_fill, Colors.red),
              const SizedBox(width: 8),
              _socialBubble(Icons.camera_alt, Colors.pink),
              const SizedBox(width: 8),
              _socialBubble(Icons.alternate_email, Colors.blue),
              const SizedBox(width: 8),
              _socialBubble(Icons.music_note, Colors.cyan),
            ],
          ),
          const SizedBox(height: 20),

          // Render active link buttons
          ..._links.where((l) => l.isActive).map((link) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _selectedTheme.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  _build3DIconBadge(link.icon3d, size: 30),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      link.title,
                      style: TextStyle(
                        color: _selectedTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (link.price != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _selectedTheme.accent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${link.currency}${link.price}',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ] else
                    Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: _selectedTheme.textSecondary,
                    ),
                ],
              ),
            );
          }),

          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                color: _selectedTheme.textSecondary,
                size: 12,
              ),
              const SizedBox(width: 4),
              Text(
                'Protected by MurihSpace Escrow',
                style: TextStyle(
                  color: _selectedTheme.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _socialBubble(IconData icon, Color color) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Center(child: Icon(icon, size: 15, color: Colors.white)),
    );
  }

  // ── THEMES GRID TAB ─────────────────────────────────────────────
  Widget _buildThemesGrid(
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Theme Preset',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 2.1,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: bioThemes.length,
          itemBuilder: (ctx, idx) {
            final theme = bioThemes[idx];
            final isSelected = _selectedTheme.name == theme.name;
            return GestureDetector(
              onTap: () {
                setState(() => _selectedTheme = theme);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Applied theme: ${theme.name}')),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: theme.bgGradient),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF2164B6)
                        : Colors.transparent,
                    width: 2.5,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            theme.name,
                            style: TextStyle(
                              color: theme.textPrimary,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            theme.isGlass ? 'Glassmorphism' : 'Solid Clean',
                            style: TextStyle(
                              color: theme.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF2164B6),
                        size: 18,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ── DETAILED ANALYTICS TAB ──────────────────────────────────────
  Widget _buildDetailedAnalytics(
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Link Click Distribution',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          ..._links.map((l) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l.title,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      Text(
                        '${l.clickCount} clicks',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF2164B6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: l.clickCount > 0
                          ? (l.clickCount / 1500).clamp(0.05, 1.0)
                          : 0.05,
                      backgroundColor: Colors.grey.withValues(alpha: 0.15),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF2164B6),
                      ),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── BIO SETTINGS TAB ────────────────────────────────────────────
  Widget _buildBioSettings(
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bio Hub Information',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bioTitleCtrl,
            style: TextStyle(color: textPrimary),
            decoration: InputDecoration(
              labelText: 'Profile Display Name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bioDescCtrl,
            maxLines: 3,
            style: TextStyle(color: textPrimary),
            decoration: InputDecoration(
              labelText: 'Bio Subtitle & Description',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2164B6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () async {
                try {
                  await ApiClient.instance.dio.put(
                    '/link-in-bio/profile',
                    data: {
                      'profile_name': _bioTitleCtrl.text.trim(),
                      'profile_bio': _bioDescCtrl.text.trim(),
                    },
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Bio profile settings updated!'),
                      ),
                    );
                  }
                } catch (_) {}
              },
              child: const Text(
                'Save Bio Settings',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
