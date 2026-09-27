import 'package:flutter/material.dart';

/// WhatsApp-style doodle backdrop for the conversation message area.
///
/// The source artwork (`assets/images/brand/chat_pattern.png`) is a single
/// light-blue ink on a fully transparent field, so it reads well on a dark
/// surface but would all but disappear on a light one. Rather than shipping two
/// copies of the asset, the ink is recoloured per theme with `BlendMode.srcIn`,
/// which keeps the drawing's alpha (and therefore its shape) while swapping the
/// colour for one that contrasts with the current background.
///
/// The pattern is deliberately very low opacity: it should read as texture
/// behind the message bubbles, never compete with message text.
class ChatPatternBackground extends StatelessWidget {
  const ChatPatternBackground({super.key, required this.child});

  /// The message list rendered on top of the pattern.
  final Widget child;

  static const String asset = 'assets/images/brand/chat_pattern.png';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      fit: StackFit.expand,
      children: [
        Opacity(
          opacity: isDark ? 0.10 : 0.07,
          child: Image.asset(
            asset,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            // srcIn keeps the artwork's alpha and replaces its hue, so a single
            // light-blue drawing works against both light and dark surfaces.
            color: isDark ? const Color(0xFF8FD8FF) : const Color(0xFF0B3A5B),
            colorBlendMode: BlendMode.srcIn,
          ),
        ),
        child,
      ],
    );
  }
}
