import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';

enum LinkType { url, product, social }

class LinkItem {
  final int id;
  String title;
  String url;
  String icon;
  LinkType _type;
  double? price;
  String currencySymbol;
  bool isActive;
  int clickCount;

  LinkType get type => _type;
  set type(LinkType val) => _type = val;

  LinkItem({
    required this.id,
    required this.title,
    required this.url,
    this.icon = '🔗',
    LinkType type = LinkType.url,
    this.price,
    this.currencySymbol = '₦',
    this.isActive = true,
    this.clickCount = 0,
  }) : _type = type;
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

const List<BioThemePreset> BIO_THEMES = [
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
    accent: Color(0xFF007AFF),
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
    accent: Color(0xFF007AFF),
  ),
];

/// Pro Bento/Linktree-Style Link in Bio Builder & Live Preview Hub for Creators & Vendors.
class LinkInBioScreen extends ConsumerStatefulWidget {
  const LinkInBioScreen({super.key});

  @override
  ConsumerState<LinkInBioScreen> createState() => _LinkInBioScreenState();
}

class _LinkInBioScreenState extends ConsumerState<LinkInBioScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _bioTitleCtrl = TextEditingController(text: 'Official Creator & Storefront Hub ✨');
  final _bioDescCtrl = TextEditingController(text: 'Shop digital products, book 1-on-1 coaching, and explore my latest projects.');
  
  dynamic _selectedThemeRaw = BIO_THEMES[0];

  BioThemePreset get _selectedTheme {
    if (_selectedThemeRaw is BioThemePreset) {
      return _selectedThemeRaw as BioThemePreset;
    }
    if (_selectedThemeRaw is String) {
      final name = _selectedThemeRaw as String;
      return BIO_THEMES.firstWhere(
        (t) => t.name.toLowerCase() == name.toLowerCase(),
        orElse: () => BIO_THEMES[0],
      );
    }
    return BIO_THEMES[0];
  }

  String _buttonStyle = 'Pill'; // Pill, Rounded, Sharp

  final List<LinkItem> _links = [
    LinkItem(
      id: 1,
      title: '🛍️ Full-Stack Starter Kit 2026',
      url: 'https://murihspace.com/store/products/1',
      icon: '🛍️',
      type: LinkType.product,
      price: 49.99,
      currencySymbol: '\$',
      clickCount: 1420,
    ),
    LinkItem(
      id: 2,
      title: '🎥 Watch Latest YouTube Tutorial',
      url: 'https://youtube.com/@creator',
      icon: '🎥',
      type: LinkType.url,
      clickCount: 890,
    ),
    LinkItem(
      id: 3,
      title: '📅 Book 1-on-1 Strategy Session',
      url: 'https://murihspace.com/coaching',
      icon: '📅',
      type: LinkType.url,
      clickCount: 450,
    ),
    LinkItem(
      id: 4,
      title: '📜 Creator Media Kit & Analytics',
      url: 'https://murihspace.com/media-kit',
      icon: '📜',
      type: LinkType.url,
      clickCount: 310,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _bioTitleCtrl.dispose();
    _bioDescCtrl.dispose();
    super.dispose();
  }

  void _showAddLinkSheet([LinkItem? existing]) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final urlCtrl = TextEditingController(text: existing?.url ?? '');
    final priceCtrl = TextEditingController(text: existing?.price != null ? existing!.price.toString() : '');
    LinkType selectedType = existing?.type ?? LinkType.url;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Padding(
            padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(color: isDark ? Colors.grey[700] : Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  existing == null ? 'Add Link to Bio' : 'Edit Link',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black),
                ),
                const SizedBox(height: 14),

                // Link Type Selector
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('URL Link'),
                        selected: selectedType == LinkType.url,
                        onSelected: (_) => setModalState(() => selectedType = LinkType.url),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Store Product'),
                        selected: selectedType == LinkType.product,
                        onSelected: (_) => setModalState(() => selectedType = LinkType.product),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: titleCtrl,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    labelText: 'Title / Label',
                    hintText: selectedType == LinkType.product ? 'e.g. Figma UI Kit 2026' : 'e.g. My Website',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: urlCtrl,
                  keyboardType: TextInputType.url,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    labelText: 'Destination URL',
                    hintText: 'https://...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 10),

                if (selectedType == LinkType.product) ...[
                  TextField(
                    controller: priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    decoration: InputDecoration(
                      labelText: 'Price (USD / NGN)',
                      hintText: '49.99',
                      prefixText: '\$ ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007AFF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      final t = titleCtrl.text.trim();
                      final u = urlCtrl.text.trim();
                      final p = double.tryParse(priceCtrl.text.trim());
                      if (t.isEmpty || u.isEmpty) return;

                      setState(() {
                        if (existing != null) {
                          existing.title = t;
                          existing.url = u;
                          existing.type = selectedType;
                          existing.price = p;
                        } else {
                          _links.add(LinkItem(
                            id: DateTime.now().millisecondsSinceEpoch,
                            title: t,
                            url: u,
                            type: selectedType,
                            price: p,
                            icon: selectedType == LinkType.product ? '🛍️' : '🔗',
                          ));
                        }
                      });
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(existing == null ? 'Link added to your Bio!' : 'Link updated!')),
                      );
                    },
                    child: Text(existing == null ? 'Add Link' : 'Save Changes', style: const TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showQrCodeModal(String username, String bioUrl) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(color: isDark ? Colors.grey[700] : Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 16),
                Text('Bio Link QR Code', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                const SizedBox(height: 6),
                Text('Scan to open @$username bio hub', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                const SizedBox(height: 20),
                
                // Simulated QR Code Frame
                Container(
                  width: 180,
                  height: 180,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 16)],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Grid QR code pattern
                      GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, crossAxisSpacing: 4, mainAxisSpacing: 4),
                        itemCount: 49,
                        itemBuilder: (context, index) {
                          final isDarkCell = (index * 7 + index * 3) % 5 != 0;
                          return Container(
                            decoration: BoxDecoration(
                              color: isDarkCell ? Colors.black : Colors.white,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          );
                        },
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: const Icon(Icons.link_rounded, color: Color(0xFF007AFF), size: 24),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF007AFF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: bioUrl));
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bio Link URL copied!')));
                        },
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: const Text('Copy Link', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? const Color(0xFF3A3B3C) : const Color(0xFFE4E6EB),
                          foregroundColor: isDark ? Colors.white : Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('QR Code image saved to gallery!')));
                        },
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: const Text('Save QR', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final username = user?.username ?? 'creator';
    final name = user?.name ?? 'Creator & Vendor';
    final bioUrl = 'https://murihspace.com/bio/@$username';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : const Color(0xFFF2F2F7);
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

    final totalClicks = _links.fold<int>(0, (sum, l) => sum + l.clickCount);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Link in Bio Studio', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w900, fontSize: 18)),
            Text('murihspace.com/bio/@$username', style: const TextStyle(color: Color(0xFF007AFF), fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_rounded, color: Color(0xFF007AFF)),
            tooltip: 'QR Code',
            onPressed: () => _showQrCodeModal(username, bioUrl),
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded, color: Color(0xFF007AFF)),
            tooltip: 'Share Bio Link',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: bioUrl));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bio Link copied to clipboard!')));
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded, color: Color(0xFF007AFF)),
            tooltip: 'Add Link',
            onPressed: () => _showAddLinkSheet(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Analytics Summary Header Card
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA)),
            ),
            child: Row(
              children: [
                Expanded(child: _analyticStat('Total Clicks', '$totalClicks', Icons.touch_app_rounded, const Color(0xFF007AFF))),
                Container(height: 24, width: 1, color: textSecondary?.withValues(alpha: 0.3)),
                Expanded(child: _analyticStat('Active Links', '${_links.where((l) => l.isActive).length}', Icons.link_rounded, const Color(0xFF34C759))),
                Container(height: 24, width: 1, color: textSecondary?.withValues(alpha: 0.3)),
                Expanded(child: _analyticStat('Theme', _selectedTheme.name, Icons.palette_rounded, const Color(0xFFAF52DE))),
              ],
            ),
          ),

          // Tabs Navigation
          TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF007AFF),
            unselectedLabelColor: textSecondary,
            indicatorColor: const Color(0xFF007AFF),
            tabs: const [
              Tab(text: 'Editor'),
              Tab(text: 'Live Preview 📱'),
              Tab(text: 'Themes'),
            ],
          ),

          // Tab Content Body
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: Editor & Link Management
                ReorderableListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _links.length,
                  onReorder: (oldIdx, newIdx) {
                    setState(() {
                      if (newIdx > oldIdx) newIdx -= 1;
                      final item = _links.removeAt(oldIdx);
                      _links.insert(newIdx, item);
                    });
                  },
                  itemBuilder: (ctx, idx) {
                    final link = _links[idx];
                    return Container(
                      key: ValueKey(link.id),
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: link.isActive ? Colors.transparent : Colors.grey.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.drag_indicator_rounded, color: textSecondary, size: 20),
                          const SizedBox(width: 8),
                          Text(link.icon, style: const TextStyle(fontSize: 22)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        link.title,
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textPrimary),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (link.type == LinkType.product && link.price != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF34C759).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '${link.currencySymbol}${link.price}',
                                          style: const TextStyle(color: Color(0xFF34C759), fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                  ],
                                ),
                                Text(link.url, style: TextStyle(fontSize: 11, color: textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.touch_app_rounded, size: 12, color: Color(0xFF007AFF)),
                                    const SizedBox(width: 4),
                                    Text('${link.clickCount} clicks', style: const TextStyle(fontSize: 11, color: Color(0xFF007AFF), fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: link.isActive,
                            onChanged: (val) => setState(() => link.isActive = val),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            onPressed: () => _showAddLinkSheet(link),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                            onPressed: () => setState(() => _links.removeAt(idx)),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // TAB 2: Interactive Live Preview Hub (Smartphone Frame)
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Container(
                      width: 320,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _selectedTheme.bgGradient,
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(36),
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.4), width: 6),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 20, spreadRadius: 4)],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Top iPhone Speaker Notch
                          Container(width: 60, height: 5, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(3))),
                          const SizedBox(height: 16),

                          // Profile Avatar
                          CircleAvatar(
                            radius: 36,
                            backgroundColor: Colors.white,
                            child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'C', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: _selectedTheme.accent)),
                          ),
                          const SizedBox(height: 10),
                          Text(name, style: TextStyle(color: _selectedTheme.textPrimary, fontWeight: FontWeight.w900, fontSize: 18)),
                          Text('@$username', style: TextStyle(color: _selectedTheme.textSecondary, fontSize: 13)),
                          const SizedBox(height: 6),
                          Text(_bioDescCtrl.text, style: TextStyle(color: _selectedTheme.textSecondary, fontSize: 12), textAlign: TextAlign.center),
                          const SizedBox(height: 20),

                          // Links & Product Cards
                          ..._links.where((l) => l.isActive).map((link) {
                            BorderRadius borderRadius;
                            if (_buttonStyle == 'Pill') {
                              borderRadius = BorderRadius.circular(24);
                            } else if (_buttonStyle == 'Sharp') {
                              borderRadius = BorderRadius.circular(4);
                            } else {
                              borderRadius = BorderRadius.circular(14);
                            }

                            return GestureDetector(
                              onTap: () {
                                setState(() => link.clickCount += 1);
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Clicked ${link.title}')));
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: _selectedTheme.cardBg,
                                  borderRadius: borderRadius,
                                  border: _selectedTheme.isGlass ? Border.all(color: Colors.white.withValues(alpha: 0.2)) : null,
                                ),
                                child: Row(
                                  children: [
                                    Text(link.icon, style: const TextStyle(fontSize: 18)),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        link.title,
                                        style: TextStyle(color: _selectedTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (link.type == LinkType.product && link.price != null) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _selectedTheme.accent,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          'Buy ${link.currencySymbol}${link.price}',
                                          style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w900),
                                        ),
                                      ),
                                    ] else
                                      Icon(Icons.arrow_forward_ios_rounded, color: _selectedTheme.textSecondary, size: 12),
                                  ],
                                ),
                              ),
                            );
                          }),

                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.lock_outline_rounded, color: _selectedTheme.textSecondary, size: 12),
                              const SizedBox(width: 4),
                              Text('Protected by MurihSpace Escrow', style: TextStyle(color: _selectedTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // TAB 3: Themes & Styling Customization
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text('THEME PRESETS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary)),
                    const SizedBox(height: 10),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 2.2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: BIO_THEMES.length,
                      itemBuilder: (ctx, idx) {
                        final theme = BIO_THEMES[idx];
                        final isSelected = _selectedTheme.name == theme.name;
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            setState(() => _selectedThemeRaw = theme);
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Bio Theme set to ${theme.name} ✨'),
                                duration: const Duration(milliseconds: 1200),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: theme.bgGradient),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: isSelected ? const Color(0xFF007AFF) : Colors.transparent, width: 2.5),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(theme.name, style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
                                      Text(theme.isGlass ? 'Glassmorphism' : 'Solid Design', style: TextStyle(color: theme.textSecondary, fontSize: 10)),
                                    ],
                                  ),
                                ),
                                if (isSelected) const Icon(Icons.check_circle_rounded, color: Color(0xFF007AFF), size: 18),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),

                    Text('BUTTON SHAPE STYLE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary)),
                    const SizedBox(height: 10),
                    Row(
                      children: ['Pill', 'Rounded', 'Sharp'].map((shape) {
                        final isSelected = _buttonStyle == shape;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: ChoiceChip(
                              label: Text(shape),
                              selected: isSelected,
                              onSelected: (_) => setState(() => _buttonStyle = shape),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    Text('BIO HEADLINE & DESCRIPTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _bioDescCtrl,
                      maxLines: 2,
                      style: TextStyle(color: textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Headline Bio Description',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF007AFF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link in Bio theme & studio customizations saved!')));
                        },
                        icon: const Icon(Icons.save_rounded),
                        label: const Text('Save Studio Customizations', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _analyticStat(String label, String value, IconData icon, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                value,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
