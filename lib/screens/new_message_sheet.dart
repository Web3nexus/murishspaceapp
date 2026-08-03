import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/api_client.dart';
import '../core/design_tokens.dart';
import '../models/chat_models.dart';
import '../providers/chat_provider.dart';

/// Opens a bottom sheet to search users and start a 1:1 conversation.
Future<void> showNewMessageSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _NewMessageSheet(),
  );
}

class _NewMessageSheet extends ConsumerStatefulWidget {
  const _NewMessageSheet();

  @override
  ConsumerState<_NewMessageSheet> createState() => _NewMessageSheetState();
}

class _NewMessageSheetState extends ConsumerState<_NewMessageSheet> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<ChatUser> _results = const [];
  bool _searching = false;
  bool _starting = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _results = const [];
        _searching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(value.trim()));
  }

  Future<void> _search(String query) async {
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final response = await ApiClient.instance.dio.get(
        '/search',
        queryParameters: {'q': query, 'type': 'users', 'per_page': 15},
      );
      final payload = ApiClient.instance.unwrap(response);
      final raw = payload is Map<String, dynamic> ? payload['users'] : payload;
      final users = raw is List
          ? raw
              .map(ChatUser.fromJson)
              .where((u) => u.id != 0 && u.name.isNotEmpty)
              .toList()
          : <ChatUser>[];
      if (!mounted) return;
      setState(() {
        _results = users;
        _searching = false;
      });
    } on DioException {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error = 'Search failed. Check your connection and try again.';
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error = 'Search failed.';
      });
    }
  }

  Future<void> _startChat(ChatUser user) async {
    setState(() => _starting = true);
    try {
      final response = await ApiClient.instance.dio.post('/conversations/direct', data: {
        'user_id': user.id,
      });
      final payload = ApiClient.instance.unwrap(response);
      final id = payload is Map<String, dynamic> ? (payload['id'] as num?)?.toInt() : null;
      if (id == null) throw ApiException(message: 'Could not start conversation.');
      final conversation = Conversation(
        id: id,
        type: 'direct',
        title: user.name,
        otherUser: user,
        updatedAt: DateTime.now(),
      );
      ref.read(conversationsProvider.notifier).upsert(conversation);
      if (!mounted) return;
      Navigator.of(context).pop();
      context.push('/app/conversation/$id');
    } catch (_) {
      if (!mounted) return;
      setState(() => _starting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not start this conversation.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.only(bottom: padding.bottom),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'New message',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: _onChanged,
                decoration: InputDecoration(
                  hintText: 'Search people by name or username',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: const Color(0xFFF2F5F8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13),
                ),
              ),
            SizedBox(
              height: 320,
              child: _buildResults(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_searching) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    }
    if (_results.isEmpty) {
      return Center(
        child: Text(
          _controller.text.trim().isEmpty ? 'Start typing to find people' : 'No people found',
          style: const TextStyle(color: DesignTokens.textSecondary),
        ),
      );
    }
    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
      itemBuilder: (_, i) {
        final user = _results[i];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: DesignTokens.primarySoft,
            backgroundImage: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                ? NetworkImage(user.avatarUrl!)
                : null,
            child: user.avatarUrl == null || user.avatarUrl!.isEmpty
                ? Text(
                    user.name.isNotEmpty ? user.name.substring(0, 1).toUpperCase() : '?',
                    style: const TextStyle(color: DesignTokens.primaryDark, fontWeight: FontWeight.w700),
                  )
                : null,
          ),
          title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('@${user.username}'),
          trailing: _starting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.arrow_forward_ios, size: 14, color: DesignTokens.textSecondary),
          onTap: _starting ? null : () => _startChat(user),
        );
      },
    );
  }
}
