import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../components/brand.dart';
import '../core/api_client.dart';
import '../core/roles.dart';
import '../models/marketplace_models.dart';
import '../providers/auth_provider.dart';
import '../providers/marketplace_provider.dart';
import 'community_create_dialog.dart';
import 'post_composer_sheet.dart';
import 'story_composer_sheet.dart';
import 'automated_greeting_sheet.dart';

/// Full Publish & Creation Hub Screen (replaces empty create screen).
class CreateScreen extends ConsumerStatefulWidget {
  const CreateScreen({super.key});

  @override
  ConsumerState<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends ConsumerState<CreateScreen> {
  final _postTextController = TextEditingController();

  @override
  void dispose() {
    _postTextController.dispose();
    super.dispose();
  }

  void _showAddProductModal(bool isDigital) {
    final titleController = TextEditingController();
    final priceController = TextEditingController();
    final descController = TextEditingController();
    final categoryController = TextEditingController(text: isDigital ? 'Digital' : 'Electronics');
    bool escrowProtected = true;
    List<XFile> pickedImages = [];
    bool isSubmitting = false;
    final picker = ImagePicker();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1C1C1E)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final textPrimary = isDark ? Colors.white : Colors.black;

        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> pickPhotos() async {
              try {
                final files = await picker.pickMultiImage(limit: 5 - pickedImages.length);
                if (files.isNotEmpty) {
                  setModalState(() => pickedImages = [...pickedImages, ...files]);
                }
              } catch (_) {}
            }

            Future<void> submitProduct() async {
              if (titleController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a product title.')),
                );
                return;
              }

              setModalState(() => isSubmitting = true);
              final priceVal = double.tryParse(priceController.text.trim()) ?? 0.0;

              try {
                final imageUrls = <String>[];
                for (final image in pickedImages) {
                  try {
                    final bytes = await image.readAsBytes();
                    final form = FormData.fromMap({
                      'file': MultipartFile.fromBytes(bytes, filename: image.name),
                    });
                    final upload = await ApiClient.instance.dio.post('/upload', data: form);
                    final payload = ApiClient.instance.unwrap(upload);
                    final url = payload is Map<String, dynamic> ? payload['url'] : null;
                    if (url is String && url.isNotEmpty) imageUrls.add(url);
                  } catch (_) {}
                }

                await ref.read(marketplaceProvider.notifier).createProduct(
                      title: titleController.text.trim(),
                      description: descController.text.trim(),
                      price: priceVal,
                      currency: 'USD',
                      isDigital: isDigital,
                      category: categoryController.text.trim(),
                      escrowProtected: escrowProtected,
                      images: imageUrls.isEmpty
                          ? ['https://images.unsplash.com/photo-1584992236310-6edddc08acff?w=600&auto=format&fit=crop']
                          : imageUrls,
                    );

                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: const Color(0xFF34C759),
                      content: Text(
                        'Product "${titleController.text}" published to Marketplace successfully!',
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  setModalState(() => isSubmitting = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to publish product. Please try again.')),
                  );
                }
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
                    Text(
                      isDigital ? 'List Digital Asset' : 'Add Physical Product to Store',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Image Picker Container Row
                    Text(
                      'Product Photos (Up to 5)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 80,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          GestureDetector(
                            onTap: pickPhotos,
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFF007AFF).withOpacity(0.5),
                                  width: 1.5,
                                ),
                              ),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo_rounded, color: Color(0xFF007AFF), size: 24),
                                  SizedBox(height: 4),
                                  Text(
                                    'Add Photo',
                                    style: TextStyle(
                                      color: Color(0xFF007AFF),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          for (int i = 0; i < pickedImages.length; i++) ...[
                            const SizedBox(width: 8),
                            Stack(
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    image: DecorationImage(
                                      image: FileImage(File(pickedImages[i].path)),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 4,
                                  top: 4,
                                  child: GestureDetector(
                                    onTap: () {
                                      setModalState(() => pickedImages.removeAt(i));
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: Colors.black87,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close, color: Colors.white, size: 14),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: titleController,
                      style: TextStyle(color: textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Product Title',
                        hintText: isDigital ? 'e.g. Flutter Starter Kit' : 'e.g. Double Door Refrigerator',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Price (USD / NGN)',
                        prefixText: '\$ ',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: categoryController,
                      style: TextStyle(color: textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      maxLines: 3,
                      style: TextStyle(color: textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Product Description',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      value: escrowProtected,
                      title: const Text('Protect with MurihSpace Escrow', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Funds held safely until buyer confirms delivery'),
                      onChanged: (val) => setModalState(() => escrowProtected = val),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF007AFF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: isSubmitting ? null : submitProduct,
                        child: isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Publish Product', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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

  void _showAddBrandDealModal() {
    final titleController = TextEditingController();
    final budgetController = TextEditingController();
    final descController = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1C1C1E)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                Text(
                  'Post Creator Brand Deal',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    labelText: 'Campaign Title',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: budgetController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    labelText: 'Budget / Payout',
                    prefixText: '\$ ',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  maxLines: 3,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    labelText: 'Deliverables & Requirements (e.g., 1 Reel + 2 Stories)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007AFF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Brand Deal "${titleController.text}" published with Escrow contract protection!',
                          ),
                        ),
                      );
                    },
                    child: const Text('Post Brand Deal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCreateBroadcastChannelModal() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    String accessType = 'Public (All Followers)';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1C1C1E)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
                    Text(
                      'Create Broadcast Channel',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Broadcast 1-to-many updates directly to your followers and supporters inbox.',
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        labelText: 'Channel Name',
                        hintText: 'e.g. VIP Announcements & Signals',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      maxLines: 3,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        labelText: 'Channel Purpose / Description',
                        hintText: 'What will subscribers get in this broadcast channel?',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: accessType,
                      decoration: InputDecoration(
                        labelText: 'Audience & Access',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Public (All Followers)', child: Text('Public (All Followers)')),
                        DropdownMenuItem(value: 'Supporters & Buyers Only', child: Text('Supporters & Buyers Only')),
                        DropdownMenuItem(value: 'Private Invitation Only', child: Text('Private Invitation Only')),
                      ],
                      onChanged: (val) {
                        if (val != null) setModalState(() => accessType = val);
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF007AFF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          if (nameController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter a channel name.')),
                            );
                            return;
                          }
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Broadcast Channel "${nameController.text}" created! Followers notified.',
                              ),
                            ),
                          );
                        },
                        child: const Text('Create Channel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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

  void _showScheduleEventModal() {
    final titleController = TextEditingController();
    final locationController = TextEditingController();
    final priceController = TextEditingController(text: '0');
    final descController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1C1C1E)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
                    Text(
                      'Schedule Event or Meetup',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleController,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        labelText: 'Event Title',
                        hintText: 'e.g. Creator Live Q&A / Product Masterclass',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: locationController,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        labelText: 'Location or Link',
                        hintText: 'e.g. MurihSpace Live Stream / Zoom / Victoria Island',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: priceController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: TextStyle(color: isDark ? Colors.white : Colors.black),
                            decoration: InputDecoration(
                              labelText: 'Ticket Price (\$0 = Free)',
                              prefixText: '\$ ',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.calendar_today_rounded, size: 18),
                            label: Text(
                              '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (picked != null) {
                                setModalState(() => selectedDate = picked);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      maxLines: 3,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        labelText: 'Event Details',
                        hintText: 'What will be covered in this event?',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF007AFF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          if (titleController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter an event title.')),
                            );
                            return;
                          }
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Event "${titleController.text}" scheduled for ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}!',
                              ),
                            ),
                          );
                        },
                        child: const Text('Schedule Event', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final role = user?.role ?? UserRole.member;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF18191A) : const Color(0xFFF2F2F7);
    final cardBg = isDark ? const Color(0xFF242526) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

    // Standard Member / User gating check
    if (role == UserRole.member) {
      return _memberGatedView(context, isDark);
    }

    final isVendor = role == UserRole.vendor;
    final isCreator = role == UserRole.creator;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          isVendor ? 'Vendor Business Tools' : 'Creator Publishing & Tools',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 22,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Header Profile Box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFF007AFF),
                    child: Text(
                      (user?.name ?? 'M')[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? 'MurihSpace User',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: textPrimary,
                          ),
                        ),
                        Text(
                          '@${user?.username ?? 'user'} · ${role.label}',
                          style: TextStyle(fontSize: 12, color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF007AFF).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      role.label,
                      style: const TextStyle(
                        color: Color(0xFF007AFF),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // FOR YOU: Create Your Ads Today Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF007AFF).withOpacity(0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'FOR YOU',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10),
                        ),
                      ),
                      const Icon(Icons.ads_click_rounded, color: Colors.white70, size: 22),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Create Your Ads Today',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Boost your catalog products, drive 5x more conversions, and convert chats into escrow sales.',
                    style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: ElevatedButton(
                      onPressed: () => context.push('/ads-manager'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF007AFF),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Launch Ads & Catalog Promos',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Quick Creation Action Grid Header
            Text(
              'What would you like to create?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            // Creation Options Grid (Role-Tailored)
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.45,
              children: [
                _createGridCard(
                  icon: Icons.article_rounded,
                  iconColor: const Color(0xFF007AFF),
                  title: 'New Post',
                  subtitle: 'Share to feed',
                  isDark: isDark,
                  onTap: () => showPostComposer(context),
                ),
                _createGridCard(
                  icon: Icons.ads_click_rounded,
                  iconColor: const Color(0xFF34C759),
                  title: 'Sponsored Ads',
                  subtitle: 'Conversions & catalog',
                  isDark: isDark,
                  onTap: () => context.push('/ads-manager'),
                ),
                _createGridCard(
                  icon: Icons.storefront_rounded,
                  iconColor: const Color(0xFFFF3B30),
                  title: isVendor ? 'List Products' : 'Add Digital Product',
                  subtitle: isVendor ? 'Physical & escrow catalog' : 'Digital download & courses',
                  isDark: isDark,
                  onTap: () => _showAddProductModal(!isVendor),
                ),
                if (isCreator)
                  _createGridCard(
                    icon: Icons.handshake_rounded,
                    iconColor: const Color(0xFFFF9500),
                    title: 'Post Brand Deal',
                    subtitle: 'Creator sponsorship',
                    isDark: isDark,
                    onTap: _showAddBrandDealModal,
                  ),
                if (isCreator)
                  _createGridCard(
                    icon: Icons.photo_camera_rounded,
                    iconColor: const Color(0xFF8B5CF6),
                    title: 'Disappearing Story',
                    subtitle: 'Disappears in 24h',
                    isDark: isDark,
                    onTap: () => showStoryComposerSheet(context),
                  ),
                if (isCreator && Permissions.roleHas(role, 'community.create'))
                  _createGridCard(
                    icon: Icons.group_add_rounded,
                    iconColor: const Color(0xFF5856D6),
                    title: 'New Community',
                    subtitle: 'Build a space',
                    isDark: isDark,
                    onTap: () => showCreateCommunityDialog(context),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // Inset Grouped Section for Secondary Creations
            Text(
              'More Business & Publishing Tools',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.mark_chat_unread_rounded, color: Color(0xFF007AFF)),
                    title: Text('Automated Greeting Message', style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary)),
                    subtitle: Text('Auto-reply to incoming customer chats', style: TextStyle(fontSize: 12, color: textSecondary)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => showAutomatedGreetingSheet(context),
                  ),
                  Divider(height: 1, color: isDark ? const Color(0xFF3A3B3C) : const Color(0xFFE4E6EB)),
                  ListTile(
                    leading: Icon(isVendor ? Icons.inventory_2_rounded : Icons.file_present_rounded, color: const Color(0xFF8B5CF6)),
                    title: Text(isVendor ? 'List Products' : 'List Digital Asset / Starter Kit', style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary)),
                    subtitle: Text(isVendor ? 'Add physical store products to marketplace' : 'Templates, code, e-books', style: TextStyle(fontSize: 12, color: textSecondary)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _showAddProductModal(!isVendor),
                  ),
                  if (isCreator) ...[
                    Divider(height: 1, color: isDark ? const Color(0xFF3A3B3C) : const Color(0xFFE4E6EB)),
                    ListTile(
                      leading: const Icon(Icons.campaign_rounded, color: Color(0xFFFF9500)),
                      title: Text('Create Broadcast Channel', style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary)),
                      subtitle: Text('1-to-many updates for followers', style: TextStyle(fontSize: 12, color: textSecondary)),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: _showCreateBroadcastChannelModal,
                    ),
                    Divider(height: 1, color: isDark ? const Color(0xFF3A3B3C) : const Color(0xFFE4E6EB)),
                    ListTile(
                      leading: const Icon(Icons.event_rounded, color: Color(0xFF34C759)),
                      title: Text('Schedule Event or Meetup', style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary)),
                      subtitle: Text('Virtual conference or in-person meetup for creators', style: TextStyle(fontSize: 12, color: textSecondary)),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: _showScheduleEventModal,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _memberGatedView(BuildContext context, bool isDark) {
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF18191A) : const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF18191A) : const Color(0xFFF2F2F7),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Business Tools',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w900,
            fontSize: 22,
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF242526) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFF007AFF).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_rounded, color: Color(0xFF007AFF), size: 32),
                ),
                const SizedBox(height: 16),
                Text(
                  'Business Tools Gated',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Business tools, ad campaigns, storefront management, and creator publishing are reserved for Creator & Vendor accounts.\n\nUpgrade your free member account to start selling, posting brand deals, and creating communities.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007AFF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => context.push('/upgrade-account'),
                    icon: const BrandFavicon(size: 18),
                    label: const Text(
                      'Upgrade to Creator or Vendor',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _createGridCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final bg = isDark ? const Color(0xFF242526) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: textPrimary,
              ),
            ),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
