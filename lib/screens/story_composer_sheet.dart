import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/story_provider.dart';

/// Opens the 24-Hour Disappearing Story Composer Sheet.
void showStoryComposerSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _StoryComposerContent(),
  );
}

class _StoryComposerContent extends ConsumerStatefulWidget {
  const _StoryComposerContent();

  @override
  ConsumerState<_StoryComposerContent> createState() => _StoryComposerContentState();
}

class _StoryComposerContentState extends ConsumerState<_StoryComposerContent> {
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedMedia;
  String _sampleMediaUrl = 'https://picsum.photos/seed/story_new/600/1000';
  final TextEditingController _captionController = TextEditingController();
  bool _isUploading = false;
  String _privacyTarget = 'Friends & Communities';

  final List<String> _sampleBackgrounds = [
    'https://picsum.photos/seed/story_new/600/1000',
    'https://picsum.photos/seed/nature_sky/600/1000',
    'https://picsum.photos/seed/city_lights/600/1000',
    'https://picsum.photos/seed/tech_setup/600/1000',
    'https://picsum.photos/seed/art_abstract/600/1000',
  ];

  Future<void> _pickImage(ImageSource source) async {
    try {
      final image = await _picker.pickImage(
        source: source,
        maxWidth: 1080,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _selectedMedia = image;
        });
      }
    } catch (_) {
      // Fallback to sample photo if permission denied or desktop emulator
    }
  }

  Future<void> _publishStory() async {
    if (_isUploading) return;
    setState(() => _isUploading = true);

    final mediaUrl = _selectedMedia != null
        ? _selectedMedia!.path
        : _sampleMediaUrl;

    final caption = _captionController.text.trim();

    final success = await ref.read(storyProvider.notifier).addStory(
          mediaUrl: mediaUrl,
          caption: caption.isNotEmpty ? caption : null,
        );

    if (mounted) {
      Navigator.pop(context);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your 24h story has been published to your friends & communities! ✨'),
            backgroundColor: Color(0xFF34C759),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mediaQuery = MediaQuery.of(context);

    return Container(
      height: mediaQuery.size.height * 0.92,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[700] : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
                Column(
                  children: [
                    const Text(
                      'Disappearing Story',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                    Text(
                      'Disappears in 24 hours',
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: _isUploading ? null : _publishStory,
                  child: _isUploading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Share',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: Color(0xFF007AFF),
                          ),
                        ),
                ),
              ],
            ),
          ),

          // Target Privacy Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : Colors.grey[200],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.people_alt_rounded, size: 14, color: Color(0xFF007AFF)),
                const SizedBox(width: 6),
                Text(
                  'Visible to: $_privacyTarget',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Story Media Canvas Preview
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Stack(
                children: [
                  // Image Display
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: SizedBox(
                      width: double.infinity,
                      height: double.infinity,
                      child: _selectedMedia != null
                          ? (kIsWeb
                              ? Image.network(_selectedMedia!.path, fit: BoxFit.cover)
                              : Image.file(File(_selectedMedia!.path), fit: BoxFit.cover))
                          : Image.network(
                              _sampleMediaUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.purple[900],
                                child: const Center(
                                  child: Icon(Icons.photo_rounded, size: 64, color: Colors.white),
                                ),
                              ),
                            ),
                    ),
                  ),

                  // Overlay Gradient for text readability
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.3),
                            Colors.transparent,
                            Colors.black.withOpacity(0.65),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Pick Controls Floating Top-Right
                  Positioned(
                    top: 14,
                    right: 14,
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.black.withOpacity(0.5),
                          child: IconButton(
                            icon: const Icon(Icons.photo_library_rounded, color: Colors.white, size: 20),
                            onPressed: () => _pickImage(ImageSource.gallery),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          backgroundColor: Colors.black.withOpacity(0.5),
                          child: IconButton(
                            icon: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
                            onPressed: () => _pickImage(ImageSource.camera),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Caption Input Overlay at Bottom
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Preset backgrounds selector if using sample image
                        if (_selectedMedia == null) ...[
                          const Text(
                            'Select Background Preset:',
                            style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            height: 44,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _sampleBackgrounds.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 8),
                              itemBuilder: (ctx, i) {
                                final url = _sampleBackgrounds[i];
                                final isSel = _sampleMediaUrl == url;
                                return GestureDetector(
                                  onTap: () => setState(() => _sampleMediaUrl = url),
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSel ? const Color(0xFF007AFF) : Colors.white,
                                        width: isSel ? 3 : 1.5,
                                      ),
                                    ),
                                    child: ClipOval(
                                      child: Image.network(url, fit: BoxFit.cover),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Caption TextField
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.65),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white30, width: 1),
                          ),
                          child: TextField(
                            controller: _captionController,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                            maxLines: 3,
                            minLines: 1,
                            decoration: const InputDecoration(
                              hintText: 'Add a caption or status note...',
                              hintStyle: TextStyle(color: Colors.white60, fontSize: 14),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              focusedErrorBorder: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              isDense: false,
                              filled: false,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
