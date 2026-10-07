import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/api_client.dart';

/// A creator storefront, as returned by `GET /api/v1/stores/{shortCode}`.
@immutable
class StorefrontModel {
  final int id;
  final String displayName;
  final String? tagline;
  final String? bio;
  final String? coverUrl;
  final String? avatarUrl;
  final String shortCode;
  final bool isPreview;

  final int? creatorId;
  final String? creatorName;
  final String? creatorUsername;

  final List<StorefrontProduct> physicalProducts;
  final List<StorefrontProduct> digitalProducts;

  const StorefrontModel({
    required this.id,
    required this.displayName,
    required this.shortCode,
    this.tagline,
    this.bio,
    this.coverUrl,
    this.avatarUrl,
    this.isPreview = false,
    this.creatorId,
    this.creatorName,
    this.creatorUsername,
    this.physicalProducts = const [],
    this.digitalProducts = const [],
  });

  List<StorefrontProduct> get products => [
    ...physicalProducts,
    ...digitalProducts,
  ];

  factory StorefrontModel.fromJson(Map<String, dynamic> json) {
    final creator = json['creator'] as Map<String, dynamic>?;
    List<StorefrontProduct> parseProducts(
      dynamic raw, {
      required bool isDigital,
    }) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map((json) => StorefrontProduct.fromJson(json, isDigital: isDigital))
          .toList();
    }

    return StorefrontModel(
      id: _toInt(json['id']) ?? 0,
      displayName: (json['display_name'] ?? 'Storefront').toString(),
      tagline: json['tagline']?.toString(),
      bio: json['bio']?.toString(),
      coverUrl: json['cover_url']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
      shortCode: (json['short_code'] ?? '').toString(),
      isPreview: json['is_preview'] == true,
      creatorId: _toInt(creator?['id']),
      creatorName: creator?['name']?.toString(),
      creatorUsername: creator?['username']?.toString(),
      physicalProducts: parseProducts(
        json['physical_products'],
        isDigital: false,
      ),
      digitalProducts: parseProducts(json['digital_products'], isDigital: true),
    );
  }
}

@immutable
class StorefrontProduct {
  final int id;
  final String title;
  final String? description;
  final double price;
  final String? currency;
  final String? category;
  final String? coverUrl;

  final bool isDigital;

  const StorefrontProduct({
    required this.id,
    required this.title,
    required this.price,
    required this.isDigital,
    this.description,
    this.currency,
    this.category,
    this.coverUrl,
  });

  /// Prefixed so the canonical `/p/:id` path can address the right catalogue:
  /// `p_` for physical, `d_` for digital, matching what the marketplace
  /// endpoint accepts. Without the prefix a bare numeric id would always resolve
  /// to the physical product, so this prefix is what keeps the link unambiguous.
  String get linkedProductPath => '/p/${isDigital ? 'd' : 'p'}_$id';

  /// [isDigital] is supplied by the caller because the physical and digital
  /// product arrays are identical in shape — the distinction only exists in
  /// which list the storefront endpoint returned them in.
  factory StorefrontProduct.fromJson(
    Map<String, dynamic> json, {
    required bool isDigital,
  }) {
    final rawPrice = json['price'];
    return StorefrontProduct(
      id: _toInt(json['id']) ?? 0,
      isDigital: isDigital,
      title: (json['title'] ?? 'Product').toString(),
      description: json['description']?.toString(),
      price: rawPrice is num
          ? rawPrice.toDouble()
          : (double.tryParse(rawPrice?.toString() ?? '0') ?? 0),
      currency: json['currency']?.toString(),
      category: json['category']?.toString(),
      coverUrl: json['cover_url']?.toString(),
    );
  }
}

int? _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

/// Resolves a shared `/store/:shortCode` link.
final storefrontProvider = FutureProvider.autoDispose
    .family<StorefrontModel, String>((ref, shortCode) {
      final code = shortCode.trim();
      if (code.isEmpty) {
        throw ApiException(
          message: 'This storefront link is missing its code.',
        );
      }
      final api = ref.read(apiClientProvider);
      return api.get('/stores/${Uri.encodeComponent(code)}').then((response) {
        final payload = api.unwrap(response);
        final raw = payload is Map<String, dynamic>
            ? (payload['storefront'] ?? payload['data'] ?? payload)
            : payload;
        if (raw is! Map<String, dynamic>) {
          throw ApiException(message: 'This storefront is not available.');
        }
        return StorefrontModel.fromJson(raw);
      });
    });

/// Landing page for a shared storefront link (`/store/:shortCode`).
///
/// `GET /stores/{shortCode}` is public, so the storefront renders for anyone.
/// The endpoint also falls back to matching a bare username, which means a
/// shared creator URL resolves here too.
class StorefrontLinkScreen extends ConsumerWidget {
  final String shortCode;

  const StorefrontLinkScreen({super.key, required this.shortCode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(storefrontProvider(shortCode));
    final theme = Theme.of(context);

    return Scaffold(
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _StorefrontError(
          message: error is ApiException && error.message.isNotEmpty
              ? error.message
              : 'We could not load this storefront.',
          onRetry: () => ref.invalidate(storefrontProvider(shortCode)),
        ),
        data: (store) => CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 180,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: store.coverUrl != null && store.coverUrl!.isNotEmpty
                    ? Image.network(
                        store.coverUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _headerFallback(theme),
                      )
                    : _headerFallback(theme),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (store.avatarUrl != null && store.avatarUrl!.isNotEmpty)
                      CircleAvatar(
                        radius: 34,
                        backgroundImage: NetworkImage(store.avatarUrl!),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      store.displayName,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (store.tagline != null && store.tagline!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(store.tagline!, style: theme.textTheme.bodyMedium),
                    ],
                    if (store.creatorUsername != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: OutlinedButton.icon(
                          onPressed: () => context.push(
                            '/u/${Uri.encodeComponent(store.creatorUsername!)}',
                          ),
                          icon: const Icon(Icons.person_rounded),
                          label: Text(
                            'View ${store.creatorName ?? store.creatorUsername!}\'s profile',
                          ),
                        ),
                      ),
                    if (store.isPreview)
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: _PreviewNotice(),
                      ),
                    const SizedBox(height: 24),
                    if (store.products.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'No products listed yet.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      )
                    else ...[
                      Text(
                        'Shop',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      for (final product in store.products)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading:
                              product.coverUrl == null ||
                                  product.coverUrl!.isEmpty
                              ? CircleAvatar(
                                  child: Icon(
                                    product.isDigital
                                        ? Icons.cloud_download_rounded
                                        : Icons.inventory_2_rounded,
                                    size: 20,
                                  ),
                                )
                              : CircleAvatar(
                                  backgroundImage: NetworkImage(
                                    product.coverUrl!,
                                  ),
                                ),
                          title: Text(product.title),
                          subtitle: Text(
                            product.price <= 0
                                ? 'Free'
                                : '${product.currency ?? 'USD'} ${product.price.toStringAsFixed(2)}',
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => context.push(product.linkedProductPath),
                        ),
                    ],
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerFallback(ThemeData theme) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          theme.colorScheme.primaryContainer,
          theme.colorScheme.secondaryContainer,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  );
}

/// Marks an owner-only storefront so a visitor is not misled about visibility.
class _PreviewNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.visibility_rounded,
            size: 18,
            color: theme.colorScheme.onTertiaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'You are previewing this storefront before it is published.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onTertiaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StorefrontError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _StorefrontError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.storefront_rounded,
              size: 56,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
