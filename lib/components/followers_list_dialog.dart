import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/follow_provider.dart';

/// Modal dialog showing Followers or Following users list with search & 1-tap follow actions.
class FollowersListDialog extends ConsumerStatefulWidget {
  final String title;
  final bool isFollowersList;

  const FollowersListDialog({
    super.key,
    required this.title,
    this.isFollowersList = true,
  });

  static void show(BuildContext context, {required String title, bool isFollowersList = true}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1C1C1E)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => FollowersListDialog(title: title, isFollowersList: isFollowersList),
    );
  }

  @override
  ConsumerState<FollowersListDialog> createState() => _FollowersListDialogState();
}

class _FollowersListDialogState extends ConsumerState<FollowersListDialog> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final followState = ref.watch(followProvider);
    final followNotifier = ref.read(followProvider.notifier);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

    final rawList = widget.isFollowersList
        ? followNotifier.getFollowersList(1)
        : followNotifier.getFollowingList(1);

    final filteredList = rawList.where((u) {
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return u.name.toLowerCase().contains(q) || u.username.toLowerCase().contains(q);
    }).toList();

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.65,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: textPrimary,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Search Bar
            TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: TextStyle(color: textPrimary),
              decoration: InputDecoration(
                hintText: 'Search ${widget.title.toLowerCase()}…',
                prefixIcon: const Icon(Icons.search_rounded),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 14),

            // Users List
            Expanded(
              child: filteredList.isEmpty
                  ? Center(
                      child: Text('No users found', style: TextStyle(color: textSecondary)),
                    )
                  : ListView.separated(
                      itemCount: filteredList.length,
                      separatorBuilder: (_, _) => const Divider(height: 1, indent: 64),
                      itemBuilder: (ctx, i) {
                        final user = filteredList[i];
                        final isFollowing = followState.isFollowing(user.userId);

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF007AFF).withValues(alpha: 0.15),
                            child: Text(
                              user.name.substring(0, 1).toUpperCase(),
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF007AFF)),
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(
                                user.name,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textPrimary),
                              ),
                              if (user.isVerified) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.verified_rounded, color: Color(0xFF007AFF), size: 16),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            '@${user.username} · ${user.bio}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: textSecondary),
                          ),
                          trailing: SizedBox(
                            height: 34,
                            child: isFollowing
                                ? OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: textSecondary,
                                      side: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                    ),
                                    onPressed: () => followNotifier.toggleFollow(user.userId),
                                    child: const Text('Following', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  )
                                : ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF007AFF),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(horizontal: 14),
                                    ),
                                    onPressed: () => followNotifier.toggleFollow(user.userId),
                                    child: const Text('Follow', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
