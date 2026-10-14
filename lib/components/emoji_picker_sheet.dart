import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/design_tokens.dart';
import '../core/emoji_assets.dart';
import '../core/emoji_manifest.g.dart';

/// Persists the most recently selected emojis on-device so the picker can
/// surface a personalised "Recent" tab without any extra server round-trip.
class EmojiRecents {
  EmojiRecents._();

  static const String _key = 'emoji_recents_v1';
  static const int _max = 28;

  static List<String>? _cache;

  static Future<List<String>> _ensure() async {
    if (_cache != null) return _cache!;
    final prefs = await SharedPreferences.getInstance();
    _cache = prefs.getStringList(_key) ?? const [];
    return _cache!;
  }

  static Future<List<String>> load() async =>
      List<String>.unmodifiable(await _ensure());

  static Future<void> markUsed(String emoji) async {
    final list = await _ensure();
    final next = [emoji, ...list.where((e) => e != emoji)].take(_max).toList();
    _cache = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, next);
  }
}

/// Ordered, library-backed categories. Every folder exists in the animated
/// emoji manifest so a tab can never render as an empty grid.
class _EmojiCategory {
  const _EmojiCategory(this.folder, this.label, this.rep);

  final String folder;
  final String label;
  final String rep;
}

const List<_EmojiCategory> _kCategories = [
  _EmojiCategory('Smileys', 'Smileys', '😀'),
  _EmojiCategory('People', 'Gestures', '👍'),
  _EmojiCategory('Animals and Nature', 'Animals', '🐶'),
  _EmojiCategory('Food and Drink', 'Food', '🍕'),
  _EmojiCategory('Activity', 'Activities', '⚽'),
  _EmojiCategory('Travel and Places', 'Travel', '🚀'),
  _EmojiCategory('Objects', 'Objects', '💡'),
  _EmojiCategory('Symbols', 'Symbols', '❤️'),
  _EmojiCategory('Flags', 'Flags', '🚩'),
];

/// Maps an emoji to the human-readable words in its animated asset filename,
/// e.g. '🤝' -> ['handshake', 'deal', 'agree'], used for keyword search.
final Map<String, List<String>> _searchIndex = _buildSearchIndex();

Map<String, List<String>> _buildSearchIndex() {
  final index = <String, List<String>>{};
  for (final entry in kEmojiManifest.entries) {
    final name = entry.value
        .substring(entry.value.lastIndexOf('/') + 1)
        .replaceAll('.webp', '');
    index[entry.key] = name
        .toLowerCase()
        .split(RegExp('[^a-z0-9]+'))
        .where((w) => w.isNotEmpty)
        .toList();
  }
  return index;
}

/// Inline emoji panel that lives *inside* the composer (never a modal bottom
/// sheet), so the message input stays visible and reachable while it is open.
class EmojiPickerPanel extends StatefulWidget {
  final ValueChanged<String> onEmojiSelected;
  final VoidCallback? onBackspace;
  final double height;

  const EmojiPickerPanel({
    super.key,
    required this.onEmojiSelected,
    this.onBackspace,
    this.height = 248,
  });

  @override
  State<EmojiPickerPanel> createState() => _EmojiPickerPanelState();
}

class _EmojiPickerPanelState extends State<EmojiPickerPanel> {
  static const int _recentTab = 0;

