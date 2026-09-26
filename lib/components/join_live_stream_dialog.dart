import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/api_client.dart';

/// Modal dialog for discovering and joining active live broadcasts.
///
/// Designed specifically for viewers and members who want to watch live
/// streams without hosting.
class JoinLiveStreamDialog extends ConsumerStatefulWidget {
  const JoinLiveStreamDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const JoinLiveStreamDialog(),
    );
  }

  @override
  ConsumerState<JoinLiveStreamDialog> createState() =>
      _JoinLiveStreamDialogState();
}

class _JoinLiveStreamDialogState extends ConsumerState<JoinLiveStreamDialog> {
  final _inputCtrl = TextEditingController();
  bool _loadingStreams = true;
  String? _error;
  List<Map<String, dynamic>> _liveStreams = [];

  @override
  void initState() {
    super.initState();
    _fetchActiveStreams();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchActiveStreams() async {
    setState(() {
      _loadingStreams = true;
      _error = null;
    });

    try {
      final res = await ApiClient.instance.dio.get('/livestreams');
      final raw = ApiClient.instance.unwrap(res);
      List<dynamic> items = [];
      if (raw is List) {
        items = raw;
      } else if (raw is Map && raw['data'] is List) {
        items = raw['data'] as List;
      }

      if (mounted) {
        setState(() {
          _liveStreams = items
              .whereType<Map<String, dynamic>>()
              .where((s) => s['status'] == 'live' || s['status'] == null)
              .toList();
          _loadingStreams = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingStreams = false;
        });
      }
    }
  }

  void _joinByCodeOrLink() {
    final raw = _inputCtrl.text.trim();
    final clean = raw
        .replaceAll(RegExp(r'^https?://[^/]+/live/'), '')
        .replaceAll(RegExp(r'^/live/'), '')
        .replaceAll(RegExp(r'^#/live/'), '')
        .trim();

    if (clean.isEmpty) {
      setState(() => _error = 'Please enter a valid live stream code or link.');
      return;
    }

    Navigator.pop(context);
    context.push('/live/$clean');
  }

  void _watchStream(Map<String, dynamic> stream) {
    Navigator.pop(context);

    final streamId = (stream['id'] as num?)?.toInt();
    final title = (stream['title']?.toString() ?? 'Live Broadcast').trim();
    final host = stream['host'] as Map<String, dynamic>?;
    final hostName = (host?['name']?.toString() ?? 'Creator').trim();
    final community = stream['community'] as Map<String, dynamic>?;
    final communityName = community?['name']?.toString();
    final trackingId = stream['tracking_id']?.toString();

    final query = <String, String>{
      if (streamId != null) 'streamId': '$streamId',
      if (trackingId != null && trackingId.isNotEmpty) 'trackingId': trackingId,
      'title': title.isNotEmpty ? title : 'Live Broadcast',
      'hostName': hostName.isNotEmpty ? hostName : 'Creator',
      'isHost': 'false',
      if (communityName != null && communityName.isNotEmpty)
        'communityName': communityName,
    };

    final encoded = query.entries
        .map(
          (e) =>
              '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}',
        )
        .join('&');

    context.push('/app/live?$encoded');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF161B22) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final cardBg = isDark ? const Color(0xFF1F2733) : const Color(0xFFF8FAFC);
    final borderColor =
        isDark ? const Color(0xFF263242) : const Color(0xFFE2E8F0);
    final inputFill =
        isDark ? const Color(0xFF121720) : const Color(0xFFF1F5F9);

    final mediaQuery = MediaQuery.of(context);
    final maxHeight = mediaQuery.size.height * 0.85;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: borderColor),
      ),
      padding: EdgeInsets.only(
        bottom: mediaQuery.viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF2D55).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFFF2D55).withValues(alpha: 0.35),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.live_tv_rounded,
                            size: 14, color: Color(0xFFFF2D55)),
                        SizedBox(width: 4),
                        Text(
                          'LIVE',
                          style: TextStyle(
                            color: Color(0xFFFF2D55),
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Join Live Stream',
                          style: TextStyle(
                            color: textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                        Text(
                          'Watch ongoing broadcasts as audience',
                          style: TextStyle(color: textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.close_rounded,
                        color: textSecondary, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: borderColor),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Code or Link Input Card
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
                          Text(
                            'Enter Stream Code or Link',
                            style: TextStyle(
                              color: textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _inputCtrl,
                            style: TextStyle(color: textPrimary, fontSize: 13),
                            textInputAction: TextInputAction.go,
                            onSubmitted: (_) => _joinByCodeOrLink(),
                            decoration: InputDecoration(
                              hintText: 'e.g. live_... or paste full link',
                              hintStyle: TextStyle(
                                color: textSecondary.withValues(alpha: 0.7),
                                fontSize: 12.5,
                              ),
                              prefixIcon: Icon(Icons.link_rounded,
                                  color: textSecondary, size: 18),
                              suffixIcon: TextButton.icon(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10),
                                  foregroundColor: const Color(0xFF007AFF),
                                  textStyle: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                icon: const Icon(Icons.content_paste_rounded,
                                    size: 13),
                                label: const Text('Paste'),
                                onPressed: () async {
                                  final data = await Clipboard.getData(
                                      Clipboard.kTextPlain);
                                  if (data?.text != null &&
                                      data!.text!.trim().isNotEmpty) {
                                    setState(() {
                                      _inputCtrl.text = data.text!.trim();
                                    });
                                  }
                                },
                              ),
                              isDense: true,
                              filled: true,
                              fillColor: inputFill,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
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
                                borderSide: const BorderSide(
                                    color: Color(0xFFFF2D55), width: 1.5),
                              ),
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _error!,
                              style: const TextStyle(
                                color: Color(0xFFFF3B30),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFFF2D55),
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _joinByCodeOrLink,
                              icon: const Icon(Icons.play_arrow_rounded,
                                  size: 18),
                              label: const Text(
                                'Watch Stream',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    // Active Broadcasts Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Ongoing Live Streams',
                          style: TextStyle(
                            color: textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Refresh',
                          icon: Icon(Icons.refresh_rounded,
                              color: textSecondary, size: 18),
                          onPressed: _fetchActiveStreams,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (_loadingStreams)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5, color: Color(0xFFFF2D55)),
                              ),
                              const SizedBox(height: 10),
                              Text('Searching for live broadcasts…',
                                  style: TextStyle(
                                      color: textSecondary, fontSize: 12)),
                            ],
                          ),
                        ),
                      )
                    else if (_liveStreams.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 24),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.sensors_off_rounded,
                                color: textSecondary.withValues(alpha: 0.6),
                                size: 36),
                            const SizedBox(height: 10),
                            Text(
                              'No public live streams right now',
                              style: TextStyle(
                                color: textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Creators currently aren\'t broadcasting publicly. Enter an invite link above to join private broadcasts.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 11.5,
                                  height: 1.35),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _liveStreams.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final stream = _liveStreams[index];
                          final host = stream['host'] as Map<String, dynamic>?;
                          final hostName = host?['name']?.toString() ?? 'Creator';
                          final hostAvatar = host?['avatar']?.toString();
                          final streamTitle =
                              stream['title']?.toString() ?? 'Live Broadcast';
                          final viewers = stream['viewers_count'] ?? 0;
                          final community =
                              stream['community'] as Map<String, dynamic>?;
                          final communityName = community?['name']?.toString();

                          return InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _watchStream(stream),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: borderColor),
                              ),
                              child: Row(
                                children: [
                                  Stack(
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor: const Color(0xFFFF2D55)
                                            .withValues(alpha: 0.15),
                                        backgroundImage: (hostAvatar != null &&
                                                hostAvatar.isNotEmpty)
                                            ? NetworkImage(hostAvatar)
                                            : null,
                                        child: (hostAvatar == null ||
                                                hostAvatar.isEmpty)
                                            ? Text(
                                                (hostName.isNotEmpty
                                                        ? hostName[0]
                                                        : 'C')
                                                    .toUpperCase(),
                                                style: const TextStyle(
                                                  color: Color(0xFFFF2D55),
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 14,
                                                ),
                                              )
                                            : null,
                                      ),
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF34C759),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                                color: bg, width: 1.5),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          streamTitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: textPrimary,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Text(
                                              hostName,
                                              style: TextStyle(
                                                color: textSecondary,
                                                fontSize: 11,
                                              ),
                                            ),
                                            if (communityName != null) ...[
                                              Text(' · ',
                                                  style: TextStyle(
                                                      color: textSecondary,
                                                      fontSize: 11)),
                                              Flexible(
                                                child: Text(
                                                  communityName,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Color(0xFF007AFF),
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF2D55)
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.visibility_rounded,
                                            size: 11,
                                            color: Color(0xFFFF2D55)),
                                        const SizedBox(width: 3),
                                        Text(
                                          '$viewers',
                                          style: const TextStyle(
                                            color: Color(0xFFFF2D55),
                                            fontWeight: FontWeight.w800,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.arrow_forward_ios_rounded,
                                      size: 12, color: Colors.grey),
                                ],
                              ),
                            ),
                          );
                        },
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
