import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/chat_folders_provider.dart';

/// Telegram iOS style Chat Folders management screen connected to chatFoldersProvider.
class ChatFoldersScreen extends ConsumerWidget {
  const ChatFoldersScreen({super.key});

  void _showCreateFolderSheet(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    IconData selectedIcon = Icons.folder_rounded;
    Color selectedColor = const Color(0xFF007AFF);

    final icons = [
      Icons.folder_rounded,
      Icons.work_rounded,
      Icons.star_rounded,
      Icons.shopping_bag_rounded,
      Icons.favorite_rounded,
      Icons.attach_money_rounded,
      Icons.school_rounded,
      Icons.sports_esports_rounded,
    ];

    final colors = [
      const Color(0xFF007AFF),
      const Color(0xFF34C759),
      const Color(0xFFFF9500),
      const Color(0xFF5856D6),
      const Color(0xFFFF2D55),
      const Color(0xFFAF52DE),
    ];

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

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
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
                  Text('Create Custom Chat Folder', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textPrimary)),
                  const SizedBox(height: 14),
                  TextField(
                    controller: nameCtrl,
                    style: TextStyle(color: textPrimary),
                    decoration: InputDecoration(
                      prefixIcon: Icon(selectedIcon, color: selectedColor),
                      labelText: 'Folder Name',
                      hintText: 'e.g. Work, Family, VIP Vendors',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('Choose Folder Icon', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textPrimary)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: icons.map((ic) {
                      return InkWell(
                        onTap: () => setModalState(() => selectedIcon = ic),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: selectedIcon == ic ? selectedColor.withValues(alpha: 0.2) : Colors.transparent,
                            shape: BoxShape.circle,
                            border: selectedIcon == ic ? Border.all(color: selectedColor, width: 2) : null,
                          ),
                          child: Icon(ic, color: selectedIcon == ic ? selectedColor : Colors.grey),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  Text('Choose Folder Color', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textPrimary)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: colors.map((c) {
                      return InkWell(
                        onTap: () => setModalState(() => selectedColor = c),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: selectedColor == c ? Border.all(color: Colors.white, width: 2.5) : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selectedColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) return;

                        ref.read(chatFoldersProvider.notifier).addCustomFolder(
                              name: name,
                              icon: selectedIcon,
                              color: selectedColor,
                              categories: ['dms', 'groups'],
                            );

                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Folder "$name" created successfully!')),
                        );
                      },
                      child: const Text('Create Folder', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chatFoldersProvider);
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
        title: Text(
          'Chat Folders',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'MY CHAT FOLDERS (${state.folders.length})',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.folders.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 64),
              itemBuilder: (ctx, i) {
                final folder = state.folders[i];
                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: folder.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(folder.icon, color: folder.color, size: 22),
                  ),
                  title: Text(
                    folder.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    folder.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: textSecondary,
                    ),
                  ),
                  trailing: folder.isDefault
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('DEFAULT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                        )
                      : IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF3B30)),
                          onPressed: () {
                            ref.read(chatFoldersProvider.notifier).deleteFolder(folder.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Folder "${folder.name}" deleted.')),
                            );
                          },
                        ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              onTap: () => _showCreateFolderSheet(context, ref),
              leading: const Icon(Icons.add_circle_rounded, color: Color(0xFF007AFF)),
              title: const Text(
                'Create New Custom Folder',
                style: TextStyle(
                  color: Color(0xFF007AFF),
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
