import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/api_client.dart';
import '../models/marketplace_models.dart';
import '../providers/auth_provider.dart';
import '../providers/marketplace_provider.dart';
import 'product_detail_screen.dart';

/// Landing page for a shared product link (`/p/:id`).
///
/// `GET /marketplace/{id}` is public, so the product resolves for anyone. The
/// buying and seller-DM actions inside [ProductDetailScreen] are not, so a
/// signed-out visitor is sent through login with a `returnTo` that lands them
/// back on this exact product.
class ProductLinkScreen extends ConsumerWidget {
  final String productId;

  const ProductLinkScreen({super.key, required this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(linkedProductProvider(productId));

    return Scaffold(
      appBar: AppBar(title: const Text('Product')),
      bottomNavigationBar: async.maybeWhen(
        data: (product) =>
            _ProductActionBar(product: product, segment: productId.trim()),
        orElse: () => const SizedBox.shrink(),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ProductError(
          message: _friendlyMessage(error),
          onRetry: () => ref.invalidate(linkedProductProvider(productId)),
        ),
        data: (product) => _ProductPreview(product: product),
      ),
    );
  }
}

String _friendlyMessage(Object error) {
  if (error is ApiException) {
    final message = error.message.toLowerCase();
    if (message.contains('not found') || message.contains('no longer')) {
      return 'This product is no longer available.';
    }
    return error.message;
  }
  return 'We could not load this product.';
}

class _ProductPreview extends StatelessWidget {
  final MarketplaceProduct product;

  const _ProductPreview({required this.product});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final image = product.images.isNotEmpty ? product.images.first : null;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (image != null)
          AspectRatio(
            aspectRatio: 1,
            child: Image.network(
              image,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => ColoredBox(
                color: theme.colorScheme.surfaceContainerHighest,
                child: Icon(
                  Icons.image_not_supported_rounded,
                  size: 48,
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.isFree
                    ? 'Free'
                    : '${product.symbol}${_money(product.price)}',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                product.title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    product.productType == 'digital'
                        ? Icons.cloud_download_rounded
                        : Icons.inventory_2_rounded,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${product.productType == 'digital' ? 'Digital' : 'Physical'} · ${product.category}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.storefront_rounded,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Sold by ${product.sellerName}',
                      style: theme.textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (product.escrowProtected) ...[
                    const SizedBox(width: 10),
                    Icon(
                      Icons.shield_rounded,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Escrow protected',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
              if (product.description.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  product.description,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

String _money(double value) {
  final text = value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2);
  final parts = text.split('.');
  final whole = parts.first;
  final buffer = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) buffer.write(',');
    buffer.write(whole[i]);
  }
  return parts.length > 1 ? '$buffer.${parts[1]}' : buffer.toString();
}

class _ProductActionBar extends ConsumerWidget {
  final MarketplaceProduct product;

  /// The raw path segment the link was opened with (`12`, `p_12` or `d_12`).
  final String segment;

  const _ProductActionBar({required this.product, required this.segment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isAuthenticated = ref.watch(authProvider).token != null;
    // Built from the segment the user actually opened, not from the resolved
    // product id: a `/p/d_5` link must come back as `/p/d_5`, otherwise the
    // login round trip would silently drop the digital prefix and resolve to
    // physical product 5 instead.
    final returnTo = '/p/${Uri.encodeComponent(segment)}';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: FilledButton.icon(
          onPressed: () {
            if (!isAuthenticated) {
              context.push(
                '/auth/login?returnTo=${Uri.encodeQueryComponent(returnTo)}',
              );
              return;
            }
            // Hands off to the same detail screen the marketplace grid uses, so
            // escrow checkout and seller DM behave identically either way.
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ProductDetailScreen(
                  itemData: {
                    'id': product.id,
                    'title': product.title,
                    'sellerId': product.sellerId,
                    'sellerName': product.sellerName,
                    'sellerAvatar': product.sellerAvatar,
                    'price': product.price,
                    'currencySymbol': product.symbol,
                    'imageUrl': product.images.isNotEmpty
                        ? product.images.first
                        : null,
                    'category': product.category,
                    'location': product.location,
                    'rating': product.sellerRating,
                    'isFree': product.isFree,
                    'escrowProtected': product.escrowProtected,
                    'productType': product.productType,
                  },
                ),
              ),
            );
          },
          icon: Icon(
            isAuthenticated ? Icons.shopping_bag_rounded : Icons.login_rounded,
          ),
          label: Text(isAuthenticated ? 'View & buy' : 'Sign in to buy'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            backgroundColor: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

class _ProductError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ProductError({required this.message, required this.onRetry});

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
              Icons.shopping_basket_rounded,
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
