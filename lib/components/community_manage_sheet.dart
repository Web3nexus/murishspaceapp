import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../core/api_client.dart';
import '../models/community_models.dart';
import '../providers/community_provider.dart';

/// Creator Community Management Sheet: Members, Access Pricing (Free vs Paid), Join Requests, and Branding.
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

  // Requests state
  bool _loadingRequests = true;
  List<Map<String, dynamic>> _pendingRequests = [];

  // Members state
  bool _loadingMembers = true;
  List<Map<String, dynamic>> _members = [];

  // Pricing & Access state
  late bool _isPaid;
  late TextEditingController _priceCtrl;
  late String _visibility;
  bool _isSavingPricing = false;

  // Branding state
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _categoryCtrl;
  String? _logoUrl;
  String? _coverUrl;
  bool _isUploadingLogo = false;
  bool _isUploadingCover = false;
  bool _isSavingBranding = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    _isPaid = widget.community.pricingType == 'paid';
    _priceCtrl = TextEditingController(text: (widget.community.priceAmount ?? 50).toInt().toString());
    _visibility = widget.community.visibility;

    _nameCtrl = TextEditingController(text: widget.community.name);
    _descCtrl = TextEditingController(text: widget.community.description ?? '');
    _categoryCtrl = TextEditingController(text: widget.community.category);
    _logoUrl = widget.community.logoUrl;
    _coverUrl = widget.community.coverUrl;

    _loadRequests();
    _loadMembers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _priceCtrl.dispose();
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _categoryCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRequests() async {
    setState(() => _loadingRequests = true);
    try {
      final res = await ApiClient.instance.dio.get('/communities/${widget.community.id}/requests');
      final payload = res.data;
      final rawList = payload is Map<String, dynamic> ? (payload['requests'] ?? payload['data']) : payload;
      if (mounted) {
        setState(() {
          _pendingRequests = rawList is List ? rawList.whereType<Map<String, dynamic>>().toList() : [];
          _loadingRequests = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingRequests = false);
    }
  }

  Future<void> _loadMembers() async {
    setState(() => _loadingMembers = true);
    try {
      final res = await ApiClient.instance.dio.get('/communities/${widget.community.id}/members');
      final payload = res.data;
      final rawList = payload is Map<String, dynamic> ? (payload['data'] is List ? payload['data'] : payload['data']?['data']) : payload;
      if (mounted) {
        setState(() {
          _members = rawList is List ? rawList.whereType<Map<String, dynamic>>().toList() : [];
          _loadingMembers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMembers = false);
    }
  }

  Future<void> _approveRequest(int membershipId, String applicantName, int idx) async {
    try {
      await ApiClient.instance.dio.post('/memberships/$membershipId/approve');
      if (mounted) {
        setState(() => _pendingRequests.removeAt(idx));
        _loadMembers();
        ref.invalidate(myCommunitiesProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Accepted $applicantName into ${widget.community.name}!')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not approve join request.')),
        );
      }
    }
  }

  Future<void> _rejectRequest(int membershipId, int idx) async {
    try {
      await ApiClient.instance.dio.post('/memberships/$membershipId/reject');
      if (mounted) {
        setState(() => _pendingRequests.removeAt(idx));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Join request declined.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not decline request.')),
        );
      }
    }
  }

  Future<void> _removeMember(int userId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove $name?'),
        content: Text('Are you sure you want to remove $name from ${widget.community.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ApiClient.instance.dio.delete('/communities/${widget.community.id}/members/$userId');
      if (mounted) {
        _loadMembers();
        ref.invalidate(myCommunitiesProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name removed from community.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not remove member.')),
        );
      }
    }
  }

  Future<void> _updateMemberRole(int userId, String newRole, String name) async {
    try {
      await ApiClient.instance.dio.put('/communities/${widget.community.id}/members/$userId/role', data: {
        'role': newRole,
      });
      if (mounted) {
        _loadMembers();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name role updated to ${newRole.toUpperCase()}!')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update member role.')),
        );
      }
    }
  }

  Future<void> _savePricing() async {
    setState(() => _isSavingPricing = true);
    try {
      await ApiClient.instance.dio.put('/my-communities/${widget.community.id}', data: {
        'pricing_type': _isPaid ? 'paid' : 'free',
        'price_amount': _isPaid ? (double.tryParse(_priceCtrl.text) ?? 50) : null,
        'visibility': _visibility,
      });
      if (mounted) {
        setState(() => _isSavingPricing = false);
        ref.invalidate(myCommunitiesProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pricing & Access settings saved!')),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSavingPricing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save pricing settings.')),
        );
      }
    }
  }

  Future<void> _pickAndUploadPhoto({required bool isLogo}) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: isLogo ? 600 : 1600,
      );
      if (picked == null) return;

      setState(() {
        if (isLogo) _isUploadingLogo = true;
        else _isUploadingCover = true;
      });

      final bytes = await picked.readAsBytes();
      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: picked.name),
        'folder': isLogo ? 'community_logos' : 'community_banners',
      });

      final res = await ApiClient.instance.dio.post('/upload', data: form);
      final payload = res.data;
      final uploadedUrl = payload is Map<String, dynamic>
          ? (payload['data']?['url'] ?? payload['url'])
          : null;

      if (mounted && uploadedUrl is String && uploadedUrl.isNotEmpty) {
        setState(() {
          if (isLogo) {
            _logoUrl = uploadedUrl;
            _isUploadingLogo = false;
          } else {
            _coverUrl = uploadedUrl;
            _isUploadingCover = false;
          }
        });
      } else {
        setState(() {
          if (isLogo) _isUploadingLogo = false;
          else _isUploadingCover = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          if (isLogo) _isUploadingLogo = false;
          else _isUploadingCover = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not upload photo. Please try again.')),
        );
      }
    }
  }

  Future<void> _saveBranding() async {
    setState(() => _isSavingBranding = true);
    try {
      await ApiClient.instance.dio.put('/my-communities/${widget.community.id}', data: {
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'category': _categoryCtrl.text.trim().isEmpty ? 'General' : _categoryCtrl.text.trim(),
        'logo_url': _logoUrl,
        'cover_url': _coverUrl,
      });
      if (mounted) {
        setState(() => _isSavingBranding = false);
        ref.invalidate(myCommunitiesProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Community details & branding updated!')),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSavingBranding = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save branding details.')),
        );
      }
    }
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
        height: MediaQuery.of(context).size.height * 0.82,
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

            // Header Row
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF007AFF).withOpacity(0.15),
                  backgroundImage: _logoUrl != null ? NetworkImage(_logoUrl!) : null,
                  child: _logoUrl == null
                      ? const Icon(Icons.groups_rounded, color: Color(0xFF007AFF))
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Manage ${widget.community.name}',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text('Members, access pricing, requests & branding', style: TextStyle(fontSize: 12, color: textSecondary)),
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
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: const Color(0xFF007AFF),
              unselectedLabelColor: textSecondary,
              indicatorColor: const Color(0xFF007AFF),
              tabs: [
                Tab(text: 'Requests (${_pendingRequests.length})'),
                Tab(text: 'Members (${_members.length})'),
                const Tab(text: 'Pricing & Access'),
                const Tab(text: 'Edit Branding'),
              ],
            ),
            const SizedBox(height: 14),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Live Join Requests
                  _loadingRequests
                      ? const Center(child: CircularProgressIndicator())
                      : (_pendingRequests.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.mark_email_read_rounded, size: 44, color: textSecondary),
                                  const SizedBox(height: 8),
                                  Text('No pending join requests', style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary)),
                                  Text('New join requests will appear here.', style: TextStyle(fontSize: 12, color: textSecondary)),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: _pendingRequests.length,
                              separatorBuilder: (_, _) => const Divider(height: 1),
                              itemBuilder: (ctx, idx) {
                                final req = _pendingRequests[idx];
                                final u = req['user'] as Map<String, dynamic>? ?? {};
                                final name = u['name']?.toString() ?? 'User';
                                final username = u['username']?.toString() ?? '';
                                final avatar = u['avatar']?.toString();
                                final bio = u['bio']?.toString() ?? '';
                                final membershipId = (req['id'] as num?)?.toInt() ?? 0;

                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(
                                    backgroundColor: const Color(0xFF007AFF).withOpacity(0.15),
                                    backgroundImage: avatar != null && avatar.isNotEmpty ? NetworkImage(avatar) : null,
                                    child: avatar == null || avatar.isEmpty
                                        ? Text(name.isNotEmpty ? name[0] : 'U', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF007AFF)))
                                        : null,
                                  ),
                                  title: Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary)),
                                  subtitle: Text(
                                    '@$username${bio.isNotEmpty ? ' · $bio' : ''}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 12, color: textSecondary),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.close_rounded, color: Color(0xFFFF3B30)),
                                        tooltip: 'Decline',
                                        onPressed: () => _rejectRequest(membershipId, idx),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.check_circle_rounded, color: Color(0xFF34C759)),
                                        tooltip: 'Approve',
                                        onPressed: () => _approveRequest(membershipId, name, idx),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            )),

                  // Tab 2: Live Community Members List
                  _loadingMembers
                      ? const Center(child: CircularProgressIndicator())
                      : (_members.isEmpty
                          ? Center(child: Text('No members found', style: TextStyle(color: textSecondary)))
                          : ListView.separated(
                              itemCount: _members.length,
                              separatorBuilder: (_, _) => const Divider(height: 1),
                              itemBuilder: (ctx, idx) {
                                final m = _members[idx];
                                final u = m['user'] as Map<String, dynamic>? ?? {};
                                final userId = (u['id'] as num?)?.toInt() ?? (m['user_id'] as num?)?.toInt() ?? 0;
                                final name = u['name']?.toString() ?? 'Member';
                                final username = u['username']?.toString() ?? '';
                                final avatar = u['avatar']?.toString();
                                final role = (m['role']?.toString() ?? 'member').toUpperCase();
                                final isOwner = userId == widget.community.userId;

                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(
                                    backgroundColor: const Color(0xFF5856D6).withOpacity(0.15),
                                    backgroundImage: avatar != null && avatar.isNotEmpty ? NetworkImage(avatar) : null,
                                    child: avatar == null || avatar.isEmpty
                                        ? Text(name.isNotEmpty ? name[0] : 'M', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF5856D6)))
                                        : null,
                                  ),
                                  title: Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary)),
                                  subtitle: Text('@$username', style: TextStyle(fontSize: 12, color: textSecondary)),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isOwner
                                              ? const Color(0xFFFF9500).withOpacity(0.15)
                                              : const Color(0xFF007AFF).withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          isOwner ? 'OWNER' : role,
                                          style: TextStyle(
                                            color: isOwner ? const Color(0xFFFF9500) : const Color(0xFF007AFF),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                      if (!isOwner) ...[
                                        const SizedBox(width: 4),
                                        PopupMenuButton<String>(
                                          icon: Icon(Icons.more_vert_rounded, size: 18, color: textSecondary),
                                          onSelected: (action) {
                                            if (action == 'remove') {
                                              _removeMember(userId, name);
                                            } else if (action == 'moderator') {
                                              _updateMemberRole(userId, 'moderator', name);
                                            } else if (action == 'member') {
                                              _updateMemberRole(userId, 'member', name);
                                            }
                                          },
                                          itemBuilder: (_) => [
                                            const PopupMenuItem(
                                              value: 'moderator',
                                              child: Text('Promote to Moderator'),
                                            ),
                                            const PopupMenuItem(
                                              value: 'member',
                                              child: Text('Set as Member'),
                                            ),
                                            const PopupMenuItem(
                                              value: 'remove',
                                              child: Text('Remove from Community', style: TextStyle(color: Colors.red)),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            )),

                  // Tab 3: Access & Subscription Pricing
                  ListView(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Paid Membership (Coins)', style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary)),
                        subtitle: Text('Require members to pay coins to subscribe and access posts', style: TextStyle(fontSize: 12, color: textSecondary)),
                        value: _isPaid,
                        onChanged: (val) => setState(() => _isPaid = val),
                      ),
                      if (_isPaid) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: _priceCtrl,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.monetization_on_rounded, color: Color(0xFFFF9500)),
                            suffixText: 'Coins / month',
                            labelText: 'Subscription Price in Coins',
                            hintText: 'e.g. 50',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _visibility,
                        dropdownColor: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                        style: TextStyle(color: textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Community Privacy',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'public', child: Text('Public (Anyone can discover & join)')),
                          DropdownMenuItem(value: 'private', child: Text('Private (Join requests required)')),
                        ],
                        onChanged: (val) => setState(() => _visibility = val ?? 'public'),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF007AFF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: _isSavingPricing ? null : _savePricing,
                          child: _isSavingPricing
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Save Pricing Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                      ),
                    ],
                  ),

                  // Tab 4: Edit Branding & Photos
                  ListView(
                    children: [
                      // Cover Banner Picker
                      GestureDetector(
                        onTap: () => _pickAndUploadPhoto(isLogo: false),
                        child: Container(
                          width: double.infinity,
                          height: 110,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F4F7),
                            borderRadius: BorderRadius.circular(14),
                            image: _coverUrl != null
                                ? DecorationImage(image: NetworkImage(_coverUrl!), fit: BoxFit.cover)
                                : null,
                            border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
                          ),
                          child: _isUploadingCover
                              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                              : Align(
                                  alignment: Alignment.bottomRight,
                                  child: Container(
                                    margin: const EdgeInsets.all(8),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.65),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.camera_alt_rounded, size: 12, color: Colors.white),
                                        SizedBox(width: 4),
                                        Text('Change Banner', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Avatar Picker
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => _pickAndUploadPhoto(isLogo: true),
                            child: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 30,
                                  backgroundColor: const Color(0xFF007AFF).withOpacity(0.15),
                                  backgroundImage: _logoUrl != null ? NetworkImage(_logoUrl!) : null,
                                  child: _isUploadingLogo
                                      ? const CircularProgressIndicator(strokeWidth: 2)
                                      : (_logoUrl == null
                                          ? const Icon(Icons.add_a_photo_rounded, color: Color(0xFF007AFF))
                                          : null),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF007AFF),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.edit_rounded, size: 11, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: TextField(
                              controller: _nameCtrl,
                              style: TextStyle(color: textPrimary),
                              decoration: InputDecoration(
                                labelText: 'Community Name',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: _descCtrl,
                        maxLines: 2,
                        style: TextStyle(color: textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Description / Bio',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: _categoryCtrl,
                        style: TextStyle(color: textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF007AFF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: _isSavingBranding ? null : _saveBranding,
                          child: _isSavingBranding
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Save Details & Photos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
