import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/design_tokens.dart';
import '../models/community_models.dart';

/// Shows the "Create community" dialog and creates the community.
/// Returns the created [Community], or null if cancelled or failed.
Future<Community?> showCreateCommunityDialog(BuildContext context) async {
  final name = TextEditingController();
  final description = TextEditingController();
  final category = TextEditingController();
  final price = TextEditingController();
  var visibility = 'public';
  var pricingType = 'free';

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Create community'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 8),
              TextField(controller: description, decoration: const InputDecoration(labelText: 'Description'), maxLines: 2),
              const SizedBox(height: 8),
              TextField(controller: category, decoration: const InputDecoration(labelText: 'Category')),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: visibility,
                decoration: const InputDecoration(labelText: 'Visibility'),
                items: const [
                  DropdownMenuItem(value: 'public', child: Text('Public')),
                  DropdownMenuItem(value: 'private', child: Text('Private')),
                ],
                onChanged: (v) => setState(() => visibility = v ?? 'public'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: pricingType,
                decoration: const InputDecoration(labelText: 'Pricing'),
                items: const [
                  DropdownMenuItem(value: 'free', child: Text('Free')),
                  DropdownMenuItem(value: 'paid', child: Text('Paid')),
                ],
                onChanged: (v) => setState(() => pricingType = v ?? 'free'),
              ),
              if (pricingType == 'paid') ...[
                const SizedBox(height: 8),
                TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price (MUR)')),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Create'),
          ),
        ],
      ),
    ),
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
      const SnackBar(content: Text('Community created!')),
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
