import 'package:flutter/material.dart';
import '../config/design_tokens.dart';

class EmojiPickerSheet extends StatefulWidget {
  final ValueChanged<String> onEmojiSelected;
  final VoidCallback? onBackspace;

  const EmojiPickerSheet({
    super.key,
    required this.onEmojiSelected,
    this.onBackspace,
  });

  static void show(BuildContext context, {
    required ValueChanged<String> onEmojiSelected,
    VoidCallback? onBackspace,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EmojiPickerSheet(
        onEmojiSelected: onEmojiSelected,
        onBackspace: onBackspace,
      ),
    );
  }

  @override
  State<EmojiPickerSheet> createState() => _EmojiPickerSheetState();
}

class _EmojiPickerSheetState extends State<EmojiPickerSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const Map<String, List<String>> _categories = {
    'Smileys': [
      '😀', '😃', '😄', '😁', '😆', '😅', '🤣', '😂', '🙂', '🙃',
      '😉', '😊', '😇', '🥰', '😍', '🤩', '😘', '😗', '😚', '😙',
      '😋', '😛', '😜', '🤪', '😝', '🤑', '🤗', '🤭', '🤫', '🤔',
      '🤐', '🤨', '😐', '😑', '😶', '😏', '😒', '🙄', '😬', '🤥',
      '😌', '😔', '😪', '🤤', '😴', '😷', '🤒', '🤕', '🤢', '🤮',
      '🤧', '🥵', '🥶', '🥴', '😵', '🤯', '🤠', '🥳', '😎', '🤓',
      '🧐', '😕', '😟', '🙁', '😮', '😯', '😲', '😳', '🥺', '😦',
      '😧', '😨', '😰', '😥', '😢', '😭', '😱', '😖', '😣', '😞',
      '😓', '😩', '😫', '🥱', '😤', '😡', '😠', '🤬', '😈', '👿',
      '💀', '☠️', '💩', '🤡', '👹', '👺', '👻', '👽', '👾', '🤖',
    ],
    'Gestures': [
      '👋', '🤚', '🖐️', '✋', '🖖', '👌', '🤏', '✌️', '🤞', '🤟',
      '🤘', '🤙', '👈', '👉', '👆', '🖕', '👇', '☝️', '👍', '👎',
      '✊', '👊', '🤛', '🤜', '👏', '🙌', '👐', '🤲', '🤝', '🙏',
      '✍️', '💅', '🤳', '💪', '🦾', '🦿', '🦵', '🦶', '👂', '🦻',
      '👃', '🧠', '🫀', '🫁', '🦷', '🦴', '👀', '👁️', '👅', '👄',
    ],
    'Hearts': [
      '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍', '🤎', '💔',
      '❣️', '💕', '💞', '💓', '💗', '💖', '💘', '💝', '💟', '☮️',
      '🔥', '✨', '⚡', '💥', '⭐', '🌟', '💫', '🎉', '🎊', '🎈',
      '🎁', '🏆', '🥇', '🥈', '🥉', '🏅', '🎖️', '👑', '💎', '💯',
    ],
    'Animals': [
      '🐶', '🐱', '🐭', '🐹', '🐰', '🦊', '🐻', '🐼', '🐨', '🐯',
      '🦁', '🐮', '🐷', '🐽', '🐸', '🐵', '🙈', '🙉', '🙊', '🐒',
      '🐔', '🐧', '🐦', '🐤', '🐣', '🐥', '🦆', '🦅', '🦉', '🦇',
      '🐺', '🐗', '🐴', '🦄', '🐝', '🐛', '🦋', '🐌', '🐞', '🐜',
      '🐢', '🐍', '🦎', '🐙', '🦑', '🦐', '🦞', '🦀', '🐡', '🐠',
    ],
    'Food': [
      '🍏', '🍎', '🍐', '🍊', '🍋', '🍌', '🍉', '🍇', '🍓', '🫐',
      '🍈', '🍒', '🍑', '🥭', '🍍', '🥥', '🥝', '🍅', '🍆', '🥑',
      '🥦', '🥬', '🥒', '🌶️', '🫑', '🌽', '🥕', '🫒', '🧄', '🧅',
      '🥐', '🥯', '🍞', '🥖', '🥨', '🧀', '🍳', '🥞', '🧇', '🥓',
      '🍔', '🍟', '🍕', '🌭', '🥪', '🌮', '🌯', '🥗', '🍝', '🍜',
      '☕', '🍵', '🧃', '🥤', '🧋', '🍺', '🍻', '🍷', '🍸', '🍹',
    ],
    'Sports': [
      '⚽', '🏀', '🏈', '⚾', '🥎', '🎾', '🏐', '🏉', '🥏', '🎱',
      '🪀', '🏓', '🏸', '🏒', '🏑', '🥍', '🏏', '🪃', '🥅', '⛳',
      '🪁', '🏹', '🎣', '🤿', '🥊', '🥋', '🛹', '🛼', '🛷', '⛸️',
      '🎿', '⛷️', '🏂', '🪂', '🏋️', '🤼', '🤸', '🧗', '🏄', '🏊',
    ],
    'Objects': [
      '📱', '📲', '💻', '⌨️', '🖥️', '🖨️', '🖱️', '💽', '💾', '💿',
      '📀', '📷', '📸', '📹', '🎥', '📽️', '📞', '☎️', '📟', '📠',
      '📺', '📻', '🎙️', '🧭', '⏱️', '⏲️', '⏰', '🕰️', '⌛', '⏳',
      '💡', '🔦', '🏮', '💸', '💵', '🪙', '💰', '💳', '💎', '🚀',
    ],
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.keys.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E222A) : Colors.white;
    final tabBg = isDark ? const Color(0xFF282C35) : const Color(0xFFF2F4F7);

    return Container(
      height: 360,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8, bottom: 6),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Category tabs & backspace action
          Container(
            color: tabBg,
            child: Row(
              children: [
                Expanded(
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    indicatorColor: DesignTokens.primary,
                    indicatorWeight: 3,
                    labelColor: DesignTokens.primary,
                    unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
                    tabs: const [
                      Tab(text: '😀 Smileys'),
                      Tab(text: '👋 Gestures'),
                      Tab(text: '❤️ Hearts'),
                      Tab(text: '🐶 Animals'),
                      Tab(text: '🍔 Food'),
                      Tab(text: '⚽ Sports'),
                      Tab(text: '💡 Objects'),
                    ],
                  ),
                ),
                if (widget.onBackspace != null)
                  IconButton(
                    icon: const Icon(Icons.backspace_outlined, size: 20),
                    tooltip: 'Backspace',
                    onPressed: widget.onBackspace,
                  ),
              ],
            ),
          ),
          // Emoji grid
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _categories.values.map((emojis) {
                return GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: emojis.length,
                  itemBuilder: (context, index) {
                    final emoji = emojis[index];
                    return InkWell(
                      onTap: () => widget.onEmojiSelected(emoji),
                      borderRadius: BorderRadius.circular(10),
                      splashColor: DesignTokens.primary.withOpacity(0.2),
                      child: Center(
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 26),
                        ),
                      ),
                    );
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
