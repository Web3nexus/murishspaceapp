import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/story_models.dart';
import '../providers/story_provider.dart';

/// Interactive Full-Screen Disappearing Story Viewer.
class StoryViewerScreen extends ConsumerStatefulWidget {
  final UserStoryGroup group;

  const StoryViewerScreen({
    super.key,
    required this.group,
  });

  @override
  ConsumerState<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends ConsumerState<StoryViewerScreen> {
  int _currentIndex = 0;
  Timer? _progressTimer;
  double _currentProgress = 0.0;
  final TextEditingController _replyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _replyController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _progressTimer?.cancel();
    _currentProgress = 0.0;

    if (widget.group.stories.isEmpty) return;

    // Mark active story segment as seen safely after frame completes
    final activeStory = widget.group.stories[_currentIndex];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(storyProvider.notifier).markStorySeen(widget.group.userId, activeStory.id);
      }
    });

    const tick = Duration(milliseconds: 50);
    const totalTicks = 100; // 5 seconds (50ms * 100)

    _progressTimer = Timer.periodic(tick, (timer) {
      if (!mounted) return;
      setState(() {
        _currentProgress += 1 / totalTicks;
        if (_currentProgress >= 1.0) {
          _advanceNextSegment();
        }
      });
    });
  }

  void _advanceNextSegment() {
    if (_currentIndex < widget.group.stories.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _startTimer();
    } else {
      _progressTimer?.cancel();
      Navigator.pop(context);
    }
  }

  void _previousSegment() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _startTimer();
    } else {
      _startTimer();
    }
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  void _sendReply() {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;

    _replyController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Reply sent to ${widget.group.userName}'),
        backgroundColor: const Color(0xFF007AFF),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.group.stories.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No active stories segment', style: TextStyle(color: Colors.white)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      );
    }

    final story = widget.group.stories[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! > 300) {
            Navigator.pop(context);
          }
        },
        child: Stack(
          children: [
            // Story Media Image Layer
            Positioned.fill(
              child: Image.network(
                story.mediaUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.purple[950],
                  child: const Center(
                    child: Icon(Icons.broken_image_rounded, size: 64, color: Colors.white54),
                  ),
                ),
              ),
            ),

            // Gradient Overlays for readability
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withOpacity(0.85),
                    ],
                    stops: const [0.0, 0.25, 0.7, 1.0],
                  ),
                ),
              ),
            ),

            // Tap gesture detectors for Prev / Next segment navigation
            Positioned.fill(
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: _previousSegment,
                      child: const SizedBox.expand(),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: _advanceNextSegment,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ],
              ),
            ),

            // Top-to-Bottom Controls Overlay Layer (Header at Top, Spacer in middle, Reply/Caption at Bottom)
            Positioned.fill(
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      // Top Progress Bars & Author Header Section
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Segment Progress Indicators
                          Row(
                            children: List.generate(widget.group.stories.length, (idx) {
                              double val = 0.0;
                              if (idx < _currentIndex) {
                                val = 1.0;
                              } else if (idx == _currentIndex) {
                                val = _currentProgress;
                              } else {
                                val = 0.0;
                              }

                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 2),
                                  child: LinearProgressIndicator(
                                    value: val.clamp(0.0, 1.0),
                                    backgroundColor: Colors.white30,
                                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                    minHeight: 3,
                                  ),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 12),

                          // Author Header Row
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: const Color(0xFF007AFF),
                                backgroundImage: widget.group.userAvatar != null
                                    ? NetworkImage(widget.group.userAvatar!)
                                    : null,
                                child: widget.group.userAvatar == null
                                    ? Text(
                                        widget.group.userName[0].toUpperCase(),
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                                        Text(
                                          widget.group.userName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 14,
                                          ),
                                        ),
                                        if (widget.group.isCommunity) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF5856D6),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              'COMMUNITY',
                                              style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    Text(
                                      '${_formatTimeAgo(story.createdAt)} · Status',
                                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Spacer forces all bottom controls down to the absolute bottom of the screen!
                      const Spacer(),

                      // Bottom Section: Caption & Reply Input Bar
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Caption Note if present
                          if (story.caption != null && story.caption!.isNotEmpty) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.65),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Text(
                                story.caption!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  height: 1.3,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],

                          // Reply Input Field for Friends / Viewers Counter for My Story
                          if (widget.group.isMyStory)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.65),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.remove_red_eye_rounded, color: Colors.white70, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${story.viewsCount} Viewers',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ],
                              ),
                            )
                          else
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.65),
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(color: Colors.white30, width: 1),
                                    ),
                                    child: TextField(
                                      controller: _replyController,
                                      style: const TextStyle(color: Colors.white, fontSize: 14),
                                      decoration: InputDecoration(
                                        hintText: 'Send reply to ${widget.group.userName}...',
                                        hintStyle: const TextStyle(color: Colors.white60, fontSize: 13),
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        errorBorder: InputBorder.none,
                                        focusedErrorBorder: InputBorder.none,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        isDense: false,
                                        filled: false,
                                      ),
                                      onSubmitted: (_) => _sendReply(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: const Color(0xFF007AFF),
                                  child: IconButton(
                                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                                    onPressed: _sendReply,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
