import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/community_models.dart';

/// Creator Community Management Sheet: Members, Access Pricing (Free vs Paid), and Join Requests.
class CommunityManageSheet extends ConsumerStatefulWidget {
  final Community community;

  const CommunityManageSheet({super.key, required this.community});

  static void show(BuildContext context, Community community) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1C1C1E)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => CommunityManageSheet(community: community),
    );
  }

  @override
  ConsumerState<CommunityManageSheet> createState() => _CommunityManageSheetState();
}

class _CommunityManageSheetState extends ConsumerState<CommunityManageSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isPaid = false;
  final _priceCtrl = TextEditingController(text: '9.99');
  String _privacy = 'public';

  final List<Map<String, dynamic>> _pendingRequests = [
    {'id': 1, 'name': 'Daniel Craig', 'username': 'daniel_c', 'bio': 'Tech Enthusiast & Ambassador'},
    {'id': 2, 'name': 'Grace Hopper', 'username': 'grace_h', 'bio': 'Software Engineer & Dev'},
  ];

  final List<Map<String, dynamic>> _members = [
    {'id': 101, 'name': 'Alice Freeman', 'username': 'alice_f', 'role': 'Admin'},
    {'id': 102, 'name': 'Bob Smith', 'username': 'bob_s', 'role': 'Moderator'},
    {'id': 103, 'name': 'Charlie Brown', 'username': 'charlie_b', 'role': 'Member'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Row
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF007AFF).withValues(alpha: 0.15),
                  child: const Icon(Icons.groups_rounded, color: Color(0xFF007AFF)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Manage ${widget.community.name}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textPrimary)),
                      Text('Members, access pricing & join requests', style: TextStyle(fontSize: 12, color: textSecondary)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Tabs Header
            TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF007AFF),
              unselectedLabelColor: textSecondary,
              indicatorColor: const Color(0xFF007AFF),
              tabs: [
                Tab(text: 'Requests (${_pendingRequests.length})'),
                Tab(text: 'Members (${_members.length})'),
                const Tab(text: 'Pricing & Access'),
              ],
            ),
            const SizedBox(height: 12),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Pending Join Requests
                  _pendingRequests.isEmpty
                      ? Center(child: Text('No pending requests', style: TextStyle(color: textSecondary)))
                      : ListView.separated(
                          itemCount: _pendingRequests.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (ctx, idx) {
                            final req = _pendingRequests[idx];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFF007AFF).withValues(alpha: 0.15),
                                child: Text((req['name'] as String)[0], style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF007AFF))),
                              ),
                              title: Text(req['name'] as String, style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary)),
                              subtitle: Text('@${req['username']} · ${req['bio']}', style: TextStyle(fontSize: 12, color: textSecondary)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.close_rounded, color: Color(0xFFFF3B30)),
                                    onPressed: () => setState(() => _pendingRequests.removeAt(idx)),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.check_circle_rounded, color: Color(0xFF34C759)),
                                    onPressed: () {
                                      setState(() {
                                        _members.add({'id': req['id'], 'name': req['name'], 'username': req['username'], 'role': 'Member'});
                                        _pendingRequests.removeAt(idx);
                                      });
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('${req['name']} approved!')),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                  // Tab 2: Community Members
                  ListView.separated(
                    itemCount: _members.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (ctx, idx) {
                      final m = _members[idx];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF5856D6).withValues(alpha: 0.15),
                          child: Text((m['name'] as String)[0], style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF5856D6))),
                        ),
                        title: Text(m['name'] as String, style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary)),
                        subtitle: Text('@${m['username']}', style: TextStyle(fontSize: 12, color: textSecondary)),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF007AFF).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(m['role'] as String, style: const TextStyle(color: Color(0xFF007AFF), fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                      );
                    },
                  ),

                  // Tab 3: Access & Subscription Pricing (Free vs Paid)
                  ListView(
                    children: [
                      SwitchListTile(
                        title: Text('Paid Membership Subscription', style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary)),
                        subtitle: Text('Require users to pay a monthly fee to join', style: TextStyle(fontSize: 12, color: textSecondary)),
                        value: _isPaid,
                        activeColor: const Color(0xFF007AFF),
                        onChanged: (val) => setState(() => _isPaid = val),
                      ),
                      if (_isPaid) ...[
                        const SizedBox(height: 10),
                        TextField(
                          controller: _priceCtrl,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            prefixText: r'$ ',
                            labelText: 'Monthly Subscription Price',
                            hintText: 'e.g. 9.99',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      DropdownButtonFormField<String>(
                        value: _privacy,
                        decoration: InputDecoration(
                          labelText: 'Community Privacy',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'public', child: Text('Public (Anyone can join instantly)')),
                          DropdownMenuItem(value: 'private', child: Text('Private (Creator approval required)')),
                        ],
                        onChanged: (val) => setState(() => _privacy = val ?? 'public'),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF007AFF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Community membership & pricing updated!')),
                            );
                          },
                          child: const Text('Save Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                      ),
                    ],
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
