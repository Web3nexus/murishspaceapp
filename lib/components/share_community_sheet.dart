import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/api_client.dart';

class CommunityShareItem {
  final int id;
  final String name;
  final String slug;
  final String? logoUrl;
  final int membersCount;
  final String? description;

  const CommunityShareItem({
    required this.id,
    required this.name,
    required this.slug,
    this.logoUrl,
    this.membersCount = 0,
    this.description,
  });

  factory CommunityShareItem.fromJson(Map<String, dynamic> json) {
    return CommunityShareItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? 'Community',
      slug: json['slug']?.toString() ?? '',
      logoUrl: json['logo_url']?.toString() ?? json['avatar_url']?.toString(),
      membersCount: (json['members_count'] as num?)?.toInt() ??
          (json['members_count_cached'] as num?)?.toInt() ??
          0,
      description: json['description']?.toString(),
    );
  }
}

/// Modal bottom sheet allowing users to pick a community they created or joined
/// and share its interactive card into a direct or group chat.
class ShareCommunitySheet extends StatefulWidget {
  final ValueChanged<CommunityShareItem> onSelect;

  const ShareCommunitySheet({super.key, required this.onSelect});

  static Future<void> show(BuildContext context, {required ValueChanged<CommunityShareItem> onSelect}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShareCommunitySheet(onSelect: onSelect),
    );
  }

  @override
  State<ShareCommunitySheet> createState() => _ShareCommunitySheetState();
}

class _ShareCommunitySheetState extends State<ShareCommunitySheet> {
  List<CommunityShareItem> _communities = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchMyCommunities();
  }

  Future<void> _fetchMyCommunities() async {
    try {
      final res = await ApiClient.instance.dio.get('/communities/my');
      final payload = ApiClient.instance.unwrap(res);
      final rawList = payload is Map<String, dynamic>
          ? (payload['data'] is List ? payload['data'] : payload['communities'])
          : payload;

      if (rawList is List && mounted) {
        final parsed = rawList
            .whereType<Map<String, dynamic>>()
            .map(CommunityShareItem.fromJson)
            .toList();
        setState(() {
          _communities = parsed;
          _loading = false;
        });
        return;
      }
    } catch (_) {
      // Fallback: try public active communities
      try {
        final res = await ApiClient.instance.dio.get('/communities');
        final payload = ApiClient.instance.unwrap(res);
        final rawList = payload is Map<String, dynamic>
            ? (payload['data'] is List ? payload['data'] : payload['communities'])
            : payload;
        if (rawList is List && mounted) {
          final parsed = rawList
              .whereType<Map<String, dynamic>>()
              .map(CommunityShareItem.fromJson)
              .toList();
          setState(() {
            _communities = parsed;
            _loading = false;
          });
          return;
        }
      } catch (e) {
        if (mounted) setState(() => _error = 'Could not load communities');
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF34C759).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.groups_rounded, color: Color(0xFF34C759), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Share Community',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      'Select a community you joined or created to share',
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close_rounded, color: textSecondary, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Center(
                child: Text(_error!, style: const TextStyle(color: Color(0xFFFF3B30))),
              ),
            )
          else if (_communities.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.group_off_rounded, size: 42, color: textSecondary),
                    const SizedBox(height: 10),
                    Text(
                      'No communities found',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Join or create a community first to share it here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                  ],
                ),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _communities.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final c = _communities[i];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                    leading: CircleAvatar(
                      radius: 22,
                      backgroundColor: const Color(0xFF34C759).withValues(alpha: 0.15),
                      backgroundImage: c.logoUrl != null && c.logoUrl!.isNotEmpty
                          ? CachedNetworkImageProvider(c.logoUrl!)
                          : null,
                      child: c.logoUrl == null || c.logoUrl!.isEmpty
                          ? Text(
                              c.name.isNotEmpty ? c.name[0].toUpperCase() : 'C',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF34C759)),
                            )
                          : null,
                    ),
                    title: Text(
                      c.name,
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: textPrimary),
                    ),
                    subtitle: Text(
                      '${c.membersCount} members${c.description != null && c.description!.isNotEmpty ? " · ${c.description!}" : ""}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                    trailing: const Icon(Icons.send_rounded, size: 18, color: Color(0xFF007AFF)),
                    onTap: () {
                      Navigator.of(context).pop();
                      widget.onSelect(c);
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

