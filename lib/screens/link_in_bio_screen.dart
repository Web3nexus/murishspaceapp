import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';

class LinkItem {
  final int id;
  String title;
  String url;
  String icon;
  bool isActive;
  int clickCount;

  LinkItem({
    required this.id,
    required this.title,
    required this.url,
    this.icon = '🔗',
    this.isActive = true,
    this.clickCount = 0,
  });
}

/// Link in Bio Builder & Live Preview Hub for Creators & Vendors.
class LinkInBioScreen extends ConsumerStatefulWidget {
  const LinkInBioScreen({super.key});

  @override
  ConsumerState<LinkInBioScreen> createState() => _LinkInBioScreenState();
}

class _LinkInBioScreenState extends ConsumerState<LinkInBioScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _bioTitleCtrl = TextEditingController(text: 'Official Creator & Storefront Hub ✨');
  final _bioDescCtrl = TextEditingController(text: 'Shop products, book coaching sessions, and explore latest content.');
  String _selectedTheme = 'Midnight Dark';
  Color _themeColor = const Color(0xFF007AFF);

  final List<LinkItem> _links = [
    LinkItem(id: 1, title: '🛍️ Shop My Vendor Store', url: 'https://murihspace.com/store/vendor-hub', icon: '🛍️', clickCount: 1420),
    LinkItem(id: 2, title: '🎥 Watch Latest YouTube Review', url: 'https://youtube.com/@creator', icon: '🎥', clickCount: 890),
    LinkItem(id: 3, title: '📅 Book 1-on-1 Strategy Session', url: 'https://murihspace.com/coaching', icon: '📅', clickCount: 450),
    LinkItem(id: 4, title: '📜 View Ambassador Media Kit', url: 'https://murihspace.com/media-kit', icon: '📜', clickCount: 310),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(existing == null ? 'Add Link to Bio' : 'Edit Link', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 14),
            TextField(controller: titleCtrl, decoration: InputDecoration(labelText: 'Link Title', hintText: 'e.g. My Online Store', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)))),
            const SizedBox(height: 10),
            TextField(controller: urlCtrl, keyboardType: TextInputType.url, decoration: InputDecoration(labelText: 'Destination URL', hintText: 'https://...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)))),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF007AFF), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                onPressed: () {
                  final t = titleCtrl.text.trim();
                  final u = urlCtrl.text.trim();
                  if (t.isEmpty || u.isEmpty) return;

                  setState(() {
                    if (existing != null) {
                      existing.title = t;
                      existing.url = u;
                    } else {
                      _links.add(LinkItem(id: DateTime.now().millisecondsSinceEpoch, title: t, url: u));
                    }
                  });
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(existing == null ? 'Link added to Bio!' : 'Link updated!')));
                },
                child: Text(existing == null ? 'Add Link' : 'Save Changes', style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
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

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Link in Bio Builder', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w800, fontSize: 18)),
            Text('murihspace.com/bio/@$username', style: const TextStyle(color: Color(0xFF007AFF), fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, color: Color(0xFF007AFF)),
            tooltip: 'Share Bio Link',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: bioUrl));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bio Link URL copied to clipboard!')));
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
          // Live Mini Preview Card Header
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [_themeColor, _themeColor.withValues(alpha: 0.7)]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: _themeColor.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white,
                  child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _themeColor)),
                ),
                const SizedBox(height: 6),
                Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                Text('@$username', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 4),
                Text(_bioDescCtrl.text, style: const TextStyle(color: Colors.white90, fontSize: 11), textAlign: TextAlign.center, maxLines: 2),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bar_chart_rounded, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text('${_links.fold<int>(0, (sum, l) => sum + l.clickCount)} Total Clicks', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
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
              Tab(text: 'Links & Analytics'),
              Tab(text: 'Theme & Customization'),
            ],
          ),

          // Tab Body
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Links & Analytics
                ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _links.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (ctx, idx) {
                    final link = _links[idx];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: link.isActive ? Colors.transparent : Colors.grey.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Text(link.icon, style: const TextStyle(fontSize: 22)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(link.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textPrimary)),
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
                            activeColor: const Color(0xFF007AFF),
                            onChanged: (val) => setState(() => link.isActive = val),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            onPressed: () => _showAddLinkSheet(link),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // Tab 2: Theme & Design Customization
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text('THEME COLOR ACCENT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _colorBtn(const Color(0xFF007AFF), 'Cyber Blue'),
                        _colorBtn(const Color(0xFF5856D6), 'Purple Neon'),
                        _colorBtn(const Color(0xFFFF9500), 'Sunset Gold'),
                        _colorBtn(const Color(0xFF34C759), 'Emerald Mint'),
                        _colorBtn(const Color(0xFFFF3B30), 'Crimson Red'),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text('BIO DETAILS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _bioDescCtrl,
                      maxLines: 2,
                      style: TextStyle(color: textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Headline Bio',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF007AFF), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link in Bio theme & settings saved!')));
                        },
                        icon: const Icon(Icons.save_rounded),
                        label: const Text('Save Bio Customizations', style: TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _colorBtn(Color color, String name) {
    final isSelected = _themeColor.value == color.value;
    return GestureDetector(
      onTap: () => setState(() {
        _themeColor = color;
        _selectedTheme = name;
      }),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
          boxShadow: [if (isSelected) BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8)],
        ),
        child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
      ),
    );
  }
}
