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

/// Full-featured advanced creator studio for public wall and community posts.
/// Designed after Facebook/Threads creator experience with open canvas, rich bottom tools, and safe status bar handling.
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
  String _privacy = 'public'; // 'public' | 'community' | 'followers'
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

  final List<String> _popularLocations = [
    'Lagos, Nigeria',
    'Abuja, Nigeria',
    'London, UK',
    'New York, USA',
    'Nairobi, Kenya',
    'Dubai, UAE',
    'MurihSpace HQ',
    'Remote Space',
  ];

  @override
  void initState() {
    super.initState();
    _communityId = widget.initialCommunityId;
    if (_communityId != null) {
      _privacy = 'community';
    }
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
        'community_id': _communityId,
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
      final rawPost = payload is Map<String, dynamic> && payload['data'] is Map<String, dynamic>
          ? payload['data']['post'] ?? payload['data']
          : (payload is Map<String, dynamic> ? payload['post'] : null);

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
                        'Public • Visible to everyone on feed',
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                      trailing: _communityId == null ? const Icon(Icons.check_circle_rounded, color: Color(0xFF007AFF)) : null,
                      onTap: () {
                        setState(() {
                          _communityId = null;
                          _privacy = 'public';
                        });
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
                          setState(() {
                            _communityId = comm.id;
                            _privacy = 'community';
                          });
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
                child: Text(
                  'Select Audience',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ),
              const Divider(height: 1),
              _buildPrivacyOption(ctx, 'public', 'Public', 'Anyone on MurihSpace can view', Icons.public_rounded, isDark),
              _buildPrivacyOption(ctx, 'followers', 'Followers Only', 'Only people who follow you', Icons.people_alt_outlined, isDark),
              if (_communityId != null)
                _buildPrivacyOption(ctx, 'community', 'Community Members', 'Restricted to members of this community', Icons.lock_outline_rounded, isDark),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPrivacyOption(
    BuildContext ctx,
    String value,
    String title,
    String subtitle,
    IconData icon,
    bool isDark,
  ) {
    final selected = _privacy == value;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF007AFF).withValues(alpha: 0.15)
              : (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F4F7)),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: selected ? const Color(0xFF007AFF) : (isDark ? Colors.white : Colors.black87), size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          color: selected ? const Color(0xFF007AFF) : (isDark ? Colors.white : Colors.black),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
      ),
      trailing: selected ? const Icon(Icons.check_circle_rounded, color: Color(0xFF007AFF)) : null,
      onTap: () {
        setState(() => _privacy = value);
        Navigator.pop(ctx);
      },
    );
  }

  void _showLocationPicker(bool isDark) {
    final searchCtrl = TextEditingController(text: _locationController.text);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final query = searchCtrl.text.trim().toLowerCase();
            final filtered = query.isEmpty
                ? _popularLocations
                : _popularLocations.where((l) => l.toLowerCase().contains(query)).toList();

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                top: 10,
                left: 16,
                right: 16,
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF3B30).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.location_on_rounded, color: Color(0xFFFF3B30), size: 20),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Add Location / Check In',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F4F8),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: TextField(
                        controller: searchCtrl,
                        autofocus: true,
                        onChanged: (_) => setModalState(() {}),
                        style: TextStyle(color: isDark ? Colors.white : Colors.black),
                        decoration: InputDecoration(
                          hintText: 'Search city, spot, or type location...',
                          hintStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 14),
                          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFFF3B30), size: 20),
                          suffixIcon: searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18),
                                  onPressed: () {
                                    searchCtrl.clear();
                                    setModalState(() {});
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (searchCtrl.text.trim().isNotEmpty && !filtered.contains(searchCtrl.text.trim())) ...[
                      ListTile(
                        leading: const Icon(Icons.add_location_alt_rounded, color: Color(0xFF007AFF)),
                        title: Text(
                          'Use "${searchCtrl.text.trim()}"',
                          style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF007AFF)),
                        ),
                        onTap: () {
                          setState(() => _locationController.text = searchCtrl.text.trim());
                          Navigator.pop(ctx);
                        },
                      ),
                      const Divider(height: 1),
                    ],
                    Text(
                      'POPULAR LOCATIONS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 180,
                      child: ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, indent: 44),
                        itemBuilder: (_, index) {
                          final loc = filtered[index];
                          final isSelected = _locationController.text.trim() == loc;
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              Icons.location_pin,
                              color: isSelected ? const Color(0xFFFF3B30) : (isDark ? Colors.grey[400] : Colors.grey[600]),
                              size: 20,
                            ),
                            title: Text(
                              loc,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected ? const Color(0xFFFF3B30) : (isDark ? Colors.white : Colors.black),
                              ),
                            ),
                            trailing: isSelected ? const Icon(Icons.check_rounded, color: Color(0xFFFF3B30), size: 18) : null,
                            onTap: () {
                              setState(() => _locationController.text = loc);
                              Navigator.pop(ctx);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(authProvider).user;
    final myCommunities = ref.watch(joinedCommunitiesProvider).communities;

    Community? selectedCommunity;
    if (_communityId != null) {
      try {
        selectedCommunity = myCommunities.firstWhere((c) => c.id == _communityId);
      } catch (_) {
        selectedCommunity = null;
      }
    }

    final hasText = _contentController.text.trim().isNotEmpty;
    final hasImages = _images.isNotEmpty;
    final hasPollContent = _postType == 'poll' &&
        _pollQuestionController.text.trim().isNotEmpty &&
        _pollOptionControllers.where((c) => c.text.trim().isNotEmpty).length >= 2;

    final canSubmit = !_submitting && (hasText || hasImages || hasPollContent);

    final bg = isDark ? const Color(0xFF141416) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final cardBg = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE2E8F0);

    final firstName = (user?.name ?? 'there').split(' ').first;
    final locationText = _locationController.text.trim();

    return Container(
      height: MediaQuery.of(context).size.height * 0.94,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          SafeArea(
            top: true,
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Column(
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: textPrimary, size: 24),
                        onPressed: () => Navigator.pop(context),
                        tooltip: 'Cancel',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      Text(
                        'Create Post',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
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
                          color: canSubmit ? null : (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE2E8F0)),
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
                            minimumSize: const Size(72, 34),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          child: _submitting
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text(
                                  'Post',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: const Color(0xFF007AFF).withValues(alpha: 0.15),
                      backgroundImage: user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty
                          ? NetworkImage(user.avatarUrl!)
                          : null,
                      child: user?.avatarUrl == null || user!.avatarUrl!.isEmpty
                          ? Text(
                              user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : 'U',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF007AFF)),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: textPrimary,
                              ),
                              children: [
                                TextSpan(text: user?.name ?? 'You'),
                                if (user?.kycStatus == 'verified' || user?.kycStatus == 'approved')
                                  const WidgetSpan(
                                    alignment: PlaceholderAlignment.middle,
                                    child: Padding(
                                      padding: EdgeInsets.only(left: 4),
                                      child: Icon(Icons.verified_rounded, color: Color(0xFF007AFF), size: 15),
                                    ),
                                  ),
                                if (locationText.isNotEmpty) ...[
                                  TextSpan(
                                    text: ' is at ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.normal,
                                      color: textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                  TextSpan(
                                    text: locationText,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFFFF3B30),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              GestureDetector(
                                onTap: () => _showCommunityPicker(myCommunities, isDark),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: cardBg,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: borderColor),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _communityId == null ? Icons.public_rounded : Icons.groups_rounded,
                                        size: 13,
                                        color: const Color(0xFF007AFF),
                                      ),
                                      const SizedBox(width: 5),
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
                              GestureDetector(
                                onTap: () => _showPrivacyPicker(isDark),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: cardBg,
                                    borderRadius: BorderRadius.circular(14),
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
                TextField(
                  controller: _contentController,
                  minLines: 4,
                  maxLines: 15,
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(
                    fontSize: _contentController.text.length < 80 ? 19 : 16,
                    height: 1.45,
                    color: textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: _postType == 'poll'
                        ? 'Describe your poll question for $firstName...'
                        : _postType == 'announcement'
                            ? 'Share an important community announcement...'
                            : "What's on your mind, $firstName?",
                    hintStyle: TextStyle(
                      fontSize: _contentController.text.length < 80 ? 19 : 16,
                      color: textSecondary?.withValues(alpha: 0.65),
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                if (_postType == 'announcement') ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFFF9500).withValues(alpha: 0.15),
                          const Color(0xFFFF3B30).withValues(alpha: 0.15),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFF9500).withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.campaign_rounded, color: Color(0xFFFF9500), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Posting as an Official Notice (highlighted with orange accent)',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _postType = 'post'),
                          child: const Icon(Icons.close_rounded, size: 16),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_images.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: _images.length == 1 ? 200 : 120,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _images.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, idx) {
                        final file = _images[idx];
                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                width: _images.length == 1 ? MediaQuery.of(context).size.width - 32 : 120,
                                height: _images.length == 1 ? 200 : 120,
                                color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE2E8F0),
                                child: Image.file(
                                  File(file.path),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 6,
                              right: 6,
                              child: GestureDetector(
                                onTap: () => setState(() => _images.removeAt(idx)),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.7),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
                if (locationText.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3B30).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFFF3B30).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on_rounded, size: 14, color: Color(0xFFFF3B30)),
                          const SizedBox(width: 6),
                          Text(
                            locationText,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFFF3B30),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => setState(() => _locationController.clear()),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFF3B30),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close_rounded, size: 10, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (_postType == 'poll') ...[
                  const SizedBox(height: 14),
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
                              'Poll Question & Choices',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: textPrimary,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () => setState(() => _postType = 'post'),
                              tooltip: 'Remove Poll',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
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
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOPICS & HASHTAGS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          for (final tag in _suggestedTags) ...[
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text('#$tag'),
                                selected: _selectedTags.contains(tag),
                                selectedColor: const Color(0xFF007AFF).withValues(alpha: 0.18),
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
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.of(context).viewInsets.bottom + 12),
            decoration: BoxDecoration(
              color: cardBg,
              border: Border(top: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                Text(
                  'Add to your post',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.photo_library_rounded, color: Color(0xFF45BD62), size: 23),
                  tooltip: 'Photos',
                  onPressed: _images.length < 4 ? _pickImages : null,
                ),
                IconButton(
                  icon: const Icon(Icons.camera_alt_rounded, color: Color(0xFF1877F2), size: 23),
                  tooltip: 'Camera',
                  onPressed: _images.length < 4 ? _takePhoto : null,
                ),
                IconButton(
                  icon: Icon(
                    Icons.location_on_rounded,
                    color: locationText.isNotEmpty ? const Color(0xFFFF3B30) : const Color(0xFFF3425F),
                    size: 23,
                  ),
                  tooltip: 'Add Location',
                  onPressed: () => _showLocationPicker(isDark),
                ),
                IconButton(
                  icon: Icon(
                    Icons.poll_rounded,
                    color: _postType == 'poll' ? const Color(0xFF007AFF) : const Color(0xFF20C997),
                    size: 23,
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
                    Icons.campaign_rounded,
                    color: _postType == 'announcement' ? const Color(0xFFFF9500) : const Color(0xFFFF8A00),
                    size: 23,
                  ),
                  tooltip: 'Notice / Announcement',
                  onPressed: () {
                    setState(() {
                      _postType = _postType == 'announcement' ? 'post' : 'announcement';
                    });
                  },
                ),
                IconButton(
                  icon: Icon(
                    _commentsDisabled ? Icons.comments_disabled_rounded : Icons.chat_bubble_rounded,
                    color: _commentsDisabled ? Colors.red : textSecondary,
                    size: 20,
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
