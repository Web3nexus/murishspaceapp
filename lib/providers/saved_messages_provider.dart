import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'mediaUrl': mediaUrl,
        'timestamp': timestamp.toIso8601String(),
        'isPinned': isPinned,
        'category': category,
      };

  factory SavedMessageItem.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      return SavedMessageItem(
        id: 'saved_${DateTime.now().millisecondsSinceEpoch}',
        content: '',
        timestamp: DateTime.now(),
      );
    }
    return SavedMessageItem(
      id: json['id']?.toString() ?? 'saved_${DateTime.now().millisecondsSinceEpoch}',
      content: json['content']?.toString() ?? '',
      mediaUrl: json['mediaUrl']?.toString() ?? json['media_url']?.toString(),
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isPinned: (json['isPinned'] as bool?) ?? (json['is_pinned'] as bool?) ?? false,
      category: json['category']?.toString() ?? 'notes',
    );
  }
}

class SavedMessagesState {
  final List<SavedMessageItem>? _items;
  final String? _searchQuery;
  final String? _selectedCategory;
  final bool loading;

  List<SavedMessageItem> get items => _items ?? const [];
  String get searchQuery => _searchQuery ?? '';
  String get selectedCategory => _selectedCategory ?? 'all';

  SavedMessagesState({
    List<SavedMessageItem>? items,
    String? searchQuery = '',
    String? selectedCategory = 'all',
    this.loading = false,
  })  : _items = items,
        _searchQuery = searchQuery,
        _selectedCategory = selectedCategory;

  List<SavedMessageItem> get filteredItems {
    var result = items;
    final cat = selectedCategory;
    if (cat == 'pinned') {
      result = result.where((i) => i.isPinned).toList();
    } else if (cat != 'all') {
      result = result.where((i) => i.category == cat).toList();
    }
    final q = searchQuery.trim();
    if (q.isNotEmpty) {
      final query = q.toLowerCase();
      result = result.where((i) => i.content.toLowerCase().contains(query)).toList();
    }
    final sorted = List<SavedMessageItem>.from(result);
    sorted.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return b.timestamp.compareTo(a.timestamp);
    });
    return sorted;
  }

  SavedMessagesState copyWith({
    List<SavedMessageItem>? items,
    String? searchQuery,
    String? selectedCategory,
    bool? loading,
  }) {
    return SavedMessagesState(
      items: items ?? this.items,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      loading: loading ?? this.loading,
    );
  }
}

class SavedMessagesNotifier extends Notifier<SavedMessagesState> {
  static const String _storageKey = 'murihspace_saved_messages_v3';

  @override
  SavedMessagesState build() {
    _loadFromStorage();
    return SavedMessagesState(items: [], loading: true);
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List;
        final loaded = decoded
            .map((e) => SavedMessageItem.fromJson(e))
            .where((item) => item.content.isNotEmpty)
            .toList();
        if (loaded.isNotEmpty) {
          state = state.copyWith(items: loaded, loading: false);
          return;
        }
      }
    } catch (_) {}

    // First time defaults: sample initial welcome note
    final defaultItem = SavedMessageItem(
      id: 'saved_welcome',
      content: '📌 Welcome to your Saved Messages & Notes!\n\nUse this personal vault to bookmark important links, store Escrow transfer notes, code snippets, or ideas. Your data is stored safely on your device.',
      timestamp: DateTime.now(),
      isPinned: true,
      category: 'notes',
    );
    state = state.copyWith(items: [defaultItem], loading: false);
    _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(state.items.map((e) => e.toJson()).toList());
      await prefs.setString(_storageKey, encoded);
    } catch (_) {}
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
    _persist();
  }

  void deleteMessage(String id) {
    state = state.copyWith(items: state.items.where((item) => item.id != id).toList());
    _persist();
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
    _persist();
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setSelectedCategory(String category) {
    state = state.copyWith(selectedCategory: category);
  }
}

final savedMessagesProvider =
    NotifierProvider<SavedMessagesNotifier, SavedMessagesState>(SavedMessagesNotifier.new);
