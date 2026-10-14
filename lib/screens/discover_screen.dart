import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../components/live_now_rail.dart';
import '../components/live_stream_card.dart';
import '../components/reels_viewer_sheet.dart';
import '../components/ui_states.dart';
import '../core/api_client.dart';
import '../core/contacts_service.dart';
import '../core/design_tokens.dart';
import '../core/permissions_service.dart';
import '../providers/auth_provider.dart';
import '../providers/community_provider.dart';
import '../providers/follow_provider.dart';
import '../providers/live_discovery_provider.dart';
import 'post_card.dart';
import 'post_comments_sheet.dart';
import 'post_report_dialog.dart';

/// Complete Redesigned Discover Screen matching MurihSpace visual reference:
/// Search bar · Category tabs (For You, Trending, People, Communities, Live) ·
/// Trending Now hero card · Category pills · Trending Topics · Suggested Creators ·
/// 3-column Media Discovery Grid with fullscreen Reels viewer.
class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 5, vsync: this);
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  bool _searching = false;
  String _searchQuery = '';
  List<Map<String, dynamic>> _userResults = [];
  List<Map<String, dynamic>> _communityResults = [];

  String _selectedSubCategory = 'All';

  List<Map<String, dynamic>> _trendingTopics = [];
  List<Map<String, dynamic>> _suggestedCreators = [];
  List<Map<String, dynamic>> _peopleYouMayKnow = [];
  List<MatchedContact> _matchedContacts = [];
  bool _loadingTrending = true;
  bool _loadingPeople = false;
  bool _hasContactPermission = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchDiscoveryData();
      _fetchPeopleData();
      _checkContactPermission();
    });
  }

  Future<void> _checkContactPermission() async {
    final granted = await ContactsService.instance.hasPermission();
    if (granted && mounted) {
      setState(() => _hasContactPermission = true);
      final contacts = await ContactsService.instance.syncContacts();
      if (mounted) {
        setState(() => _matchedContacts = contacts);
      }
    }
  }

  Future<void> _syncContactsAction() async {
    final granted = await ref.read(permissionsProvider.notifier).ensureContacts(context);
    if (!granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contacts access is needed to find your friends.')),
        );
      }
      return;
    }
    if (mounted) {
      setState(() => _hasContactPermission = true);
      final contacts = await ContactsService.instance.syncContacts();
      if (mounted) {
        setState(() => _matchedContacts = contacts);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              contacts.isNotEmpty
                  ? 'Found ${contacts.length} registered contacts on MurihSpace!'
                  : 'Contacts synced. No registered friends found yet.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _fetchPeopleData() async {
    if (mounted) setState(() => _loadingPeople = true);
    try {
      final res = await ApiClient.instance.dio.get('/discover/people');
      final data = ApiClient.instance.unwrap(res);
      if (data is Map<String, dynamic> && mounted) {
        final rawPymk = data['people_you_may_know'];
        final rawCreators = data['suggested_creators'];
        final pymk = rawPymk is List
            ? rawPymk.whereType<Map<String, dynamic>>().toList()
            : <Map<String, dynamic>>[];
        final creators = rawCreators is List
            ? rawCreators.whereType<Map<String, dynamic>>().toList()
            : <Map<String, dynamic>>[];

        final statuses = <int, bool>{};
        for (final item in [...pymk, ...creators]) {
          final id = (item['id'] as num?)?.toInt();
          if (id != null && item['is_following'] != null) {
            statuses[id] = item['is_following'] == true;
          }
        }
        ref.read(followProvider.notifier).seedFollowing(statuses);

        if (mounted) {
          setState(() {
            _peopleYouMayKnow = pymk;
            if (creators.isNotEmpty) {
              _suggestedCreators = creators;
            }
          });
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingPeople = false);
    }
  }

  Map<String, dynamic>? _featuredTrending;
  List<Map<String, dynamic>> _trendingMedia = [];
  bool _loadingTrendingMedia = false;

  Future<void> _fetchDiscoveryData() async {
    try {
      final res = await ApiClient.instance.dio.get('/discover/trending');
      final data = ApiClient.instance.unwrap(res);
      if (data is Map<String, dynamic> && mounted) {
        final topics = data['trending_topics'];
        final creators = data['suggested_creators'];
        final featured = data['featured_trending'];
        setState(() {
          if (topics is List) {
            _trendingTopics = topics.whereType<Map<String, dynamic>>().toList();
          }
          if (creators is List) {
            _suggestedCreators = creators
                .whereType<Map<String, dynamic>>()
                .toList();

            final statuses = <int, bool>{};
            for (final c in _suggestedCreators) {
              final id = (c['id'] as num?)?.toInt();
              if (id != null && c['is_following'] != null) {
                statuses[id] = c['is_following'] == true;
              }
            }
            ref.read(followProvider.notifier).seedFollowing(statuses);
          }
          if (featured is Map<String, dynamic>) {
            _featuredTrending = featured;
          }
          _loadingTrending = false;
        });
      }
      _fetchTrendingMedia();
    } catch (_) {
      if (mounted) setState(() => _loadingTrending = false);
    }
  }

  Future<void> _fetchTrendingMedia() async {
    if (mounted) setState(() => _loadingTrendingMedia = true);
    try {
      final res = await ApiClient.instance.dio.get('/feed');
      final payload = ApiClient.instance.unwrap(res);
      List<Map<String, dynamic>> list = [];
      if (payload is Map<String, dynamic>) {
        final data = payload['data'];
        if (data is List) {
          list = data.whereType<Map<String, dynamic>>().toList();
        }
      } else if (payload is List) {
        list = payload.whereType<Map<String, dynamic>>().toList();
      }

      final mediaPosts = list.where((p) {
        final mediaUrls = p['media_urls'];
        return (mediaUrls is List && mediaUrls.isNotEmpty) ||
            p['type'] == 'media' ||
            p['type'] == 'reels';
      }).toList();

      if (mounted) {
        setState(() {
          _trendingMedia = mediaPosts;
          _loadingTrendingMedia = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingTrendingMedia = false);
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _tab.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    final q = query.trim();
    if (q.isEmpty) {
      setState(() {
        _searchQuery = '';
        _searching = false;
        _userResults = [];
        _communityResults = [];
      });
      return;
    }
    _searchDebounce = Timer(
      const Duration(milliseconds: 300),
      () => _performSearch(q),
    );
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) return;
    setState(() {
      _searchQuery = query;
      _searching = true;
    });

    try {
      final response = await ApiClient.instance.dio.get(
        '/search',
        queryParameters: {'q': query, 'type': 'all', 'per_page': 20},
      );
      final payload = ApiClient.instance.unwrap(response);
      List<Map<String, dynamic>> users = [];
      List<Map<String, dynamic>> communities = [];

      if (payload is Map<String, dynamic>) {
        final rawResults = payload['results'];
        if (rawResults is Map<String, dynamic>) {
          if (rawResults['users'] is List) {
            users = (rawResults['users'] as List)
                .whereType<Map<String, dynamic>>()
                .toList();
          }
          if (rawResults['communities'] is List) {
            communities = (rawResults['communities'] as List)
                .whereType<Map<String, dynamic>>()
                .toList();
          }
        }
        if (users.isEmpty && payload['users'] is List) {
          users = (payload['users'] as List)
              .whereType<Map<String, dynamic>>()
              .toList();
        }
        if (communities.isEmpty && payload['communities'] is List) {
          communities = (payload['communities'] as List)
              .whereType<Map<String, dynamic>>()
              .toList();
        }
      }

      if (!mounted) return;
      setState(() {
        _userResults = users;
        _communityResults = communities;
        _searching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _searching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F141C) : const Color(0xFFF3F5F8);
    final cardBg = isDark ? const Color(0xFF161B26) : Colors.white;
    final searchBg = isDark ? const Color(0xFF1E2638) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF17202B);
    final textSecondary = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF667085);
    final borderColor = isDark
        ? const Color(0xFF2E384D)
        : const Color(0xFFE4E7EC);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Discover',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 22,
            color: textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_searchQuery.isNotEmpty ? 54 : 102),
          child: Column(
            children: [
              // Standard Clean Search Input
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: searchBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        color: textSecondary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          onSubmitted: (v) => _performSearch(v.trim()),
                          textInputAction: TextInputAction.search,
                          style: TextStyle(
                            fontSize: 14,
                            color: textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            filled: false,
                            hintText:
                                'Search people, posts, videos, communities...',
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

              if (_searchQuery.isEmpty) ...[
                const SizedBox(height: 8),
                // Category Navigation Tabs
                TabBar(
                  controller: _tab,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: DesignTokens.primary,
                  unselectedLabelColor: textSecondary,
                  indicatorColor: DesignTokens.primary,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  tabs: const [
                    Tab(text: 'For You'),
                    Tab(text: 'Trending'),
                    Tab(text: 'People'),
                    Tab(text: 'Communities'),
                    Tab(text: 'Live'),
                  ],
                ),
              ] else
                const SizedBox(height: 12),
            ],
          ),
        ),
      ),
      body: _searchQuery.isNotEmpty
          ? _buildSearchResults(isDark, cardBg, textPrimary, textSecondary)
          : TabBarView(
              controller: _tab,
              children: [
                _buildForYouTab(
                  isDark,
                  cardBg,
                  textPrimary,
                  textSecondary,
                  borderColor,
                ),
                _buildTrendingMediaTab(
                  isDark,
                  cardBg,
                  textPrimary,
                  textSecondary,
                  borderColor,
                ),
                _buildPeopleTab(isDark, cardBg, textPrimary, textSecondary),
                _buildCommunitiesTab(
                  isDark,
                  cardBg,
                  textPrimary,
                  textSecondary,
                ),
                _buildLiveTab(isDark, cardBg, textPrimary, textSecondary),
              ],
            ),
    );
  }

  // 1. "For You" Discovery Hub (Trending Hero + Category Pills + Topics + Creators + Feed)
  Widget _buildForYouTab(
    bool isDark,
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
  ) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 14),
      children: [
        // A. Featured Hero Banner: "TRENDING NOW"
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GestureDetector(
            onTap: () {
              final tag =
                  _featuredTrending?['tag'] as String? ??
                  (_trendingTopics.isNotEmpty
                      ? _trendingTopics[0]['tag'] as String?
                      : null);
              if (tag != null && tag.isNotEmpty) {
                _searchController.text = tag;
                _performSearch(tag);
              }
            },
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F2B48), Color(0xFF1A68D4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.1),
                          Colors.black.withValues(alpha: 0.75),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: DesignTokens.primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            '🔥 TRENDING NOW',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _featuredTrending?['title'] as String? ??
                              (_trendingTopics.isNotEmpty
                                  ? _trendingTopics[0]['tag'] as String? ??
                                        'Trending Topics'
                                  : 'Discover MurihSpace'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _featuredTrending?['subtitle'] as String? ??
                              (_trendingTopics.isNotEmpty
                                  ? _trendingTopics[0]['count'] as String? ??
                                        'Popular Topics'
                                  : 'Explore what is happening right now'),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 18),

        // B. Category Shortcuts Row (Music, Travel, Food, Fashion, Tech)
        SizedBox(
          height: 82,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            children: [
              _categoryPillItem(
                'Music',
                Icons.music_note_rounded,
                const Color(0xFF8B5CF6),
                isDark,
              ),
              _categoryPillItem(
                'Travel',
                Icons.flight_takeoff_rounded,
                const Color(0xFF10B981),
                isDark,
              ),
              _categoryPillItem(
                'Food',
                Icons.restaurant_rounded,
                const Color(0xFFF59E0B),
                isDark,
              ),
              _categoryPillItem(
                'Fashion',
                Icons.shopping_bag_rounded,
                const Color(0xFFEC4899),
                isDark,
              ),
              _categoryPillItem(
                'Tech',
                Icons.devices_rounded,
                const Color(0xFF0284C7),
                isDark,
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // C. Trending Topics Section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Trending Topics',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                ),
              ),
              GestureDetector(
                onTap: () => _tab.animateTo(1),
                child: const Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: DesignTokens.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _trendingTopics.map((topic) {
              final tag = topic['tag'] as String? ?? '';
              final count = topic['count'] as String? ?? '';
              return GestureDetector(
                onTap: () {
                  _searchController.text = tag;
                  _performSearch(tag);
                },
                child: Container(
                  width: (MediaQuery.of(context).size.width - 42) / 2,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tag,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        count,
                        style: TextStyle(fontSize: 11, color: textSecondary),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 24),

        // D. Suggested Creators Section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Suggested Creators',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                ),
              ),
              GestureDetector(
                onTap: () => context.push('/creators'),
                child: const Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: DesignTokens.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 175,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: _suggestedCreators.length,
            itemBuilder: (ctx, i) {
              final c = _suggestedCreators[i];
              final rawAvatar =
                  c['avatar_url'] as String? ?? c['avatar'] as String?;
              final resolvedAvatar = rawAvatar != null && rawAvatar.isNotEmpty
                  ? ApiClient.resolveUrl(rawAvatar)
                  : null;
              final name = c['name'] as String? ?? 'Creator';
              final username = c['username'] as String? ?? '';
              final creatorId = (c['id'] as num?)?.toInt() ?? 0;
              final followers = c['followers'] as String? ?? 'Popular';

              return GestureDetector(
                onTap: () {
                  if (username.isNotEmpty) {
                    context.push('/u/$username');
                  }
                },
                child: Container(
                  width: 140,
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: DesignTokens.primary.withValues(
                          alpha: 0.15,
                        ),
                        backgroundImage: resolvedAvatar != null
                            ? CachedNetworkImageProvider(resolvedAvatar)
                            : null,
                        child: resolvedAvatar == null
                            ? Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'C',
                              )
                            : null,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '@$username · $followers',
                        style: TextStyle(fontSize: 10, color: textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        height: 28,
                        child: _buildFollowButton(creatorId),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 20),

        // E. Recommended Posts Feed
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Explore Posts',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: textPrimary,
            ),
          ),
        ),
        const _FeedList(feedType: 'home'),
      ],
    );
  }

  // 2. 3-Column Media Grid Tab (Screen 3 in Reference Image)
  Widget _buildTrendingMediaTab(
    bool isDark,
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
  ) {
    const categories = ['All', 'Music', 'Travel', 'Food', 'Lifestyle'];

    return Column(
      children: [
        // Filter pills row
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            itemBuilder: (ctx, i) {
              final cat = categories[i];
              final isSelected = cat == _selectedSubCategory;
              return GestureDetector(
                onTap: () => setState(() => _selectedSubCategory = cat),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? DesignTokens.primary
                        : (isDark ? const Color(0xFF1E2638) : Colors.white),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? DesignTokens.primary : borderColor,
                    ),
                  ),
                  child: Text(
                    cat,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white : const Color(0xFF17202B)),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // 3-Column Media Grid
        Expanded(
          child: _loadingTrendingMedia
              ? const Center(
                  child: LoadingStateWidget(
                    message: 'Loading trending media...',
                  ),
                )
              : _trendingMedia.isEmpty
              ? CenteredEmptyStateWidget(
                  icon: Icons.video_library_outlined,
                  title: 'No Trending Media',
                  description:
                      'Be the first to publish photos and reels on MurihSpace!',
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(2),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 2,
                    mainAxisSpacing: 2,
                    childAspectRatio: 0.75, // Vertical reel aspect ratio
                  ),
                  itemCount: _trendingMedia.length,
                  itemBuilder: (ctx, i) {
                    final item = _trendingMedia[i];
                    final mediaUrls = item['media_urls'] is List
                        ? item['media_urls'] as List
                        : [];
                    final rawUrl = mediaUrls.isNotEmpty
                        ? mediaUrls.first.toString()
                        : '';
                    final url = rawUrl.isNotEmpty
                        ? (ApiClient.resolveUrl(rawUrl) ?? rawUrl)
                        : '';
                    final caption = item['content'] as String? ?? '';
                    final author = item['author'] is Map
                        ? item['author']['name'] as String? ?? 'Creator'
                        : 'Creator';
                    final likesCount =
                        (item['likes_count'] as num?)?.toInt() ??
                        (item['reactions_count'] as num?)?.toInt() ??
                        0;
                    final displayCount = likesCount >= 1000
                        ? '${(likesCount / 1000).toStringAsFixed(1)}K'
                        : '$likesCount';

                    return GestureDetector(
                      onTap: () {
                        if (url.isNotEmpty) {
                          ReelsViewerSheet.show(
                            context,
                            authorName: author,
                            caption: caption,
                            videoThumbnail: url,
                            likesCount: displayCount,
                          );
                        }
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (url.isNotEmpty)
                            CachedNetworkImage(
                              imageUrl: url,
                              fit: BoxFit.cover,
                              placeholder: (ctx, url) =>
                                  Container(color: cardBg),
                              errorWidget: (ctx, url, err) => Container(
                                color: cardBg,
                                child: const Icon(
                                  Icons.broken_image_rounded,
                                  color: Colors.grey,
                                ),
                              ),
                            )
                          else
                            Container(
                              color: cardBg,
                              padding: const EdgeInsets.all(8),
                              child: Center(
                                child: Text(
                                  caption,
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: textPrimary,
                                  ),
                                ),
                              ),
                            ),
                          // Gradient overlay at bottom
                          Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.transparent, Colors.black87],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                stops: [0.6, 1.0],
                              ),
                            ),
                          ),
                          // View / like count badge
                          Positioned(
                            left: 6,
                            bottom: 6,
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  displayCount,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Reel icon in top right
                          const Positioned(
                            top: 6,
                            right: 6,
                            child: Icon(
                              Icons.video_library_rounded,
                              color: Colors.white70,
                              size: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _categoryPillItem(
    String label,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Container(
      width: 68,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF17202B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeopleTab(
    bool isDark,
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
  ) {
    if ((_loadingTrending || _loadingPeople) &&
        _suggestedCreators.isEmpty &&
        _peopleYouMayKnow.isEmpty &&
        _matchedContacts.isEmpty) {
      return const Center(
        child: LoadingStateWidget(message: 'Discovering people & creators...'),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          _fetchDiscoveryData(),
          _fetchPeopleData(),
          if (_hasContactPermission)
            ContactsService.instance.syncContacts().then((c) {
              if (mounted) setState(() => _matchedContacts = c);
            }),
        ]);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Contacts sync banner if not granted
          if (!_hasContactPermission)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: DesignTokens.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: DesignTokens.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: DesignTokens.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.contacts_rounded,
                      color: DesignTokens.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Find Friends From Contacts',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Connect with people you know on MurihSpace',
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DesignTokens.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _syncContactsAction,
                    child: const Text(
                      'Sync',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // 1. From Your Contacts section
          if (_matchedContacts.isNotEmpty) ...[
            _buildSectionHeader(
              title: 'From Your Contacts',
              icon: Icons.contacts_rounded,
              textPrimary: textPrimary,
              trailingCount: _matchedContacts.length,
            ),
            const SizedBox(height: 8),
            ..._matchedContacts.map((contact) {
              return _buildContactTile(
                contact: contact,
                cardBg: cardBg,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              );
            }),
            const SizedBox(height: 16),
          ],

          // 2. People You May Know section (2nd degree network / mutual follows)
          if (_peopleYouMayKnow.isNotEmpty) ...[
            _buildSectionHeader(
              title: 'People You May Know',
              icon: Icons.people_outline_rounded,
              textPrimary: textPrimary,
              trailingCount: _peopleYouMayKnow.length,
            ),
            const SizedBox(height: 8),
            ..._peopleYouMayKnow.map((person) {
              return _buildPersonTile(
                person: person,
                cardBg: cardBg,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              );
            }),
            const SizedBox(height: 16),
          ],

          // 3. Suggested Creators
          if (_suggestedCreators.isNotEmpty) ...[
            _buildSectionHeader(
              title: 'Suggested Creators',
              icon: Icons.star_border_rounded,
              textPrimary: textPrimary,
              trailingCount: _suggestedCreators.length,
            ),
            const SizedBox(height: 8),
            ..._suggestedCreators.map((creator) {
              return _buildPersonTile(
                person: creator,
                cardBg: cardBg,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              );
            }),
            const SizedBox(height: 16),
          ],

          // If completely empty
          if (_matchedContacts.isEmpty &&
              _peopleYouMayKnow.isEmpty &&
              _suggestedCreators.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: CenteredEmptyStateWidget(
                icon: Icons.people_outline_rounded,
                title: 'No People Found',
                description: 'Sync your contacts or search above to find friends.',
                actionLabel: _hasContactPermission ? null : 'Sync Contacts',
                onAction: _hasContactPermission ? null : _syncContactsAction,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required IconData icon,
    required Color textPrimary,
    int? trailingCount,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: DesignTokens.primary),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
        if (trailingCount != null && trailingCount > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: DesignTokens.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$trailingCount',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: DesignTokens.primary,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPersonTile({
    required Map<String, dynamic> person,
    required Color cardBg,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final rawAvatar =
        person['avatar_url'] as String? ?? person['avatar'] as String?;
    final resolvedAvatar = rawAvatar != null && rawAvatar.isNotEmpty
        ? ApiClient.resolveUrl(rawAvatar)
        : null;
    final name = person['name'] as String? ?? 'User';
    final username = person['username'] as String? ?? '';
    final userId = (person['id'] as num?)?.toInt() ?? 0;
    final followers = person['followers'] as String?;
    final reason = person['reason'] as String?;
    final isVerified = person['is_verified'] == true;

    final subtitle = reason != null && reason.isNotEmpty
        ? reason
        : (followers != null && followers.isNotEmpty
            ? followers
            : (username.isNotEmpty ? '@$username' : ''));

    return GestureDetector(
      onTap: () {
        if (username.isNotEmpty) {
          context.push('/u/$username');
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: DesignTokens.primary.withValues(alpha: 0.15),
              backgroundImage: resolvedAvatar != null
                  ? CachedNetworkImageProvider(resolvedAvatar)
                  : null,
              child: resolvedAvatar == null
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'U',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: textPrimary,
                          ),
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
                  const SizedBox(height: 2),
                  Text(
                    username.isNotEmpty && subtitle != '@$username'
                        ? '@$username · $subtitle'
                        : subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _buildFollowButton(userId),
          ],
        ),
      ),
    );
  }

  Widget _buildContactTile({
    required MatchedContact contact,
    required Color cardBg,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final resolvedAvatar =
        contact.avatarUrl != null && contact.avatarUrl!.isNotEmpty
            ? ApiClient.resolveUrl(contact.avatarUrl)
            : null;

    return GestureDetector(
      onTap: () {
        if (contact.username.isNotEmpty) {
          context.push('/u/${contact.username}');
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: DesignTokens.primary.withValues(alpha: 0.15),
              backgroundImage: resolvedAvatar != null
                  ? CachedNetworkImageProvider(resolvedAvatar)
                  : null,
              child: resolvedAvatar == null
                  ? Text(
                      contact.name.isNotEmpty
                          ? contact.name[0].toUpperCase()
                          : 'C',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    contact.username.isNotEmpty
                        ? '@${contact.username} · From contacts'
                        : 'From contacts',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _buildFollowButton(contact.id),
          ],
        ),
      ),
    );
  }

  Widget _buildFollowButton(int userId) {
    if (userId <= 0) return const SizedBox.shrink();
    final currentUserId = ref.read(authProvider).user?.id;
    if (currentUserId != null && userId == currentUserId) {
      return const SizedBox.shrink();
    }
    final isFollowing = ref.watch(followProvider).isFollowing(userId);
    if (isFollowing) {
      return OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: DesignTokens.primary,
          side: BorderSide(
            color: DesignTokens.primary.withValues(alpha: 0.6),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          minimumSize: const Size(80, 32),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onPressed: () {
          ref.read(followProvider.notifier).toggleFollow(userId);
        },
        child: const Text(
          'Following',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      );
    }
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: DesignTokens.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        minimumSize: const Size(80, 32),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 0,
      ),
      onPressed: () {
        ref.read(followProvider.notifier).toggleFollow(userId);
      },
      child: const Text(
        'Follow',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildCommunitiesTab(
    bool isDark,
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
  ) {
    final commState = ref.watch(discoverCommunitiesProvider);
    if (commState.loading && commState.communities.isEmpty) {
      return const Center(
        child: LoadingStateWidget(message: 'Loading spaces...'),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: commState.communities.length,
      itemBuilder: (ctx, i) {
        final c = commState.communities[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: DesignTokens.primary.withValues(alpha: 0.15),
                child: Text(
                  c.name.isNotEmpty
                      ? c.name.substring(0, 1).toUpperCase()
                      : 'C',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      '${c.membersCount} members',
                      style: TextStyle(color: textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: () => context.push('/c/${c.slug}'),
                child: const Text('View'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLiveTab(
    bool isDark,
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
  ) {
    final liveState = ref.watch(liveDiscoveryProvider);

    if (liveState.loading && liveState.streams.isEmpty) {
      return const Center(
        child: LoadingStateWidget(message: 'Searching for live broadcasts...'),
      );
    }

    if (liveState.streams.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => ref.read(liveDiscoveryProvider.notifier).refresh(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: CenteredEmptyStateWidget(
              icon: Icons.live_tv_rounded,
              title: 'No Live Streams Right Now',
              description:
                  'Follow your favorite creators to get notified as soon as they go live.',
              actionLabel: 'Discover Creators',
              onAction: () => _tab.animateTo(2),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(liveDiscoveryProvider.notifier).refresh(),
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.82,
        ),
        itemCount: liveState.streams.length,
        itemBuilder: (ctx, i) {
          final stream = liveState.streams[i];
          return LiveStreamCard(
            stream: stream,
            onTap: () => openLiveStream(ctx, stream.trackingId),
          );
        },
      ),
    );
  }

  Widget _buildSearchResults(
    bool isDark,
    Color cardBg,
    Color textPrimary,
    Color? textSecondary,
  ) {
    if (_searching) {
      return const LoadingStateWidget(
        message: 'Searching creators and topics...',
      );
    }

    if (_userResults.isEmpty && _communityResults.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.person_search_rounded,
        title: 'No results found',
        description:
            'No users or channels matching "$_searchQuery". Try another keyword.',
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        if (_userResults.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'PEOPLE (${_userResults.length})',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: textSecondary,
                letterSpacing: 0.8,
              ),
            ),
          ),
          ..._userResults.map((u) {
            final name = u['name'] as String? ?? 'User';
            final username = u['username'] as String? ?? 'user';
            final avatar = u['avatar_url'] as String? ?? u['avatar'] as String?;
            final fullAvatar = avatar != null
                ? ApiClient.resolveUrl(avatar)
                : null;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: DesignTokens.primary,
                  backgroundImage: fullAvatar != null
                      ? CachedNetworkImageProvider(fullAvatar)
                      : null,
                  child: fullAvatar == null
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'U',
                          style: const TextStyle(color: Colors.white),
                        )
                      : null,
                ),
                title: Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                subtitle: Text(
                  '@$username',
                  style: TextStyle(color: textSecondary),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () => context.push('/u/$username'),
              ),
            );
          }),
          const SizedBox(height: 16),
        ],

        if (_communityResults.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'COMMUNITIES (${_communityResults.length})',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: textSecondary,
                letterSpacing: 0.8,
              ),
            ),
          ),
          ..._communityResults.map((c) {
            final name = c['name'] as String? ?? 'Community';
            final slug = c['slug'] as String? ?? '';
            final count = (c['members_count'] as num?)?.toInt() ?? 0;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF5856D6),
                  child: const Icon(Icons.groups_rounded, color: Colors.white),
                ),
                title: Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                subtitle: Text(
                  '$count members',
                  style: TextStyle(color: textSecondary),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () => context.push('/c/$slug'),
              ),
            );
          }),
        ],
      ],
    );
  }
}

class _FeedList extends ConsumerWidget {
  final String feedType;

  const _FeedList({required this.feedType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myId = ref.watch(authProvider).user?.id ?? 0;
    final source = PostsSource.feed(feedType);
    final state = ref.watch(postsProvider(source));

    if (state.loading && state.posts.isEmpty) {
      return const Center(
        child: LoadingStateWidget(message: 'Loading posts...'),
      );
    }

    if (state.error != null && state.posts.isEmpty) {
      return Center(
        child: ErrorStateWidget(
          title: 'Could not load feed',
          description: state.error!,
          onRetry: () => ref.read(postsProvider(source).notifier).refresh(),
        ),
      );
    }

    if (state.posts.isEmpty) {
      return const Center(
        child: EmptyStateWidget(
          icon: Icons.explore_off_outlined,
          title: 'No posts yet',
          description:
              'Follow creators and communities to see updates in your feed.',
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: state.posts.length,
      itemBuilder: (ctx, i) {
        final post = state.posts[i];
        return PostCard(
          post: post,
          myId: myId,
          source: source,
          onCommentTap: () => showPostComments(
            context,
            post: post,
            myId: myId,
            onAddComment: (content) => ref
                .read(postsProvider(source).notifier)
                .addComment(post, content),
          ),
          onLike: () => ref
              .read(postsProvider(source).notifier)
              .toggleLike(post, myId: myId),
          onSave: () =>
              ref.read(postsProvider(source).notifier).toggleSave(post),
          onShare: () => ref.read(postsProvider(source).notifier).share(post),
          onReport: () => showPostReportDialog(context, post: post),
        );
      },
    );
  }
}
