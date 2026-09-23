import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../core/api_client.dart';
import '../core/design_tokens.dart';
import '../models/broadcast_channel_models.dart';
import '../models/community_models.dart';
import '../models/group_models.dart';
import '../providers/auth_provider.dart';
import '../providers/broadcast_channels_provider.dart';
import '../providers/community_provider.dart';
import '../providers/groups_provider.dart';

/// Shows the "Create community" sliding bottom sheet and creates the community.
/// Returns the created [Community], or null if cancelled or failed.
Future<Community?> showCreateCommunityDialog(BuildContext context) async {
  final name = TextEditingController();
  final description = TextEditingController();
  final category = TextEditingController(text: 'General');
  final price = TextEditingController(text: '50');
  var visibility = 'public';
  var pricingType = 'free';

  String? logoUrl;
  String? coverUrl;
  bool isUploadingLogo = false;
  bool isUploadingCover = false;

  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1C1C1E)
        : Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      final textPrimary = isDark ? Colors.white : Colors.black;
      final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

      return StatefulBuilder(
        builder: (context, setState) {
          Future<void> pickAndUploadImage({required bool isLogo}) async {
            try {
              final picker = ImagePicker();
              final picked = await picker.pickImage(
                source: ImageSource.gallery,
                imageQuality: 85,
                maxWidth: isLogo ? 600 : 1600,
              );
              if (picked == null) return;

              setState(() {
                if (isLogo) isUploadingLogo = true;
                else isUploadingCover = true;
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

              if (context.mounted && uploadedUrl is String && uploadedUrl.isNotEmpty) {
                setState(() {
                  if (isLogo) {
                    logoUrl = uploadedUrl;
                    isUploadingLogo = false;
                  } else {
                    coverUrl = uploadedUrl;
                    isUploadingCover = false;
                  }
                });
              } else {
                setState(() {
                  if (isLogo) isUploadingLogo = false;
                  else isUploadingCover = false;
                });
              }
            } catch (_) {
              if (context.mounted) {
                setState(() {
                  if (isLogo) isUploadingLogo = false;
                  else isUploadingCover = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Could not upload image. Please try again.')),
                );
              }
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Drag Handle
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Create Community',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        icon: Icon(Icons.close_rounded, color: textSecondary),
                      ),
                    ],
                  ),
                  Text(
                    'Build a dedicated space for your audience and members.',
                    style: TextStyle(fontSize: 13, color: textSecondary),
                  ),
                  const SizedBox(height: 18),

                  // Interactive Cover Banner Picker
                  GestureDetector(
                    onTap: () => pickAndUploadImage(isLogo: false),
                    child: Container(
                      width: double.infinity,
                      height: 120,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F4F7),
                        borderRadius: BorderRadius.circular(16),
                        image: coverUrl != null
                            ? DecorationImage(image: NetworkImage(coverUrl!), fit: BoxFit.cover)
                            : null,
                        border: Border.all(
                          color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                        ),
                      ),
                      child: isUploadingCover
                          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                          : (coverUrl == null
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_photo_alternate_rounded, size: 28, color: textSecondary),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Upload Cover Banner',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary),
                                    ),
                                  ],
                                )
                              : Align(
                                  alignment: Alignment.bottomRight,
                                  child: Container(
                                    margin: const EdgeInsets.all(8),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.edit_rounded, size: 12, color: Colors.white),
                                        SizedBox(width: 4),
                                        Text('Change Banner', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                )),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Interactive Logo / Avatar Picker & Community Name Row
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => pickAndUploadImage(isLogo: true),
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 32,
                              backgroundColor: const Color(0xFF007AFF).withOpacity(0.15),
                              backgroundImage: logoUrl != null ? NetworkImage(logoUrl!) : null,
                              child: isUploadingLogo
                                  ? const CircularProgressIndicator(strokeWidth: 2)
                                  : (logoUrl == null
                                      ? const Icon(Icons.add_a_photo_rounded, color: Color(0xFF007AFF), size: 24)
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
                                child: const Icon(Icons.camera_alt_rounded, size: 12, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: TextField(
                          controller: name,
                          style: TextStyle(color: textPrimary),
                          decoration: InputDecoration(
                            labelText: 'Community Name *',
                            hintText: 'e.g. Web3 Creators Hub',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Description Field (Short Bio)
                  TextField(
                    controller: description,
                    maxLines: 2,
                    style: TextStyle(color: textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Short Description / Bio',
                      hintText: 'What is this community about?',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Category Field
                  TextField(
                    controller: category,
                    style: TextStyle(color: textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Category',
                      hintText: 'e.g. Technology, Design, Business, Crypto',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Visibility Selector
                  DropdownButtonFormField<String>(
                    value: visibility,
                    dropdownColor: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                    style: TextStyle(color: textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Visibility',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'public',
                        child: Text('Public (Anyone can discover & join)', style: TextStyle(color: textPrimary)),
                      ),
                      DropdownMenuItem(
                        value: 'private',
                        child: Text('Private (Join requests required)', style: TextStyle(color: textPrimary)),
                      ),
                    ],
                    onChanged: (v) => setState(() => visibility = v ?? 'public'),
                  ),
                  const SizedBox(height: 12),

                  // Pricing Selector
                  DropdownButtonFormField<String>(
                    value: pricingType,
                    dropdownColor: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                    style: TextStyle(color: textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Access Pricing',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'free',
                        child: Text('Free Community', style: TextStyle(color: textPrimary)),
                      ),
                      DropdownMenuItem(
                        value: 'paid',
                        child: Text('Paid Community (Requires Coins)', style: TextStyle(color: textPrimary)),
                      ),
                    ],
                    onChanged: (v) => setState(() => pricingType = v ?? 'free'),
                  ),

                  if (pricingType == 'paid') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: price,
                      keyboardType: const TextInputType.numberWithOptions(decimal: false),
                      style: TextStyle(color: textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Subscription Price in Coins',
                        prefixIcon: const Icon(Icons.monetization_on_rounded, color: Color(0xFFFF9500)),
                        suffixText: 'Coins',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Submit CTA Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF007AFF),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text(
                        'Create Community',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  if (ok != true || !context.mounted) return null;
  if (name.text.trim().isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('A community name is required.')),
    );
    return null;
  }

  try {
    final response = await ApiClient.instance.dio.post('/my-communities', data: {
      'name': name.text.trim(),
      'description': description.text.trim().isEmpty ? null : description.text.trim(),
      'category': category.text.trim().isEmpty ? 'General' : category.text.trim(),
      'visibility': visibility,
      'pricing_type': pricingType,
      'logo_url': logoUrl,
      'cover_url': coverUrl,
      if (pricingType == 'paid') 'price_amount': double.tryParse(price.text) ?? 50,
    });
    final payload = response.data;
    final raw = payload is Map<String, dynamic> ? payload['community'] : null;
    return raw is Map<String, dynamic> ? Community.fromJson(raw) : null;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not create the community.')),
      );
    }
    return null;
  }
}

/// Convenience wrapper that refreshes the my-communities provider after a
/// successful create. Returns the created community or null.
Future<Community?> createCommunity(BuildContext context) async {
  final community = await showCreateCommunityDialog(context);
  if (community != null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Community created successfully!')),
    );
  }
  return community;
}

/// Small labelled avatar used by community list/detail screens.
class CommunityLogo extends StatelessWidget {
  final Community community;
  final double size;

  const CommunityLogo({super.key, required this.community, required this.size});

  @override
  Widget build(BuildContext context) {
    final logoUrl = community.logoUrl;
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: DesignTokens.primarySoft,
      backgroundImage: logoUrl != null && logoUrl.isNotEmpty ? NetworkImage(logoUrl) : null,
      child: logoUrl == null || logoUrl.isEmpty
          ? Icon(Icons.person, color: DesignTokens.primaryDark, size: (size / 2) * 1.1)
          : null,
    );
  }
}

/// Shows the "Create Broadcast Channel" modal sheet.
///
/// A broadcast channel MUST be linked to an audience source the creator owns:
/// your Page (friends + followers), a Group you own/admin, or a Community you
/// own. Recipients are derived from that link server-side — you can never add
/// arbitrary users to a broadcast.
///
/// Returns the created [BroadcastChannel], or null if cancelled/failed.
Future<BroadcastChannel?> showCreateBroadcastChannelDialog(BuildContext context) {
  return showModalBottomSheet<BroadcastChannel>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1C1C1E)
        : Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => const _CreateBroadcastSheet(),
  );
}

