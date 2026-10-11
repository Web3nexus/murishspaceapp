import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/design_tokens.dart';
import '../models/live_models.dart';

/// A single live broadcast tile used by both the home "Live Now" rail and the
/// discovery grid. The backend exposes no thumbnail column, so the card renders
/// branded placeholder art derived from the host identity instead of faking
/// imagery that does not exist.
class LiveStreamCard extends StatelessWidget {
  final LiveStream stream;
  final VoidCallback onTap;

  const LiveStreamCard({
    super.key,
    required this.stream,
    required this.onTap,
  });

  static const List<List<Color>> _gradients = [
    [Color(0xFF102840), Color(0xFF1E4E77)],
    [Color(0xFF0E5C85), Color(0xFF38A8D8)],
    [Color(0xFF1B2A4A), Color(0xFF5856D6)],
  ];

  List<Color> get _gradient => _gradients[stream.id.abs() % _gradients.length];

  IconData get _modeIcon {
    switch (stream.streamMode) {
      case 'audio':
        return Icons.mic_rounded;
      case 'meeting':
        return Icons.groups_rounded;
      default:
        return Icons.videocam_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hostName = stream.host?.name ?? 'Creator';
    final avatarUrl = ApiClient.resolveUrl(stream.host?.avatarUrl);
    final communityName = stream.community?.name;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(DesignTokens.rLg),
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Center(
              child: Icon(
                _modeIcon,
                size: 46,
                color: Colors.white.withValues(alpha: 0.18),
              ),
            ),
            // Bottom scrim keeps the caption legible over any art.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0x00000000), Color(0xCC000000)],
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _LivePill(),
                      const SizedBox(width: 6),
                      _CountPill(
                        icon: Icons.remove_red_eye_rounded,
                        value: stream.viewersCount,
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      _Avatar(url: avatarUrl, name: hostName, size: 26),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              hostName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (communityName != null &&
                                communityName.isNotEmpty)
                              Text(
                                communityName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.72),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    stream.title.isEmpty ? 'Live on MurihSpace' : stream.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LivePill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: DesignTokens.danger,
        borderRadius: BorderRadius.circular(DesignTokens.rPill),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 6,
            height: 6,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
          SizedBox(width: 4),
          Text(
            'LIVE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  final IconData icon;
  final int value;

  const _CountPill({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(DesignTokens.rPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            _compact(value),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? url;
  final String name;
  final double size;

  const _Avatar({this.url, required this.name, this.size = 26});

  String get _initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = url != null && url!.isNotEmpty;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: DesignTokens.primary,
        border: Border.all(color: Colors.white, width: 1.5),
        image: hasImage
            ? DecorationImage(image: NetworkImage(url!), fit: BoxFit.cover)
            : null,
      ),
      alignment: Alignment.center,
      child: hasImage
          ? null
          : Text(
              _initials,
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.4,
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }
}

String _compact(int value) {
  if (value >= 1000000) {
    final m = value / 1000000;
    return '${m.toStringAsFixed(m >= 10 ? 0 : 1)}M';
  }
  if (value >= 1000) {
    final k = value / 1000;
    return '${k.toStringAsFixed(k >= 10 ? 0 : 1)}k';
  }
  return '$value';
}