  int _tab = _recentTab;
  String _query = '';
  List<String> _recents = const [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRecents();
    _warm(_emojisForFolder(_kCategories.first.folder));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Warms the on-disk cache for the emojis the user is about to see so the
  /// animated assets paint immediately instead of streaming in.
  void _warm(List<String> emojis) {
    if (emojis.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) precacheEmojiAssets(context, emojis.take(80));
    });
  }

  Future<void> _loadRecents() async {
    final list = await EmojiRecents.load();
    if (!mounted) return;
    setState(() => _recents = list);
    if (_tab == _recentTab) _warm(list);
  }

  Future<void> _pick(String emoji) async {
    widget.onEmojiSelected(emoji);
    await EmojiRecents.markUsed(emoji);
    final list = await EmojiRecents.load();
    if (mounted) setState(() => _recents = list);
  }

  List<String> _searchResults() {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return const [];
    final words = query.split(RegExp(r'\s+'));
    final results = <String>[];
    for (final entry in kEmojiManifest.entries) {
      if (results.length >= 120) break;
      final haystack =
          '${entry.key} ${_searchIndex[entry.key]?.join(' ')} ${entry.value.toLowerCase()}';
      if (words.every((w) => haystack.contains(w))) results.add(entry.key);
    }
    return results;
  }

  List<String> _emojisForFolder(String folder) => kEmojiManifest.entries
      .where((e) => e.value.startsWith('$folder/'))
      .map((e) => e.key)
      .toList();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF181A20) : Colors.white;
    final fieldBg = isDark ? const Color(0xFF222630) : const Color(0xFFF1F5F9);

    return Container(
      color: bg,
      height: widget.height,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
            child: _searchField(isDark, fieldBg),
          ),
          _categoryRow(isDark),
          Expanded(child: _grid(isDark)),
        ],
      ),
    );
  }

  Widget _searchField(bool isDark, Color fieldBg) {
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: fieldBg,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: _query.isEmpty
              ? (isDark ? const Color(0xFF323846) : const Color(0xFFE2E8F0))
              : DesignTokens.primary.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 10),
          Icon(
            Icons.search_rounded,
            size: 16,
            color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF61758A),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onChanged: (v) {
                setState(() => _query = v);
                if (v.trim().length >= 2) _warm(_searchResults());
              },
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white : Colors.black,
              ),
              decoration: InputDecoration(
                filled: false,
                hintText: 'Search emoji…',
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? const Color(0xFF8E8E93)
                      : const Color(0xFF8E8E93),
                ),
              ),
            ),
          ),
          if (_query.isNotEmpty)
            IconButton(
              onPressed: () {
                _searchController.clear();
                setState(() => _query = '');
              },
              icon: Icon(
                Icons.cancel_rounded,
                size: 16,
                color: isDark
                    ? const Color(0xFF8E8E93)
                    : const Color(0xFF61758A),
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          if (widget.onBackspace != null) ...[
            const SizedBox(width: 2),
            IconButton(
              onPressed: widget.onBackspace,
              icon: Icon(
                Icons.backspace_outlined,
                size: 18,
                color: isDark
                    ? const Color(0xFF8E8E93)
                    : const Color(0xFF61758A),
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              tooltip: 'Backspace',
            ),
          ],
          const SizedBox(width: 6),
        ],
      ),
    );
  }

  Widget _categoryRow(bool isDark) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        itemCount: _kCategories.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 4),
        itemBuilder: (context, index) {
          final selected = _tab == index;
          final isRecent = index == _recentTab;
          final label = isRecent ? 'Recent' : _kCategories[index - 1].label;

          return GestureDetector(
            onTap: () {
              setState(() => _tab = index);
              _warm(
                isRecent
                    ? _recents
                    : _emojisForFolder(_kCategories[index - 1].folder),
              );
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: selected
                    ? DesignTokens.primary.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isRecent)
                    Icon(
                      Icons.history_rounded,
                      size: 15,
                      color: selected
                          ? DesignTokens.primary
                          : (isDark
                                ? const Color(0xFF8E8E93)
                                : const Color(0xFF61758A)),
                    )
                  else
                    AnimatedEmoji(emoji: _kCategories[index - 1].rep, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected
                          ? DesignTokens.primary
                          : (isDark ? Colors.white60 : Colors.black54),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _grid(bool isDark) {
    final searching = _query.trim().isNotEmpty;
    final List<String> items;
    if (searching) {
      items = _searchResults();
    } else if (_tab == _recentTab) {
      items = _recents;
    } else {
      items = _emojisForFolder(_kCategories[_tab - 1].folder);
    }

    final empty = items.isEmpty;
    final emptyLabel = searching
        ? 'No emojis found for "$_query"'
        : _tab == _recentTab
        ? 'Emojis you use will appear here'
        : 'No emojis in this category';

    if (empty) {
      return Center(
        child: Text(
          emptyLabel,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = (constraints.maxWidth / 46).floor().clamp(6, 10);
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final emoji = items[index];
            return InkWell(
              onTap: () => _pick(emoji),
              borderRadius: BorderRadius.circular(9),
              splashColor: DesignTokens.primary.withValues(alpha: 0.18),
              highlightColor: DesignTokens.primary.withValues(alpha: 0.08),
              child: Center(child: AnimatedEmoji(emoji: emoji, size: 26)),
            );
          },
        );
      },
    );
  }
}