class _CreateBroadcastSheet extends ConsumerStatefulWidget {
  const _CreateBroadcastSheet();

  @override
  ConsumerState<_CreateBroadcastSheet> createState() => _CreateBroadcastSheetState();
}

class _CreateBroadcastSheetState extends ConsumerState<_CreateBroadcastSheet> {
  final _name = TextEditingController();
  final _handle = TextEditingController();
  final _description = TextEditingController();
  bool _allowReplies = false;
  bool _isCreating = false;
  String? _error;

  BroadcastLinkedType _linkedType = BroadcastLinkedType.page;
  int? _linkedId;

  @override
  void dispose() {
    _name.dispose();
    _handle.dispose();
    _description.dispose();
    super.dispose();
  }

  List<Group> get _ownedGroups {
    final myId = ref.read(authProvider).user?.id;
    return ref.watch(myGroupsProvider).groups.where((g) {
      return g.isOwner || (g.creator?.id == myId) || (g.creatorId == myId);
    }).toList();
  }

  List<Community> get _ownedCommunities {
    final myId = ref.read(authProvider).user?.id;
    return ref.watch(myCommunitiesProvider).communities.where((c) {
      return c.userId == myId || (c.creator?.id == myId);
    }).toList();
  }

  Future<void> _create() async {
    final title = _name.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Please enter a channel name.');
      return;
    }
    if (_linkedType == BroadcastLinkedType.group && _linkedId == null) {
      setState(() => _error = 'Choose one of the groups you own.');
      return;
    }
    if (_linkedType == BroadcastLinkedType.community && _linkedId == null) {
      setState(() => _error = 'Choose one of the communities you own.');
      return;
    }

