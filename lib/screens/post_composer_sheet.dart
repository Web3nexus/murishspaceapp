import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../core/api_client.dart';
import '../core/design_tokens.dart';
import '../models/community_models.dart';
import '../providers/community_provider.dart';

/// Full-screen composer for a community post (text + up to 4 images).
/// Returns the created [Post] (or null on cancel/failure).
Future<Post?> showPostComposer(
  BuildContext context, {
  int? initialCommunityId,
}) {
  return showModalBottomSheet<Post>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    builder: (_) => _PostComposer(initialCommunityId: initialCommunityId),
  );
}

class _PostComposer extends ConsumerStatefulWidget {
  final int? initialCommunityId;

  const _PostComposer({this.initialCommunityId});

  @override
  ConsumerState<_PostComposer> createState() => _PostComposerState();
}

class _PostComposerState extends ConsumerState<_PostComposer> {
  final _controller = TextEditingController();
  final _picker = ImagePicker();
  List<XFile> _images = [];
  int? _communityId;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _communityId = widget.initialCommunityId;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage(limit: 4 - _images.length);
    if (picked.isEmpty) return;
    setState(() => _images = [..._images, ...picked]);
  }

  Future<void> _submit() async {
    final content = _controller.text.trim();
    if (content.isEmpty && _images.isEmpty) return;
    final communityId = _communityId;
    if (communityId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a community to post in.')),
      );
      return;
    }
    setState(() => _submitting = true);

    try {
      final mediaUrls = <String>[];
      for (final image in _images) {
        final bytes = await image.readAsBytes();
        final form = FormData.fromMap({
          'file': MultipartFile.fromBytes(bytes, filename: image.name),
        });
        final upload = await ApiClient.instance.dio.post('/upload', data: form);
        final payload = ApiClient.instance.unwrap(upload);
        final url = payload is Map<String, dynamic> ? payload['url'] : null;
        if (url is String && url.isNotEmpty) mediaUrls.add(url);
      }

      final response = await ApiClient.instance.dio.post('/posts', data: {
        'community_id': communityId,
        'type': 'post',
        'content': content,
        if (mediaUrls.isNotEmpty) 'media_urls': mediaUrls,
      });
      final payload = response.data;
      final rawPost = payload is Map<String, dynamic> ? payload['post'] : null;
      if (!mounted) return;
      Navigator.pop(context, rawPost is Map<String, dynamic> ? Post.fromJson(rawPost) : null);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not publish your post. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final myCommunities = ref.watch(myCommunitiesProvider).communities;
    final canSubmit = (_controller.text.trim().isNotEmpty || _images.isNotEmpty) &&
        _communityId != null &&
        !_submitting;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Create post',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (myCommunities.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'You need to join a community before posting.',
                  style: TextStyle(color: DesignTokens.textSecondary),
                ),
              )
            else
              DropdownButtonFormField<int>(
                initialValue: _communityId,
                decoration: const InputDecoration(
                  labelText: 'Community',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  for (final c in myCommunities)
                    DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (id) => setState(() => _communityId = id),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              minLines: 4,
              maxLines: 10,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: "What's happening?",
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            if (_images.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final image in _images)
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            File(image.path),
                            width: 84,
                            height: 84,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              width: 84,
                              height: 84,
                              color: const Color(0xFFF2F5F8),
                              child: const Icon(Icons.broken_image_outlined),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: InkWell(
                            onTap: () => setState(() => _images.remove(image)),
                            child: Container(
                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                              padding: const EdgeInsets.all(2),
                              child: const Icon(Icons.close, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton(
                  onPressed: _images.length >= 4 ? null : _pickImages,
                  icon: const Icon(Icons.image_outlined, color: DesignTokens.primaryDark),
                  tooltip: 'Add photos',
                ),
                const Spacer(),
                if (_submitting)
                  const Padding(
                    padding: EdgeInsets.all(10),
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  )
                else
                  FilledButton(
                    onPressed: canSubmit ? _submit : null,
                    style: FilledButton.styleFrom(backgroundColor: DesignTokens.primary),
                    child: const Text('Publish'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
