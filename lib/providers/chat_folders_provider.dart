import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChatFolder {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final String description;
  final bool isDefault;
  final List<String> includedCategories; // 'dms', 'groups', 'communities', 'vendors'

  ChatFolder({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.description,
    this.isDefault = false,
    this.includedCategories = const ['dms'],
  });
}

class ChatFoldersState {
  final List<ChatFolder> folders;
  final String activeFolderId;

  ChatFoldersState({
    required this.folders,
    this.activeFolderId = 'folder_all',
  });

  ChatFoldersState copyWith({
    List<ChatFolder>? folders,
    String? activeFolderId,
  }) {
    return ChatFoldersState(
      folders: folders ?? this.folders,
      activeFolderId: activeFolderId ?? this.activeFolderId,
    );
  }
}

class ChatFoldersNotifier extends Notifier<ChatFoldersState> {
  @override
  ChatFoldersState build() {
    return ChatFoldersState(
      folders: [
        ChatFolder(
          id: 'folder_all',
          name: 'All Chats',
          icon: Icons.all_inbox_rounded,
          color: const Color(0xFF007AFF),
          description: 'Includes all direct & group conversations',
          isDefault: true,
          includedCategories: ['dms', 'groups', 'communities', 'vendors'],
        ),
        ChatFolder(
          id: 'folder_dms',
          name: 'Direct Messages',
          icon: Icons.person_rounded,
          color: const Color(0xFF34C759),
          description: 'Only private 1-on-1 chats',
          isDefault: true,
          includedCategories: ['dms'],
        ),
        ChatFolder(
          id: 'folder_comm',
          name: 'Communities',
          icon: Icons.groups_rounded,
          color: const Color(0xFFFF9500),
          description: 'Public channels and community spaces',
          isDefault: true,
          includedCategories: ['communities'],
        ),
        ChatFolder(
          id: 'folder_vendors',
          name: 'Vendor & Orders',
          icon: Icons.storefront_rounded,
          color: const Color(0xFF5856D6),
          description: 'Marketplace orders and vendor conversations',
          isDefault: false,
          includedCategories: ['vendors'],
        ),
      ],
    );
  }

  void setActiveFolder(String folderId) {
    state = state.copyWith(activeFolderId: folderId);
  }

  void addCustomFolder({
    required String name,
    required IconData icon,
    required Color color,
    required List<String> categories,
  }) {
    final newFolder = ChatFolder(
      id: 'folder_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      icon: icon,
      color: color,
      description: 'Custom chat folder filter',
      isDefault: false,
      includedCategories: categories,
    );
    state = state.copyWith(folders: [...state.folders, newFolder]);
  }

  void deleteFolder(String id) {
    state = state.copyWith(
      folders: state.folders.where((f) => f.id != id || f.isDefault).toList(),
    );
  }
}

final chatFoldersProvider = NotifierProvider<ChatFoldersNotifier, ChatFoldersState>(ChatFoldersNotifier.new);
