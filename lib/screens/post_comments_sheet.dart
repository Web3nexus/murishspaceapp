import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/design_tokens.dart';
import '../models/community_models.dart';
import '../utils/format.dart';

/// Bottom sheet listing a post's comments with an inline composer.
Future<void> showPostComments(
  BuildContext context, {
  required Post post,
  required int myId,
  required Future<bool> Function(String content) onAddComment,
}) async {
  final dio = ApiClient.instance.dio;
  List<PostComment> comments = [];
  String? error;

  try {
    final response = await dio.get('/posts/${post.id}/comments');
    final payload = ApiClient.instance.unwrap(response);
    final rawList = payload is Map<String, dynamic> ? payload['data'] : payload;
    comments = rawList is List ? rawList.map(PostComment.fromJson).toList() : [];
  } on DioException {
    error = 'Could not load comments.';
  } catch (_) {
    error = 'Could not load comments.';
  }

  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    builder: (_) => _CommentsSheet(
      post: post,
      myId: myId,
      initialComments: comments,
      initialError: error,
      onAddComment: onAddComment,
    ),
  );
}

class _CommentsSheet extends StatefulWidget {
  final Post post;
  final int myId;
  final List<PostComment> initialComments;
  final String? initialError;
  final Future<bool> Function(String) onAddComment;

  const _CommentsSheet({
    required this.post,
    required this.myId,
    required this.initialComments,
    this.initialError,
    required this.onAddComment,
  });

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  late final List<PostComment> _comments = List.of(widget.initialComments);
  late String? _error = widget.initialError;
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final ok = await widget.onAddComment(text);
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (ok) {
        _controller.clear();
        _error = null;
        _comments.add(PostComment(
          id: DateTime.now().microsecondsSinceEpoch,
          postId: widget.post.id,
          userId: widget.myId,
          content: text,
          createdAt: DateTime.now(),
        ));
      } else {
        _error = 'Could not post your comment.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Text(
                'Comments',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _comments.isEmpty
                  ? Center(
                      child: Text(
                        _error ?? 'No comments yet. Be the first to comment.',
                        style: const TextStyle(color: DesignTokens.textSecondary),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _comments.length,
                      separatorBuilder: (_, _) => const Divider(height: 1, indent: 64),
                      itemBuilder: (_, i) => _CommentTile(comment: _comments[i]),
                    ),
            ),
            if (_error != null && _comments.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _error!,
                  style: const TextStyle(fontSize: 12, color: DesignTokens.danger),
                ),
              ),
            const Divider(height: 1),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Write a comment…',
                          filled: true,
                          fillColor: const Color(0xFFF2F5F8),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _sending
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.5),
                            ),
                          )
                        : IconButton.filled(
                            onPressed: _submit,
                            style: IconButton.styleFrom(backgroundColor: DesignTokens.primary),
                            icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                          ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final PostComment comment;

  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    final author = comment.author;
    final avatarUrl = author?.avatarUrl;
    final name = author?.name ?? 'MurihSpace user';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: DesignTokens.primarySoft,
            backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null || avatarUrl.isEmpty
                ? Text(
                    name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: DesignTokens.primaryDark, fontWeight: FontWeight.w700, fontSize: 13),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: DesignTokens.textPrimary),
                      ),
                    ),
                    Text(
                      formatRelativeTime(comment.createdAt),
                      style: const TextStyle(fontSize: 11, color: DesignTokens.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(comment.content, style: const TextStyle(fontSize: 14, height: 1.35, color: DesignTokens.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