    setState(() {
      _isCreating = true;
      _error = null;
    });

    try {
      final channel = await ref
          .read(myBroadcastChannelsProvider.notifier)
          .create(
            name: title,
            handle: _handle.text.trim(),
            description: _description.text.trim(),
            allowReplies: _allowReplies,
            linkedType: _linkedType,
            linkedId: _linkedId,
          );
      if (!mounted) return;
      Navigator.pop(context, channel);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isCreating = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isCreating = false;
        _error = 'Could not create broadcast channel. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];
    final cardBg = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7);
    final ownedGroups = _ownedGroups;
    final ownedCommunities = _ownedCommunities;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF007AFF).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.campaign_rounded, color: Color(0xFF007AFF), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Create Broadcast Channel',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                        ),
                      ),
                      Text(
                        'Linked to an audience you own — no broadcasting to strangers.',
                        style: TextStyle(fontSize: 12, color: textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 18),

            TextField(
              controller: _name,
              style: TextStyle(color: textPrimary),
              decoration: InputDecoration(
                labelText: 'Channel Name',
                hintText: 'e.g., Daily Market Signals & VIP Updates',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _handle,
              style: TextStyle(color: textPrimary),
              decoration: InputDecoration(
                labelText: 'Channel Handle (optional)',
                hintText: 'e.g., vip_signals',
                prefixText: '@ ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _description,
              maxLines: 2,
              style: TextStyle(color: textPrimary),
              decoration: InputDecoration(
                labelText: 'Description / Purpose',
                hintText: 'Share announcements, product drops, and exclusive news...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),

            Text(
              'Who receives it:',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Recipients are added automatically from the source you link. You cannot add users who are not your friends, or not in a group/community you own.',
              style: TextStyle(fontSize: 12, color: textSecondary),
            ),
            const SizedBox(height: 12),

            _LinkOptionTile(
              selected: _linkedType == BroadcastLinkedType.page,
              icon: Icons.person_rounded,
              title: 'My Page',
              subtitle: 'Everyone who follows or is friends with you',
              onTap: () => setState(() {
                _linkedType = BroadcastLinkedType.page;
                _linkedId = null;
              }),
            ),
            const SizedBox(height: 8),

            _LinkOptionTile(
              selected: _linkedType == BroadcastLinkedType.group,
              icon: Icons.groups_rounded,
              title: 'One of my Groups',
              subtitle: ownedGroups.isEmpty
                  ? 'You need to own a group first'
                  : 'Members of a group you own or admin',
              onTap: ownedGroups.isEmpty
                  ? null
                  : () => setState(() {
                      _linkedType = BroadcastLinkedType.group;
                      _linkedId = ownedGroups.firstOrNull?.id;
                    }),
            ),
            if (_linkedType == BroadcastLinkedType.group) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                value: _linkedId,
                decoration: InputDecoration(
                  labelText: 'Group',
                  filled: true,
                  fillColor: cardBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: ownedGroups
                    .map((g) => DropdownMenuItem(
                          value: g.id,
                          child: Text(
                            g.name,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: textPrimary),
                          ),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _linkedId = v),
              ),
            ],
            const SizedBox(height: 8),

            _LinkOptionTile(
              selected: _linkedType == BroadcastLinkedType.community,
              icon: Icons.forum_rounded,
              title: 'One of my Communities',
              subtitle: ownedCommunities.isEmpty
                  ? 'You need to create a community first'
                  : 'Members of a community you own',
              onTap: ownedCommunities.isEmpty
                  ? null
                  : () => setState(() {
                      _linkedType = BroadcastLinkedType.community;
                      _linkedId = ownedCommunities.firstOrNull?.id;
                    }),
            ),
            if (_linkedType == BroadcastLinkedType.community) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                value: _linkedId,
                decoration: InputDecoration(
                  labelText: 'Community',
                  filled: true,
                  fillColor: cardBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: ownedCommunities
                    .map((c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(
                            c.name,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: textPrimary),
                          ),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _linkedId = v),
              ),
            ],
            const SizedBox(height: 14),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Allow Subscriber Comment Replies', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textPrimary)),
              subtitle: Text('Subscribers can comment on broadcast messages', style: TextStyle(fontSize: 12, color: textSecondary)),
              value: _allowReplies,
              onChanged: (val) => setState(() => _allowReplies = val),
            ),

            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007AFF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _isCreating ? null : _create,
                icon: _isCreating
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.campaign_rounded),
                label: Text(
                  _isCreating ? 'Creating Broadcast Channel…' : 'Create Broadcast Channel',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkOptionTile extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _LinkOptionTile({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7);
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];
    final enabled = onTap != null;

    return Material(
      color: selected ? const Color(0xFF007AFF).withValues(alpha: 0.12) : cardBg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? const Color(0xFF007AFF) : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: enabled ? const Color(0xFF007AFF) : Colors.grey,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: enabled ? textPrimary : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: selected ? const Color(0xFF007AFF) : Colors.grey,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
