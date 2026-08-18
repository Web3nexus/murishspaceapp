import 'package:flutter_riverpod/flutter_riverpod.dart';

class SavedMessageItem {
  final String id;
  final String content;
  final String? mediaUrl;
  final DateTime timestamp;
  final bool isPinned;
  final String category; // 'notes', 'links', 'media', 'code'

  SavedMessageItem({
    required this.id,
    required this.content,
    this.mediaUrl,
    required this.timestamp,
    this.isPinned = false,
    this.category = 'notes',
  });

  SavedMessageItem copyWith({
    String? content,
    String? mediaUrl,
    DateTime? timestamp,
    bool? isPinned,
    String? category,
  }) {
    return SavedMessageItem(
      id: id,
      content: content ?? this.content,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      timestamp: timestamp ?? this.timestamp,
      isPinned: isPinned ?? this.isPinned,
      category: category ?? this.category,
    );
  }
}

class SavedMessagesState {
  final List<SavedMessageItem> items;
  final String searchQuery;

  SavedMessagesState({
    required this.items,
    this.searchQuery = '',
  });

  List<SavedMessageItem> get filteredItems {
    if (searchQuery.trim().isEmpty) return items;
    final query = searchQuery.toLowerCase();
    return items.where((i) => i.content.toLowerCase().contains(query)).toList();
  }

  SavedMessagesState copyWith({
    List<SavedMessageItem>? items,
    String? searchQuery,
  }) {
    return SavedMessagesState(
      items: items ?? this.items,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class SavedMessagesNotifier extends Notifier<SavedMessagesState> {
  @override
  SavedMessagesState build() {
    return SavedMessagesState(
      items: [
        SavedMessageItem(
          id: 'saved_1',
          content: 'MurihSpace Escrow Deposit PIN: Remember 4-digit code for transactions.',
          timestamp: DateTime.now().subtract(const Duration(hours: 2)),
          isPinned: true,
          category: 'notes',
        ),
        SavedMessageItem(
          id: 'saved_2',
          content: 'Useful Creator Sponsorship link: https://murihspace.com/brand-deals/guide',
          timestamp: DateTime.now().subtract(const Duration(days: 1)),
          category: 'links',
        ),
        SavedMessageItem(
          id: 'saved_3',
          content: 'Vendor product list ideas: Wireless noise-canceling headphones & Mechanical Keyboards.',
          timestamp: DateTime.now().subtract(const Duration(days: 3)),
          category: 'notes',
        ),
      ],
    );
  }

  void saveMessage(String text, {String? mediaUrl, String category = 'notes'}) {
    final newItem = SavedMessageItem(
      id: 'saved_${DateTime.now().millisecondsSinceEpoch}',
      content: text.trim(),
      mediaUrl: mediaUrl,
      timestamp: DateTime.now(),
      category: category,
    );
    state = state.copyWith(items: [newItem, ...state.items]);
  }

  void deleteMessage(String id) {
    state = state.copyWith(items: state.items.where((item) => item.id != id).toList());
  }

  void togglePin(String id) {
    state = state.copyWith(
      items: state.items.map((item) {
        if (item.id == id) {
          return item.copyWith(isPinned: !item.isPinned);
        }
        return item;
      }).toList(),
    );
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }
}

final savedMessagesProvider = NotifierProvider<SavedMessagesNotifier, SavedMessagesState>(SavedMessagesNotifier.new);
