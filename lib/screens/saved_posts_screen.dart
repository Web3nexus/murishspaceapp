import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/saved_messages_provider.dart';

/// Saved Messages, Notes & Bookmarks collection screen connected to savedMessagesProvider.
class SavedPostsScreen extends ConsumerStatefulWidget {
  const SavedPostsScreen({super.key});

  @override
  ConsumerState<SavedPostsScreen> createState() => _SavedPostsScreenState();
}

class _SavedPostsScreenState extends ConsumerState<SavedPostsScreen> {
  final _inputCtrl = TextEditingController();

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  void _addNote() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    ref.read(savedMessagesProvider.notifier).saveMessage(text);
    _inputCtrl.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(savedMessagesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : const Color(0xFFEFF1F5);
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Saved Messages & Notes',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              onChanged: (val) => ref.read(savedMessagesProvider.notifier).setSearchQuery(val),
              style: TextStyle(color: textPrimary),
              decoration: InputDecoration(
                hintText: 'Search saved messages…',
                prefixIcon: const Icon(Icons.search_rounded),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                fillColor: cardBg,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Messages List
          Expanded(
            child: state.filteredItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bookmark_outline_rounded, size: 54, color: textSecondary),
                        const SizedBox(height: 10),
                        Text('No Saved Messages Yet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textPrimary)),
                        const SizedBox(height: 4),
                        Text('Save important notes, links, or messages to yourself here.', style: TextStyle(color: textSecondary, fontSize: 13)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.filteredItems.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final item = state.filteredItems[i];
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: item.isPinned
                              ? Border.all(color: const Color(0xFFFF9500), width: 1.5)
                              : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (item.isPinned) ...[
                                  const Icon(Icons.push_pin_rounded, color: Color(0xFFFF9500), size: 16),
                                  const SizedBox(width: 6),
                                ],
                                Text(
                                  item.category.toUpperCase(),
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF007AFF)),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: Icon(
                                    item.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                                    size: 18,
                                    color: item.isPinned ? const Color(0xFFFF9500) : textSecondary,
                                  ),
                                  onPressed: () => ref.read(savedMessagesProvider.notifier).togglePin(item.id),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete_outline_rounded, size: 18, color: textSecondary),
                                  onPressed: () => ref.read(savedMessagesProvider.notifier).deleteMessage(item.id),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.content,
                              style: TextStyle(fontSize: 14, color: textPrimary, height: 1.4),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Saved ${item.timestamp.hour}:${item.timestamp.minute.toString().padLeft(2, '0')}',
                                  style: TextStyle(fontSize: 11, color: textSecondary),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Clipboard.setData(ClipboardData(text: item.content));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Copied to clipboard!')),
                                    );
                                  },
                                  child: const Text('Copy Text', style: TextStyle(fontSize: 11, color: Color(0xFF007AFF), fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Bottom Input Composer
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: cardBg,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputCtrl,
                      style: TextStyle(color: textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'Save a note or message to self…',
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _addNote(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send_rounded, color: Color(0xFF007AFF)),
                    onPressed: _addNote,
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
