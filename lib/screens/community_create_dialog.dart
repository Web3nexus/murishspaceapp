import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/design_tokens.dart';
import '../models/community_models.dart';

/// Shows the "Create community" sliding bottom sheet and creates the community.
/// Returns the created [Community], or null if cancelled or failed.
Future<Community?> showCreateCommunityDialog(BuildContext context) async {
  final name = TextEditingController();
  final description = TextEditingController();
  final category = TextEditingController();
  final price = TextEditingController();
  final logoUrlController = TextEditingController(text: 'https://images.unsplash.com/photo-1522071820081-009f0129c71c?w=400');
  final coverUrlController = TextEditingController(text: 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=1000');
  var visibility = 'public';
  var pricingType = 'free';

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

                  // Name Field
                  TextField(
                    controller: name,
                    style: TextStyle(color: textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Community Name',
                      hintText: 'e.g., Web3 Creators Hub',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

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

                  // Profile Pic Image URL
                  TextField(
                    controller: logoUrlController,
                    style: TextStyle(color: textPrimary),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.image_outlined),
                      labelText: 'Profile Pic Image URL',
                      hintText: 'https://...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Cover Banner Image URL
                  TextField(
                    controller: coverUrlController,
                    style: TextStyle(color: textPrimary),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.landscape_outlined),
                      labelText: 'Cover Banner Image URL',
                      hintText: 'https://...',
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
                      hintText: 'e.g. Technology, Design, Business',
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
                        child: Text('Private (Invite & approval required)', style: TextStyle(color: textPrimary)),
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
                      labelText: 'Access Type',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'free',
                        child: Text('Free Access', style: TextStyle(color: textPrimary)),
                      ),
                      DropdownMenuItem(
                        value: 'paid',
                        child: Text('Paid Membership', style: TextStyle(color: textPrimary)),
                      ),
                    ],
                    onChanged: (v) => setState(() => pricingType = v ?? 'free'),
                  ),

                  if (pricingType == 'paid') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: price,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Membership Price (USD / NGN)',
                        prefixText: '\$ ',
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
      'logo_url': logoUrlController.text.trim().isEmpty ? null : logoUrlController.text.trim(),
      'cover_url': coverUrlController.text.trim().isEmpty ? null : coverUrlController.text.trim(),
      if (pricingType == 'paid') 'price_amount': double.tryParse(price.text) ?? 0,
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
          ? Text(
              community.initials,
              style: const TextStyle(color: DesignTokens.primaryDark, fontWeight: FontWeight.w700, fontSize: 16),
            )
          : null,
    );
  }
}

/// Shows the "Create Broadcast Channel" modal sheet and creates the broadcast channel.
Future<dynamic> showCreateBroadcastChannelDialog(BuildContext context) async {
  final name = TextEditingController();
  final description = TextEditingController();
  final channelHandle = TextEditingController();
  bool allowReplies = false;
  bool isCreating = false;

  return showModalBottomSheet<dynamic>(
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
                          color: const Color(0xFF007AFF).withOpacity(0.15),
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
                              '1-to-many updates for your subscribers & followers.',
                              style: TextStyle(fontSize: 12, color: textSecondary),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: Icon(Icons.close_rounded, color: textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  TextField(
                    controller: name,
                    style: TextStyle(color: textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Channel Name',
                      hintText: 'e.g., Daily Market Signals & VIP Updates',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: channelHandle,
                    style: TextStyle(color: textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Channel Handle',
                      hintText: 'e.g., vip_signals',
                      prefixText: '@ ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: description,
                    maxLines: 2,
                    style: TextStyle(color: textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Description / Purpose',
                      hintText: 'Share announcements, product drops, and exclusive news...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Allow Subscriber Comment Replies', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textPrimary)),
                    subtitle: Text('Subscribers can comment on broadcast messages', style: TextStyle(fontSize: 12, color: textSecondary)),
                    value: allowReplies,
                    onChanged: (val) => setState(() => allowReplies = val),
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF007AFF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: isCreating
                          ? null
                          : () async {
                              final title = name.text.trim();
                              if (title.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please enter a channel name')),
                                );
                                return;
                              }
                              setState(() => isCreating = true);
                              try {
                                await ApiClient.instance.dio.post('/conversations/broadcast', data: {
                                  'title': title,
                                  'handle': channelHandle.text.trim(),
                                  'description': description.text.trim(),
                                  'allow_replies': allowReplies,
                                });
                              } catch (_) {}
                              if (context.mounted) {
                                Navigator.pop(ctx, true);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Broadcast Channel "$title" created!')),
                                );
                              }
                            },
                      icon: isCreating
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.campaign_rounded),
                      label: Text(
                        isCreating ? 'Creating Broadcast Channel…' : 'Create Broadcast Channel',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
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
}
