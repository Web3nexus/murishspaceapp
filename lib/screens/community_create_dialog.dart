import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/api_client.dart';
import '../core/design_tokens.dart';
import '../models/community_models.dart';

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
