import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'api_client.dart';
import 'emoji_manifest.g.dart';

/// Full URL of an emoji's animated webp asset, or null when the pack has none.
String? emojiAssetUrl(String emoji) {
  final rel = kEmojiManifest[emoji];
  if (rel == null) return null;
  final encoded = rel.split('/').map(Uri.encodeComponent).join('/');
  return ApiClient.resolveUrl('/emoji/$encoded');
}

final RegExp _emojiRegExp = RegExp(
  '(${kEmojiKeys.map(RegExp.escape).join('|')})',
);

/// Splits [text] into [InlineSpan]s, swapping emoji for their animated image.
List<InlineSpan> buildEmojiSpans(String text, TextStyle style) {
  final spans = <InlineSpan>[];
  var last = 0;
  for (final m in _emojiRegExp.allMatches(text)) {
    if (m.start > last) {
      spans.add(TextSpan(text: text.substring(last, m.start), style: style));
    }
    final emoji = m.group(1)!;
    final size = (style.fontSize ?? 16) * 1.25;
    spans.add(
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: AnimatedEmoji(emoji: emoji, size: size),
      ),
    );
    last = m.end;
  }
  if (last < text.length) {
    spans.add(TextSpan(text: text.substring(last), style: style));
  }
  return spans;
}

/// Renders an emoji as its animated webp asset, falling back to the text glyph
/// whenever the pack has no asset for it.
class AnimatedEmoji extends StatelessWidget {
  final String emoji;
  final double size;
  final Color? fallbackColor;

  const AnimatedEmoji({
    super.key,
    required this.emoji,
    this.size = 20,
    this.fallbackColor,
  });

  @override
  Widget build(BuildContext context) {
    final url = emojiAssetUrl(emoji);
    final fallbackStyle = TextStyle(
      fontSize: size * 0.9,
      color: fallbackColor ?? Theme.of(context).textTheme.bodyMedium?.color,
    );

    if (url == null || url.isEmpty) {
      return Text(emoji, style: fallbackStyle);
    }

    return CachedNetworkImage(
      imageUrl: url,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorWidget: (_, _, _) => Text(emoji, style: fallbackStyle),
      placeholder: (_, _) => SizedBox(width: size, height: size),
    );
  }
}