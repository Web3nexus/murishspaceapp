import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../components/ui_states.dart';
import '../core/api_client.dart';
import '../core/design_tokens.dart';
import '../providers/follow_provider.dart';

/// Dedicated Suggested Vendors Screen (View All)
/// Backed by real Laravel API endpoint with strict role filtering
/// (only accounts with role = 'vendor' or an active storefront).
class SuggestedVendorsScreen extends ConsumerStatefulWidget {
  const SuggestedVendorsScreen({super.key});

  @override
  ConsumerState<SuggestedVendorsScreen> createState() =>
      _SuggestedVendorsScreenState();
}

class _SuggestedVendorsScreenState
    extends ConsumerState<SuggestedVendorsScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounceTimer;

  List<Map<String, dynamic>> _vendors = [];
  bool _loading = true;
  bool _loadingMore = false;
  int _currentPage = 1;
  int _lastPage = 1;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchVendors(page: 1, refresh: true);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_loadingMore &&
        _currentPage < _lastPage) {
      _fetchVendors(page: _currentPage + 1);
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _searchQuery = query.trim();
        _currentPage = 1;
      });
      _fetchVendors(page: 1, refresh: true);
    });
  }

  Future<void> _fetchVendors({int page = 1, bool refresh = false}) async {
    if (page == 1 && refresh) {
      setState(() => _loading = true);
    } else {
      setState(() => _loadingMore = true);
    }

    try {
      final res = await ApiClient.instance.dio.get(
        '/discover/vendors',
        queryParameters: {
          'page': page,
          'per_page': 20,
          if (_searchQuery.isNotEmpty) 'q': _searchQuery,
        },
      );

      final payload = ApiClient.instance.unwrap(res);
      List<Map<String, dynamic>> list = [];
      int lastP = 1;
      int currentP = page;

      if (payload is Map<String, dynamic>) {
        final raw = payload['vendors'];
        if (raw is List) {
          list = raw.whereType<Map<String, dynamic>>().toList();
        }
        lastP = (payload['last_page'] as num?)?.toInt() ?? 1;
        currentP = (payload['current_page'] as num?)?.toInt() ?? page;
      }

      if (mounted) {
        setState(() {
          if (page == 1) {
            _vendors = list;
          } else {
            _vendors.addAll(list);
          }
          _currentPage = currentP;
          _lastPage = lastP;
          _loading = false;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F141C) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF161B26) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final borderColor = isDark
        ? const Color(0xFF2E384D)
        : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Suggested Vendors',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E2638)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, color: textSecondary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      style: TextStyle(
                        fontSize: 14,
                        color: textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        filled: false,
                        hintText: 'Search vendors by store name, business...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: textSecondary,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _fetchVendors(page: 1, refresh: true),
        child: _loading
            ? const Center(
                child: LoadingStateWidget(message: 'Loading vendors...'),
              )
            : _vendors.isEmpty
            ? CenteredEmptyStateWidget(
                icon: Icons.storefront_rounded,
                title: 'No Vendors Found',
                description: _searchQuery.isNotEmpty
                    ? 'No vendors matched "$_searchQuery". Try another keyword.'
                    : 'No suggested vendors available right now.',
              )
            : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                itemCount: _vendors.length + (_loadingMore ? 1 : 0),
                itemBuilder: (ctx, i) {
                  if (i == _vendors.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: CircularProgressIndicator.adaptive(),
                      ),
                    );
                  }

                  final v = _vendors[i];
                  final vendorId = (v['id'] as num?)?.toInt() ?? 0;
                  final name = v['name'] as String? ?? 'Vendor';
                  final storeName = v['store_name'] as String?;
                  final storeSlug = v['store_slug'] as String?;
                  final tagline = v['tagline'] as String?;
                  final username = v['username'] as String? ?? '';
                  final bio = v['bio'] as String? ?? '';
                  final followers = v['followers'] as String? ?? 'Popular';
                  final isVerified = v['is_verified'] == true;
                  final rawAvatar =
                      v['avatar_url'] as String? ?? v['avatar'] as String?;
                  final avatarUrl = rawAvatar != null && rawAvatar.isNotEmpty
                      ? ApiClient.resolveUrl(rawAvatar)
                      : null;

                  final followState = ref.watch(followProvider);
                  final isFollowing = followState.isFollowing(vendorId);

                  final displayName = (storeName != null && storeName.isNotEmpty)
                      ? storeName
                      : name;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (storeSlug != null && storeSlug.isNotEmpty) {
                              context.push('/store/$storeSlug');
                            } else if (username.isNotEmpty) {
                              context.push('/u/$username');
                            }
                          },
                          child: CircleAvatar(
                            radius: 24,
                            backgroundColor: DesignTokens.primary.withValues(
                              alpha: 0.15,
                            ),
                            backgroundImage: avatarUrl != null
                                ? CachedNetworkImageProvider(avatarUrl)
                                : null,
                            child: avatarUrl == null
                                ? Text(
                                    displayName.isNotEmpty
                                        ? displayName[0].toUpperCase()
                                        : 'V',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: DesignTokens.primary,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              if (storeSlug != null && storeSlug.isNotEmpty) {
                                context.push('/store/$storeSlug');
                              } else if (username.isNotEmpty) {
                                context.push('/u/$username');
                              }
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        displayName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isVerified) ...[
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Icons.verified_rounded,
                                        size: 15,
                                        color: DesignTokens.primary,
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  '@$username · $followers',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: textSecondary,
                                  ),
                                ),
                                if ((tagline != null && tagline.isNotEmpty) || bio.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    tagline != null && tagline.isNotEmpty ? tagline : bio,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (storeSlug != null && storeSlug.isNotEmpty) ...[
                          IconButton(
                            icon: const Icon(Icons.storefront_rounded, size: 20),
                            color: DesignTokens.primary,
                            tooltip: 'Visit Storefront',
                            onPressed: () => context.push('/store/$storeSlug'),
                          ),
                        ],
                        SizedBox(
                          height: 32,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isFollowing
                                  ? (isDark
                                        ? const Color(0xFF2E384D)
                                        : const Color(0xFFE2E8F0))
                                  : DesignTokens.primary,
                              foregroundColor: isFollowing
                                  ? textPrimary
                                  : Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () {
                              if (vendorId > 0) {
                                ref
                                    .read(followProvider.notifier)
                                    .toggleFollow(vendorId);
                              }
                            },
                            child: Text(
                              isFollowing ? 'Following' : 'Follow',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

