import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/saved_messages_provider.dart';

/// Redesigned Telegram/iMessage-level Saved Messages, Vault & Personal Notes Hub.
class SavedPostsScreen extends ConsumerStatefulWidget {
  const SavedPostsScreen({super.key});

  @override
  ConsumerState<SavedPostsScreen> createState() => _SavedPostsScreenState();
}

class _SavedPostsScreenState extends ConsumerState<SavedPostsScreen> {
  final _inputCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  String _selectedCategory = 'notes';

  @override
  void dispose() {
    _inputCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _addNote() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    ref.read(savedMessagesProvider.notifier).saveMessage(text, category: _selectedCategory);
    _inputCtrl.clear();
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Note saved to personal vault!'),
        backgroundColor: Color(0xFF34C759),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Color _getCategoryColor(String? category) {
    final cat = (category ?? 'notes').toLowerCase();
    switch (cat) {
      case 'pinned':
        return const Color(0xFFFF9500);
      case 'links':
        return const Color(0xFF007AFF);
      case 'media':
        return const Color(0xFFAF52DE);
      case 'code':
        return const Color(0xFF34C759);
      case 'notes':
      default:
        return const Color(0xFFFF9500);
    }
  }

  IconData _getCategoryIcon(String? category) {
    final cat = (category ?? 'notes').toLowerCase();
    switch (cat) {
      case 'pinned':
        return Icons.push_pin_rounded;
      case 'links':
        return Icons.link_rounded;
      case 'media':
        return Icons.image_rounded;
      case 'code':
        return Icons.code_rounded;
      case 'notes':
      default:
        return Icons.note_alt_rounded;
    }
  }

  String _formatTimestamp(DateTime? dt) {
    if (dt == null) return 'Saved';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(savedMessagesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : const Color(0xFFEFF1F5);
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

    final categories = <Map<String, dynamic>>[
      {'id': 'all', 'label': 'All', 'icon': Icons.all_inbox_rounded},
      {'id': 'pinned', 'label': 'Pinned', 'icon': Icons.push_pin_rounded},
      {'id': 'notes', 'label': 'Notes', 'icon': Icons.note_alt_rounded},
      {'id': 'links', 'label': 'Links', 'icon': Icons.link_rounded},
      {'id': 'media', 'label': 'Media', 'icon': Icons.image_rounded},
      {'id': 'code', 'label': 'Code', 'icon': Icons.code_rounded},
    ];

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Saved Messages',
              style: TextStyle(
                color: textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 19,
              ),
            ),
            Text(
              '${state.items.length} notes · Personal encrypted vault',
              style: TextStyle(fontSize: 11, color: textSecondary, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_added_rounded, color: Color(0xFF007AFF)),
            tooltip: 'Vault Info',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Your Saved Messages are encrypted and stored on your device.')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Input Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (val) => ref.read(savedMessagesProvider.notifier).setSearchQuery(val),
                style: TextStyle(color: textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search saved messages & notes…',
                  hintStyle: TextStyle(fontSize: 13, color: textSecondary),
                  prefixIcon: Icon(Icons.search_rounded, color: textSecondary, size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  suffixIcon: state.searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear_rounded, color: textSecondary, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            ref.read(savedMessagesProvider.notifier).setSearchQuery('');
                          },
                        )
                      : null,
                ),
              ),
            ),
          ),

          // Category Filter Chips Bar
          SizedBox(
            height: 44,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final cat = categories[i];
                final catId = cat['id']?.toString() ?? 'all';
                final catLabel = cat['label']?.toString() ?? 'Category';
                final catIcon = cat['icon'] as IconData? ?? Icons.all_inbox_rounded;
                final isSelected = state.selectedCategory == catId;

                return ChoiceChip(
                  showCheckmark: false,
                  avatar: Icon(
                    catIcon,
                    size: 14,
                    color: isSelected ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[700]),
                  ),
                  label: Text(
                    catLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.white : (isDark ? Colors.grey[300] : Colors.grey[800]),
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: const Color(0xFF007AFF),
                  backgroundColor: cardBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected ? Colors.transparent : (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA)),
                    ),
                  ),
                  onSelected: (_) {
                    HapticFeedback.selectionClick();
                    ref.read(savedMessagesProvider.notifier).setSelectedCategory(catId);
                  },
                );
              },
            ),
          ),

          // Messages List View
          Expanded(
            child: state.filteredItems.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFF007AFF).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.bookmark_outline_rounded, size: 48, color: Color(0xFF007AFF)),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No Saved Messages Found',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: textPrimary),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Save notes, links, Escrow PINs, or code snippets here to access them anytime.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: textSecondary, fontSize: 13, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.filteredItems.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (ctx, i) {
                      final item = state.filteredItems[i];
                      final catColor = _getCategoryColor(item.category);
                      final catIcon = _getCategoryIcon(item.category);
                      final noteCategoryStr = item.category.toUpperCase();

                      return Container(
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(18),
                          border: item.isPinned
                              ? Border.all(color: const Color(0xFFFF9500), width: 1.5)
                              : Border.all(color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA), width: 0.8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Row
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 12, 8, 4),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: catColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(catIcon, size: 12, color: catColor),
                                        const SizedBox(width: 4),
                                        Text(
                                          noteCategoryStr,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                            color: catColor,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (item.isPinned) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF9500).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(Icons.push_pin_rounded, color: Color(0xFFFF9500), size: 11),
                                          SizedBox(width: 3),
                                          Text(
                                            'PINNED',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFFFF9500),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  const Spacer(),
                                  IconButton(
                                    icon: Icon(
                                      item.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                                      size: 18,
                                      color: item.isPinned ? const Color(0xFFFF9500) : textSecondary,
                                    ),
                                    tooltip: item.isPinned ? 'Unpin' : 'Pin to top',
                                    onPressed: () {
                                      HapticFeedback.lightImpact();
                                      ref.read(savedMessagesProvider.notifier).togglePin(item.id);
                                    },
                                  ),
                                  PopupMenuButton<String>(
                                    icon: Icon(Icons.more_vert_rounded, size: 18, color: textSecondary),
                                    onSelected: (action) {
                                      if (action == 'copy') {
                                        Clipboard.setData(ClipboardData(text: item.content));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Copied to clipboard!')),
                                        );
                                      } else if (action == 'delete') {
                                        ref.read(savedMessagesProvider.notifier).deleteMessage(item.id);
                                      }
                                    },
                                    itemBuilder: (ctx) => [
                                      const PopupMenuItem(
                                        value: 'copy',
                                        child: Row(
                                          children: [
                                            Icon(Icons.copy_rounded, size: 16),
                                            SizedBox(width: 8),
                                            Text('Copy Text'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('Delete', style: TextStyle(color: Colors.red)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Note Content
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                              child: SelectableText(
                                item.content,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: textPrimary,
                                  height: 1.45,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),

                            const SizedBox(height: 8),
                            const Divider(height: 1, indent: 14, endIndent: 14),

                            // Footer Row
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatTimestamp(item.timestamp),
                                    style: TextStyle(fontSize: 11, color: textSecondary),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      Clipboard.setData(ClipboardData(text: item.content));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Copied note text!'),
                                          duration: Duration(seconds: 1),
                                        ),
                                      );
                                    },
                                    child: const Row(
                                      children: [
                                        Icon(Icons.copy_rounded, size: 12, color: Color(0xFF007AFF)),
                                        SizedBox(width: 4),
                                        Text(
                                          'Copy',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF007AFF),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Bottom Interactive Composer Sheet
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: cardBg,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Category Selector Row
                  Row(
                    children: [
                      const Text(
                        'Type: ',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      const SizedBox(width: 4),
                      ...['notes', 'links', 'media', 'code'].map((cat) {
                        final isSel = _selectedCategory == cat;
                        final color = _getCategoryColor(cat);
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _selectedCategory = cat);
                              HapticFeedback.selectionClick();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isSel ? color : color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                cat.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isSel ? Colors.white : color,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Input Box Row
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: TextField(
                            controller: _inputCtrl,
                            maxLines: 3,
                            minLines: 1,
                            style: TextStyle(color: textPrimary, fontSize: 14),
                            decoration: const InputDecoration(
                              hintText: 'Save a note, code snippet, or link…',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 10),
                            ),
                            onSubmitted: (_) => _addNote(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF007AFF),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.send_rounded, size: 20),
                        onPressed: _addNote,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
