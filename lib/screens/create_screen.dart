import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../components/murih_icon.dart';
import '../core/design_tokens.dart';
import 'post_composer_sheet.dart';

/// Complete Redesigned Creator Studio / Publishing Tools (Page D)
/// matching MurihSpace visual reference:
/// Header ("Creator Studio", "Publishing Tools & Content Strategy") ·
/// "Grow faster with consistency" progress card (4 of 5 posts scheduled) ·
/// Publishing Tools Menu (Create Post, Content Library, Post Schedule, Templates, AI Assistant, Cross-Post) ·
/// In-screen publishing suite with audience selector, media upload carousel with duration badges,
/// format pills (Photo, Video, Live, Poll), AI caption generator & suggested hashtags,
/// location, tags, community & music toggles, post scheduling, and Publish CTA.
class CreateScreen extends ConsumerStatefulWidget {
  const CreateScreen({super.key});

  @override
  ConsumerState<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends ConsumerState<CreateScreen> {
  final _captionController = TextEditingController();
  final _locationController = TextEditingController();
  final _picker = ImagePicker();

  String _selectedAudience = 'Public';
  String _selectedFormat = 'Photo';
  bool _isScheduled = false;
  DateTime _scheduledDate = DateTime.now().add(const Duration(hours: 4));
  bool _isPublishing = false;
  bool _aiGenerating = false;

  final List<XFile> _selectedMedia = [];

  final List<String> _suggestedHashtags = [
    '#MurihSpace',
    '#CreatorEconomy',
    '#DailyVibe',
    '#Inspiration',
    '#TechTrends',
    '#FitnessLifestyle',
    '#CostaBlanca',
  ];

  final List<Map<String, dynamic>> _scheduledPosts = [
    {
      'title': 'Productivity Masterclass Short Video',
      'scheduledTime': 'Tomorrow at 09:00 AM',
      'format': 'Reel',
      'viewsProjected': '12K views',
      'thumbnail': 'https://images.unsplash.com/photo-1517838277536-f5f99be501cd?w=300',
    },
    {
      'title': 'Costa Blanca Sunset Memories Carousel',
      'scheduledTime': 'Friday at 18:00 PM',
      'format': 'Photo Post',
      'viewsProjected': '8.5K views',
      'thumbnail': 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=300',
    },
  ];

  @override
  void dispose() {
    _captionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    try {
      final picked = await _picker.pickMultiImage(limit: 6 - _selectedMedia.length);
      if (picked.isNotEmpty) {
        setState(() {
          _selectedMedia.addAll(picked);
        });
      }
    } catch (_) {}
  }

  void _generateAiCaption() async {
    setState(() => _aiGenerating = true);
    await Future.delayed(const Duration(milliseconds: 700));
    final prompts = [
      'Embrace the journey and keep pushing your craft forward. Every step counts! 🚀 #MurihSpace #CreatorEconomy',
      'Behind the scenes of today’s creative workflow. What are you building this week? Drop your thoughts below! 💡 #DailyVibe',
      'Consistency is not about perfection, it is about showing up daily and delivering value. Let’s make it count! ⚡️ #TechTrends',
    ];
    final selectedPrompt = prompts[DateTime.now().second % prompts.length];
    setState(() {
      _captionController.text = selectedPrompt;
      _aiGenerating = false;
    });
  }

  void _addHashtag(String tag) {
    final current = _captionController.text;
    if (!current.contains(tag)) {
      _captionController.text = current.isEmpty ? tag : '$current $tag';
    }
  }

  Future<void> _submitPost() async {
    final caption = _captionController.text.trim();
    if (caption.isEmpty && _selectedMedia.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a caption or attach media.')),
      );
      return;
    }

    setState(() => _isPublishing = true);
    await Future.delayed(const Duration(milliseconds: 900));

    if (!mounted) return;
    setState(() {
      _isPublishing = false;
      _captionController.clear();
      _selectedMedia.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isScheduled
              ? 'Post scheduled successfully for ${_scheduledDate.day}/${_scheduledDate.month} at ${_scheduledDate.hour}:${_scheduledDate.minute.toString().padLeft(2, '0')}!'
              : 'Post published successfully to MurihSpace!',
        ),
        backgroundColor: const Color(0xFF16A34A),
      ),
    );
  }

  void _showTemplatesModal() {
    final templates = [
      {'title': 'Hook + Story + Takeaway', 'desc': 'Great for thought leadership & personal stories'},
      {'title': 'Problem · Agitate · Solution', 'desc': 'High-converting framework for tools & advice'},
      {'title': 'Behind the Scenes & Lessons', 'desc': 'Engaging breakdown of your real daily work'},
      {'title': 'Top 3 Tools / Resources', 'desc': 'Viral saveable list format that boosts bookmarks'},
    ];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF161B26)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE4E7EC),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Creator Post Templates',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'Select a proven structure to jumpstart your post:',
                style: TextStyle(fontSize: 12, color: Color(0xFF667085)),
              ),
              const SizedBox(height: 16),
              for (final t in templates)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: DesignTokens.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const MurihIcon('Category', color: DesignTokens.primary, size: 18),
                  ),
                  title: Text(t['title']!, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  subtitle: Text(t['desc']!, style: const TextStyle(fontSize: 11, color: Color(0xFF667085))),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12),
                  onTap: () {
                    Navigator.pop(ctx);
                    _captionController.text = '📌 ${t['title']}\n\n1. The Hook:\n2. The Story:\n3. Key Takeaway:\n\n#MurihSpace';
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F1319) : const Color(0xFFF3F5F8);
    final cardBg = isDark ? const Color(0xFF161B26) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF17202B);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085);
    final borderColor = isDark ? const Color(0xFF2E384D) : const Color(0xFFE4E7EC);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: textPrimary,
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/app/home');
            }
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Creator Studio',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
            Text(
              'Publishing Tools & Content Strategy',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => context.push('/profile/notifications'),
            icon: const Icon(Icons.notifications_outlined),
            color: textPrimary,
            tooltip: 'Notifications',
          ),
          IconButton(
            onPressed: () => context.push('/creator-hub'),
            icon: const Icon(Icons.workspace_premium_rounded),
            color: DesignTokens.primary,
            tooltip: 'Creator Hub',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. "Grow faster with consistency" Strategy Hero Banner
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF16233B), const Color(0xFF1A3365)]
                      : [const Color(0xFFE8F1FD), const Color(0xFFD6E4FA)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: DesignTokens.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: DesignTokens.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 16),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Grow Faster with Consistency',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF17202B),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '+24% Lift',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Weekly Goal: 4 of 5 posts scheduled',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                        ),
                      ),
                      const Text(
                        '80%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: DesignTokens.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: const LinearProgressIndicator(
                      value: 0.8,
                      minHeight: 8,
                      backgroundColor: Colors.white24,
                      valueColor: AlwaysStoppedAnimation<Color>(DesignTokens.primary),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Tip: Morning releases (08:00 - 11:00) yield 3.2x higher discovery conversions in your audience timezone.',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 2. Quick Publishing Tools Grid (6 interactive options)
            Text(
              'Publishing Tools',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _toolCard(
                    icon: Icons.edit_note_rounded,
                    title: 'Create Post',
                    subtitle: 'Rich composer',
                    color: DesignTokens.primary,
                    isDark: isDark,
                    cardBg: cardBg,
                    borderColor: borderColor,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    onTap: () => showPostComposer(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _toolCard(
                    icon: Icons.video_collection_rounded,
                    title: 'Content Library',
                    subtitle: 'Reels & drafts',
                    color: const Color(0xFF7C3AED),
                    isDark: isDark,
                    cardBg: cardBg,
                    borderColor: borderColor,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    onTap: () => context.push('/app/profile'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _toolCard(
                    icon: Icons.calendar_month_rounded,
                    title: 'Post Schedule',
                    subtitle: 'Planned timeline',
                    color: const Color(0xFF16A34A),
                    isDark: isDark,
                    cardBg: cardBg,
                    borderColor: borderColor,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    onTap: () {
                      setState(() => _isScheduled = true);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _toolCard(
                    icon: Icons.dashboard_customize_rounded,
                    title: 'Templates',
                    subtitle: 'Viral post hooks',
                    color: const Color(0xFFD97706),
                    isDark: isDark,
                    cardBg: cardBg,
                    borderColor: borderColor,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    onTap: _showTemplatesModal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 3. Fast Publishing Suite Card (In-Screen Studio)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Compose & Publish',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                        ),
                      ),
                      // Audience Selector Dropdown
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E2638) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: borderColor),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedAudience,
                            isDense: true,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
                            items: const [
                              DropdownMenuItem(value: 'Public', child: Text('Public', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                              DropdownMenuItem(value: 'Followers', child: Text('Followers', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                              DropdownMenuItem(value: 'Exclusive', child: Text('Exclusive', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedAudience = val);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Format Pills: Photo, Video, Live, Poll
                  Row(
                    children: [
                      _formatPill(
                        label: 'Photo',
                        icon: Icons.image_rounded,
                        color: const Color(0xFF16A34A),
                        selected: _selectedFormat == 'Photo',
                        isDark: isDark,
                        onTap: () => setState(() => _selectedFormat = 'Photo'),
                      ),
                      const SizedBox(width: 8),
                      _formatPill(
                        label: 'Video',
                        icon: Icons.videocam_rounded,
                        color: const Color(0xFFDC2626),
                        selected: _selectedFormat == 'Video',
                        isDark: isDark,
                        onTap: () => setState(() => _selectedFormat = 'Video'),
                      ),
                      const SizedBox(width: 8),
                      _formatPill(
                        label: 'Live',
                        icon: Icons.sensors_rounded,
                        color: const Color(0xFF7C3AED),
                        selected: _selectedFormat == 'Live',
                        isDark: isDark,
                        onTap: () => context.push('/live/start'),
                      ),
                      const SizedBox(width: 8),
                      _formatPill(
                        label: 'Poll',
                        icon: Icons.poll_rounded,
                        color: DesignTokens.primary,
                        selected: _selectedFormat == 'Poll',
                        isDark: isDark,
                        onTap: () => showPostComposer(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Media Carousel Attachments
                  if (_selectedMedia.isNotEmpty) ...[
                    SizedBox(
                      height: 90,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _selectedMedia.length + 1,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (ctx, i) {
                          if (i == _selectedMedia.length) {
                            return GestureDetector(
                              onTap: _pickMedia,
                              child: Container(
                                width: 80,
                                height: 90,
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E2638) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: borderColor),
                                ),
                                child: const Center(
                                  child: Icon(Icons.add_photo_alternate_rounded, color: DesignTokens.primary),
                                ),
                              ),
                            );
                          }
                          final f = _selectedMedia[i];
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  File(f.path),
                                  width: 80,
                                  height: 90,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () => setState(() => _selectedMedia.removeAt(i)),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Colors.black87,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 4,
                                left: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('0:45', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                  ] else ...[
                    GestureDetector(
                      onTap: _pickMedia,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E2638) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor, style: BorderStyle.solid),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.cloud_upload_outlined, size: 30, color: DesignTokens.primary),
                            const SizedBox(height: 6),
                            Text(
                              'Tap to upload photos or videos',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary),
                            ),
                            Text(
                              'Supports high-resolution images & short video reels',
                              style: TextStyle(fontSize: 10, color: textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Caption Input
                  TextField(
                    controller: _captionController,
                    maxLines: 4,
                    style: TextStyle(color: textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: "Write your caption, share insights, or add a hook...",
                      hintStyle: TextStyle(color: textSecondary, fontSize: 13),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E2638) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: DesignTokens.primary, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // AI Caption Generator & Hashtags
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: _aiGenerating ? null : _generateAiCaption,
                        icon: _aiGenerating
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5))
                            : const MurihIcon('Edit', size: 16, color: DesignTokens.primary),
                        label: Text(
                          _aiGenerating ? 'Generating...' : 'AI Caption Assistant',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: DesignTokens.primary),
                        ),
                      ),
                      Text(
                        '${_captionController.text.length} / 2,200',
                        style: TextStyle(fontSize: 11, color: textSecondary),
                      ),
                    ],
                  ),

                  // Suggested Hashtags Pills
                  SizedBox(
                    height: 32,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _suggestedHashtags.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 6),
                      itemBuilder: (ctx, i) {
                        final tag = _suggestedHashtags[i];
                        return GestureDetector(
                          onTap: () => _addHashtag(tag),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E2638) : const Color(0xFFE8F1FD),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              tag,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: DesignTokens.primary,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Divider(height: 1, color: borderColor),
                  const SizedBox(height: 12),

                  // Schedule Post Switch
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Schedule Post',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textPrimary),
                    ),
                    subtitle: Text(
                      _isScheduled
                          ? 'Publishing on ${_scheduledDate.day}/${_scheduledDate.month} at ${_scheduledDate.hour}:${_scheduledDate.minute.toString().padLeft(2, '0')}'
                          : 'Set custom time for peak audience discovery',
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                    value: _isScheduled,
                    activeThumbColor: DesignTokens.primary,
                    activeTrackColor: DesignTokens.primary.withValues(alpha: 0.4),
                    onChanged: (val) async {
                      if (val) {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: _scheduledDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 60)),
                        );
                        if (pickedDate == null || !context.mounted) return;
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(_scheduledDate),
                        );
                        if (pickedTime != null && context.mounted) {
                          setState(() {
                            _scheduledDate = DateTime(
                              pickedDate.year,
                              pickedDate.month,
                              pickedDate.day,
                              pickedTime.hour,
                              pickedTime.minute,
                            );
                            _isScheduled = true;
                          });
                          return;
                        }
                      }
                      setState(() => _isScheduled = val);
                    },
                  ),
                  const SizedBox(height: 14),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            _captionController.clear();
                            _selectedMedia.clear();
                            setState(() {});
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: borderColor),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            'Save Draft',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textPrimary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _isPublishing ? null : _submitPost,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: DesignTokens.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: _isPublishing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : Text(
                                  _isScheduled ? 'Schedule Post' : 'Publish Now',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 4. Scheduled Posts Timeline Card
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Upcoming Schedule',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text('Manage Calendar', style: TextStyle(color: DesignTokens.primary, fontWeight: FontWeight.w700, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            for (final sp in _scheduledPosts)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        sp['thumbnail'] as String,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sp['title'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textPrimary),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.schedule_rounded, size: 12, color: textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                sp['scheduledTime'] as String,
                                style: TextStyle(fontSize: 11, color: textSecondary),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: DesignTokens.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  sp['format'] as String,
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: DesignTokens.primary),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_vert_rounded, size: 18),
                      color: textSecondary,
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _toolCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: textPrimary),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formatPill({
    required String label,
    required IconData icon,
    required Color color,
    required bool selected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.15)
                : (isDark ? const Color(0xFF1E2638) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? color : Colors.transparent,
              width: 1.2,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: selected ? color : (isDark ? Colors.grey[400] : Colors.grey[600])),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? color : (isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
