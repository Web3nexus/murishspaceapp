import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../core/api_client.dart';
import '../models/community_models.dart';
import '../providers/auth_provider.dart';
import '../providers/community_provider.dart';
import '../providers/follow_provider.dart';

/// Full-featured advanced creator studio for community posts.
/// Returns the created [Post] (or null on cancel/failure).
Future<Post?> showPostComposer(
  BuildContext context, {
  int? initialCommunityId,
}) {
  return showModalBottomSheet<Post>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
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
  final _contentController = TextEditingController();
  final _pollQuestionController = TextEditingController();
  final List<TextEditingController> _pollOptionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];
  final _locationController = TextEditingController();

  final _picker = ImagePicker();
  List<XFile> _images = [];
  int? _communityId;
  String _postType = 'post'; // 'post' | 'poll' | 'announcement'
  String _privacy = 'community'; // 'community' | 'public' | 'followers'
  int _pollDurationDays = 3;
  bool _commentsDisabled = false;
  bool _submitting = false;

  final List<String> _suggestedTags = [
    'General',
    'Tech',
    'Design',
    'Crypto',
    'Business',
    'Education',
    'Announcement',
  ];
  final Set<String> _selectedTags = {};

  @override
  void initState() {
    super.initState();
    _communityId = widget.initialCommunityId;
  }

  @override
  void dispose() {
    _contentController.dispose();
    _pollQuestionController.dispose();
    for (final c in _pollOptionControllers) {
      c.dispose();
    }
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final remaining = 4 - _images.length;
    if (remaining <= 0) return;
    final picked = await _picker.pickMultiImage(limit: remaining);
    if (picked.isEmpty) return;
    setState(() => _images = [..._images, ...picked].take(4).toList());
  }

  Future<void> _takePhoto() async {
    if (_images.length >= 4) return;
    final photo = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (photo == null) return;
    setState(() => _images.add(photo));
  }

  void _addPollOption() {
    if (_pollOptionControllers.length >= 5) return;
    setState(() {
      _pollOptionControllers.add(TextEditingController());
    });
  }

  void _removePollOption(int index) {
    if (_pollOptionControllers.length <= 2) return;
    setState(() {
      final c = _pollOptionControllers.removeAt(index);
      c.dispose();
    });
  }

  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });
  }

  Future<void> _submit() async {
    final content = _contentController.text.trim();
    if (content.isEmpty && _images.isEmpty && _postType != 'poll') return;
    final communityId = _communityId;
    if (communityId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a destination community.')),
      );
      return;
    }

    if (_postType == 'poll') {
      final q = _pollQuestionController.text.trim();
      final validOpts = _pollOptionControllers
          .map((c) => c.text.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      if (q.isEmpty || validOpts.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a poll question and at least 2 options.')),
        );
        return;
      }
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

      final postPayload = <String, dynamic>{
        'community_id': communityId,
        'type': _postType,
        'content': content.isNotEmpty ? content : (_pollQuestionController.text.trim()),
        'privacy': _privacy,
        'comments_disabled': _commentsDisabled,
        if (mediaUrls.isNotEmpty) 'media_urls': mediaUrls,
        if (_selectedTags.isNotEmpty) 'hashtags': _selectedTags.map((t) => '#$t').toList(),
        if (_locationController.text.trim().isNotEmpty) 'location': _locationController.text.trim(),
      };

      if (_postType == 'poll') {
        postPayload['poll_question'] = _pollQuestionController.text.trim();
        postPayload['poll_options'] = _pollOptionControllers
            .map((c) => c.text.trim())
            .where((t) => t.isNotEmpty)
            .toList();
        postPayload['poll_ends_at'] = DateTime.now().add(Duration(days: _pollDurationDays)).toIso8601String();
      }

      final response = await ApiClient.instance.dio.post('/posts', data: postPayload);
      final payload = response.data;
      final rawPost = payload is Map<String, dynamic> ? payload['post'] : null;

      ref.read(followProvider.notifier).incrementPostsCount(1);

      if (!mounted) return;
      Navigator.pop(context, rawPost is Map<String, dynamic> ? Post.fromJson(rawPost) : null);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not publish post. Please check your connection and try again.')),
      );
    }
  }

  void _showCommunityPicker(List<Community> communities, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final user = ref.watch(authProvider).user;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      'Post Destination',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${communities.length + 1} options',
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  children: [
                    // Public Wall / Profile option
                    ListTile(
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFF007AFF).withValues(alpha: 0.15),
                        backgroundImage: user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty
                            ? NetworkImage(user.avatarUrl!)
                            : null,
                        child: user?.avatarUrl == null || user!.avatarUrl!.isEmpty
                            ? Text(
                                (user?.name ?? 'M')[0].toUpperCase(),
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF007AFF)),
                              )
                            : null,
                      ),
                      title: Text(
                        'My Public Profile / Wall',
                        style: TextStyle(
                          fontWeight: _communityId == null ? FontWeight.w800 : FontWeight.w600,
                          color: _communityId == null ? const Color(0xFF007AFF) : (isDark ? Colors.white : Colors.black),
                        ),
                      ),
                      subtitle: Text(
                        'Public • Visible to everyone on global feed',
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                      trailing: _communityId == null ? const Icon(Icons.check_circle_rounded, color: Color(0xFF007AFF)) : null,
                      onTap: () {
                        setState(() => _communityId = null);
                        Navigator.pop(ctx);
                      },
                    ),
                    const Divider(height: 1, indent: 64),
                    for (final comm in communities) ...[
                      ListTile(
                        leading: CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(0xFF007AFF).withValues(alpha: 0.15),
                          backgroundImage: comm.logoUrl != null && comm.logoUrl!.isNotEmpty
                              ? NetworkImage(comm.logoUrl!)
                              : null,
                          child: comm.logoUrl == null || comm.logoUrl!.isEmpty
                              ? Text(
                                  comm.name.isNotEmpty ? comm.name[0].toUpperCase() : 'C',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF007AFF)),
                                )
                              : null,
                        ),
                        title: Text(
                          comm.name,
                          style: TextStyle(
                            fontWeight: _communityId == comm.id ? FontWeight.w800 : FontWeight.w600,
                            color: _communityId == comm.id ? const Color(0xFF007AFF) : (isDark ? Colors.white : Colors.black),
                          ),
                        ),
                        subtitle: Text(
                          '${comm.membersCount} members • ${comm.visibility == "private" ? "Private" : "Public"}',
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                        ),
                        trailing: _communityId == comm.id ? const Icon(Icons.check_circle_rounded, color: Color(0xFF007AFF)) : null,
                        onTap: () {
                          setState(() => _communityId = comm.id);
                          Navigator.pop(ctx);
                        },
                      ),
                      const Divider(height: 1, indent: 64),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPrivacyPicker(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  'Who can see this post?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.public_rounded, color: Color(0xFF007AFF)),
                  title: const Text('Public', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Anyone on MurihSpace can discover and interact'),
                  trailing: _privacy == 'public' ? const Icon(Icons.check_circle_rounded, color: Color(0xFF007AFF)) : null,
                  onTap: () {
                    setState(() => _privacy = 'public');
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.groups_rounded, color: Color(0xFF34C759)),
                  title: const Text('Community Members', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Only members of this community can view'),
                  trailing: _privacy == 'community' ? const Icon(Icons.check_circle_rounded, color: Color(0xFF007AFF)) : null,
                  onTap: () {
                    setState(() => _privacy = 'community');
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.people_alt_rounded, color: Color(0xFFFF9500)),
                  title: const Text('Followers Only', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Only your registered followers see this in feed'),
                  trailing: _privacy == 'followers' ? const Icon(Icons.check_circle_rounded, color: Color(0xFF007AFF)) : null,
                  onTap: () {
                    setState(() => _privacy = 'followers');
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF141416) : Colors.white;
    final cardBg = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F4F7);
    final borderColor = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E7EB);
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

    final user = ref.watch(authProvider).user;
    final myCommunities = ref.watch(myCommunitiesProvider).communities;

    // Auto-select first community if none selected
    if (_communityId == null && myCommunities.isNotEmpty) {
      _communityId = myCommunities.first.id;
    }
    final selectedCommunity = myCommunities.where((c) => c.id == _communityId).firstOrNull;

    final canSubmit = (_contentController.text.trim().isNotEmpty ||
            _images.isNotEmpty ||
            (_postType == 'poll' && _pollQuestionController.text.trim().isNotEmpty)) &&
        _communityId != null &&
        !_submitting;

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Top Handle & Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: textPrimary),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Cancel',
                    ),
                    Text(
                      'Create Post',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        gradient: canSubmit
                            ? const LinearGradient(
                                colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: canSubmit ? null : (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E7EB)),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: canSubmit
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF007AFF).withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                )
                              ]
                            : null,
                      ),
                      child: ElevatedButton(
                        onPressed: canSubmit ? _submit : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          disabledForegroundColor: isDark ? Colors.grey[600] : Colors.grey[400],
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text(
                                'Publish',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Main Scrollable Editor Area
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // User & Destination Selector Card
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: const Color(0xFF007AFF).withValues(alpha: 0.15),
                      backgroundImage: user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty
                          ? NetworkImage(user.avatarUrl!)
                          : null,
                      child: user?.avatarUrl == null
                          ? Text(
                              user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : 'U',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF007AFF)),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  user?.name ?? 'You',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (user?.kycStatus == 'verified' || user?.kycStatus == 'approved') ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.verified_rounded, color: Color(0xFF007AFF), size: 16),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              // Destination / Community selector button
                              GestureDetector(
                                onTap: () => _showCommunityPicker(myCommunities, isDark),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: cardBg,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: borderColor),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _communityId == null ? Icons.public_rounded : Icons.groups_rounded,
                                        size: 14,
                                        color: const Color(0xFF007AFF),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _communityId == null
                                            ? 'My Public Wall'
                                            : (selectedCommunity?.name ?? 'Community'),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: textPrimary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(width: 2),
                                      Icon(Icons.arrow_drop_down_rounded, size: 16, color: textSecondary),
                                    ],
                                  ),
                                ),
                              ),
                              // Privacy selector button
                              GestureDetector(
                                onTap: () => _showPrivacyPicker(isDark),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: cardBg,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: borderColor),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _privacy == 'public'
                                            ? Icons.public_rounded
                                            : _privacy == 'community'
                                                ? Icons.lock_outline_rounded
                                                : Icons.people_alt_outlined,
                                        size: 13,
                                        color: textSecondary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _privacy.capitalize(),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: textSecondary,
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Icon(Icons.arrow_drop_down_rounded, size: 16, color: textSecondary),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Post Type Segmented Switcher
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      _buildTypeTab('post', 'Discussion', Icons.article_rounded, isDark),
                      _buildTypeTab('poll', 'Poll', Icons.poll_rounded, isDark),
                      _buildTypeTab('announcement', 'Notice', Icons.campaign_rounded, isDark),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Post Body Text Field
                TextField(
                  controller: _contentController,
                  minLines: 4,
                  maxLines: 12,
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.45,
                    color: textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: _postType == 'poll'
                        ? 'Describe your poll or ask a question...'
                        : _postType == 'announcement'
                            ? 'Share an important community announcement...'
                            : "What's happening in your space?",
                    hintStyle: TextStyle(
                      fontSize: 16,
                      color: textSecondary?.withValues(alpha: 0.7),
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),

                // Poll Builder Section (If Poll active)
                if (_postType == 'poll') ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF007AFF).withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.poll_rounded, color: Color(0xFF007AFF), size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Poll Question & Options',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _pollQuestionController,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Ask a question...',
                            filled: true,
                            fillColor: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: borderColor),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                        ),
                        const SizedBox(height: 10),
                        for (int i = 0; i < _pollOptionControllers.length; i++) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _pollOptionControllers[i],
                                    onChanged: (_) => setState(() {}),
                                    decoration: InputDecoration(
                                      hintText: 'Option ${i + 1}',
                                      filled: true,
                                      fillColor: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: borderColor),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    ),
                                  ),
                                ),
                                if (_pollOptionControllers.length > 2)
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                                    onPressed: () => _removePollOption(i),
                                  ),
                              ],
                            ),
                          ),
                        ],
                        if (_pollOptionControllers.length < 5)
                          TextButton.icon(
                            onPressed: _addPollOption,
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Add Option', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Poll Duration',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary),
                            ),
                            DropdownButton<int>(
                              value: _pollDurationDays,
                              underline: const SizedBox(),
                              dropdownColor: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                              items: const [
                                DropdownMenuItem(value: 1, child: Text('24 Hours')),
                                DropdownMenuItem(value: 3, child: Text('3 Days')),
                                DropdownMenuItem(value: 7, child: Text('7 Days')),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _pollDurationDays = val);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                // Selected Images Gallery Preview Grid
                if (_images.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (int i = 0; i < _images.length; i++)
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.file(
                                File(_images[i].path),
                                width: (_images.length == 1) ? 220 : 96,
                                height: (_images.length == 1) ? 160 : 96,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 6,
                              right: 6,
                              child: GestureDetector(
                                onTap: () => setState(() => _images.removeAt(i)),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.black87,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],

                // Location tag row (if filled)
                if (_locationController.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Chip(
                    avatar: const Icon(Icons.location_on_rounded, size: 16, color: Color(0xFFFF3B30)),
                    label: Text(_locationController.text.trim()),
                    deleteIcon: const Icon(Icons.close_rounded, size: 14),
                    onDeleted: () => setState(() => _locationController.clear()),
                  ),
                ],

                const SizedBox(height: 16),

                // Trending Hashtags Quick Inserter
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ADD TOPICS / HASHTAGS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        for (final tag in _suggestedTags)
                          FilterChip(
                            label: Text('#$tag'),
                            selected: _selectedTags.contains(tag),
                            selectedColor: const Color(0xFF007AFF).withValues(alpha: 0.2),
                            checkmarkColor: const Color(0xFF007AFF),
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _selectedTags.contains(tag)
                                  ? const Color(0xFF007AFF)
                                  : (isDark ? Colors.grey[300] : Colors.grey[700]),
                            ),
                            backgroundColor: cardBg,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            side: BorderSide(
                              color: _selectedTags.contains(tag) ? const Color(0xFF007AFF) : borderColor,
                            ),
                            onSelected: (_) => _toggleTag(tag),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Bottom Quick Media & Settings Toolbar
          Container(
            padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).viewInsets.bottom + 8),
            decoration: BoxDecoration(
              color: cardBg,
              border: Border(top: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.image_outlined, color: Color(0xFF007AFF), size: 24),
                  tooltip: 'Add Photos',
                  onPressed: _images.length < 4 ? _pickImages : null,
                ),
                IconButton(
                  icon: const Icon(Icons.camera_alt_outlined, color: Color(0xFF34C759), size: 24),
                  tooltip: 'Take Photo',
                  onPressed: _images.length < 4 ? _takePhoto : null,
                ),
                IconButton(
                  icon: Icon(
                    Icons.poll_rounded,
                    color: _postType == 'poll' ? const Color(0xFF007AFF) : textSecondary,
                    size: 24,
                  ),
                  tooltip: 'Create Poll',
                  onPressed: () {
                    setState(() {
                      _postType = _postType == 'poll' ? 'post' : 'poll';
                    });
                  },
                ),
                IconButton(
                  icon: Icon(
                    Icons.location_on_outlined,
                    color: _locationController.text.isNotEmpty ? const Color(0xFFFF3B30) : textSecondary,
                    size: 24,
                  ),
                  tooltip: 'Add Location',
                  onPressed: () => _promptLocation(context, isDark),
                ),
                IconButton(
                  icon: Icon(
                    _commentsDisabled ? Icons.chat_bubble_outline_rounded : Icons.chat_bubble_rounded,
                    color: _commentsDisabled ? Colors.red : textSecondary,
                    size: 22,
                  ),
                  tooltip: _commentsDisabled ? 'Comments Disabled' : 'Disable Comments',
                  onPressed: () {
                    setState(() => _commentsDisabled = !_commentsDisabled);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        duration: const Duration(seconds: 1),
                        content: Text(_commentsDisabled ? 'Comments turned off for this post' : 'Comments allowed'),
                      ),
                    );
                  },
                ),
                const Spacer(),
                // Character counter
                Text(
                  '${_contentController.text.length} / 5,000',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _contentController.text.length > 4500 ? Colors.red : textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeTab(String type, String label, IconData icon, bool isDark) {
    final selected = _postType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _postType = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? (isDark ? const Color(0xFF2C2C2E) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? const Color(0xFF007AFF) : (isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected
                      ? (isDark ? Colors.white : Colors.black)
                      : (isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _promptLocation(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) {
        final locCtrl = TextEditingController(text: _locationController.text);
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          title: const Text('Add Location Tag'),
          content: TextField(
            controller: locCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'e.g. Lagos, Nigeria or London, UK',
              prefixIcon: Icon(Icons.location_on_rounded, color: Color(0xFFFF3B30)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                setState(() => _locationController.text = locCtrl.text.trim());
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
