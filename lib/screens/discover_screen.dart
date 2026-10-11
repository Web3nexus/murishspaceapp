import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../components/reels_viewer_sheet.dart';
import '../components/ui_states.dart';
import '../core/api_client.dart';
import '../core/design_tokens.dart';
import '../providers/auth_provider.dart';
import '../providers/community_provider.dart';
import '../providers/follow_provider.dart';
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
  bool _loadingTrending = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchDiscoveryData();
    });
  }

  Future<void> _fetchDiscoveryData() async {
    try {
      final res = await ApiClient.instance.dio.get('/discover/trending');
      final data = ApiClient.instance.unwrap(res);
      if (data is Map<String, dynamic> && mounted) {
        final topics = data['trending_topics'];
        final creators = data['suggested_creators'];
        setState(() {
          if (topics is List) {
            _trendingTopics = topics.whereType<Map<String, dynamic>>().toList();
          }
          if (creators is List) {
            _suggestedCreators = creators.whereType<Map<String, dynamic>>().toList();
          }
          _loadingTrending = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingTrending = false);
    }
  }

  final List<Map<String, dynamic>> _discoveryMedia = [
    {
      'url': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=600',
      'views': '1.2M',
      'isReel': true,
      'caption': 'Sunset vibes and warm breeze in Costa Blanca! ✨',
      'author': 'Amina Bello',
    },
    {
      'url': 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=600',
      'views': '850K',
      'isReel': true,
      'caption': 'Coastal road trip highlights! 🚗🌊',
      'author': 'Jay Travel',
    },
    {
      'url': 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=600',
      'views': '640K',
      'isReel': true,
      'caption': 'Artisanal wood-fired pizza masterclass! 🍕',
      'author': 'Nana Eats',
    },
    {
      'url': 'https://images.unsplash.com/photo-1517838277536-f5f99be501cd?w=600',
      'views': '430K',
      'isReel': true,
      'caption': 'Morning HIIT & boxing conditioning! 💪',
      'author': 'Lord Uzih',
    },
    {
      'url': 'https://images.unsplash.com/photo-1518611012118-696072aa579a?w=600',
      'views': '320K',
      'isReel': true,
      'caption': 'Sunset yoga on the deck 🧘‍♀️',
      'author': 'Sarah Pulse',
    },
    {
      'url': 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=600',
      'views': '290K',
      'isReel': true,
      'caption': 'Hidden waterfalls in Valencia province 🌿',
      'author': 'ExploreWithUs',
    },
    {
      'url': 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=600',
      'views': '520K',
      'isReel': true,
      'caption': 'Night festival lights & electronic stage! 🎧',
      'author': 'Ibiza Night',
    },
    {
      'url': 'https://images.unsplash.com/photo-1492144534655-ae79c964c9d7?w=600',
      'views': '410K',
      'isReel': true,
      'caption': 'Track day acceleration test with the M4 Competition 🔥',
      'author': 'SpeedZone',
    },
    {
      'url': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=600',
      'views': '380K',
      'isReel': true,
      'caption': 'Calpe cliff overlook view 🏔️',
      'author': 'Lord Uzih',
    },
  ];

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
    _searchDebounce = Timer(const Duration(milliseconds: 300), () => _performSearch(q));
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
            users = (rawResults['users'] as List).whereType<Map<String, dynamic>>().toList();
          }
          if (rawResults['communities'] is List) {
            communities = (rawResults['communities'] as List).whereType<Map<String, dynamic>>().toList();
          }
        }
        if (users.isEmpty && payload['users'] is List) {
          users = (payload['users'] as List).whereType<Map<String, dynamic>>().toList();
        }
        if (communities.isEmpty && payload['communities'] is List) {
          communities = (payload['communities'] as List).whereType<Map<String, dynamic>>().toList();
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
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085);
    final borderColor = isDark ? const Color(0xFF2E384D) : const Color(0xFFE4E7EC);

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
                      Icon(Icons.search_rounded, color: textSecondary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          onSubmitted: (v) => _performSearch(v.trim()),
                          textInputAction: TextInputAction.search,
                          style: TextStyle(fontSize: 14, color: textPrimary, fontWeight: FontWeight.w500),
                          decoration: InputDecoration(
                            hintText: 'Search people, posts, videos, communities...',
                            hintStyle: TextStyle(fontSize: 13, color: textSecondary),
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
                          child: Icon(Icons.close_rounded, size: 18, color: textSecondary),
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
                  labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
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
                _buildForYouTab(isDark, cardBg, textPrimary, textSecondary, borderColor),
                _buildTrendingMediaTab(isDark, cardBg, textPrimary, textSecondary, borderColor),
                _buildPeopleTab(isDark, cardBg, textPrimary, textSecondary),
                _buildCommunitiesTab(isDark, cardBg, textPrimary, textSecondary),
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
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              image: const DecorationImage(
                image: CachedNetworkImageProvider(
                  'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=900',
                ),
                fit: BoxFit.cover,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.85)],
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                  const Text(
                    'Sunset Parties in Costa Blanca',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Music · Travel · Events',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
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
              _categoryPillItem('Music', Icons.music_note_rounded, const Color(0xFF8B5CF6), isDark),
              _categoryPillItem('Travel', Icons.flight_takeoff_rounded, const Color(0xFF10B981), isDark),
              _categoryPillItem('Food', Icons.restaurant_rounded, const Color(0xFFF59E0B), isDark),
              _categoryPillItem('Fashion', Icons.shopping_bag_rounded, const Color(0xFFEC4899), isDark),
              _categoryPillItem('Tech', Icons.devices_rounded, const Color(0xFF0284C7), isDark),
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
              Text(
                'View All',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: DesignTokens.primary,
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
              Text(
                'View All',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: DesignTokens.primary,
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
              final rawAvatar = c['avatar_url'] as String? ?? c['avatar'] as String?;
              final resolvedAvatar = rawAvatar != null && rawAvatar.isNotEmpty ? ApiClient.resolveUrl(rawAvatar) : null;
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
                        backgroundColor: DesignTokens.primary.withValues(alpha: 0.15),
                        backgroundImage: resolvedAvatar != null ? CachedNetworkImageProvider(resolvedAvatar) : null,
                        child: resolvedAvatar == null ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'C') : null,
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
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: DesignTokens.primary,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () {
                            if (creatorId > 0) {
                              ref.read(followProvider.notifier).toggleFollow(creatorId);
                            }
                          },
                          child: const Text(
                            'Follow',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
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
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
          child: GridView.builder(
            padding: const EdgeInsets.all(2),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
              childAspectRatio: 0.75, // Vertical reel aspect ratio
            ),
            itemCount: _discoveryMedia.length,
            itemBuilder: (ctx, i) {
              final item = _discoveryMedia[i];
              return GestureDetector(
                onTap: () {
                  ReelsViewerSheet.show(
                    context,
                    authorName: item['author'] as String,
                    caption: item['caption'] as String,
                    videoThumbnail: item['url'] as String,
                    likesCount: item['views'] as String,
                  );
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: item['url'] as String,
                      fit: BoxFit.cover,
                      placeholder: (ctx, url) => Container(color: cardBg),
                      errorWidget: (ctx, url, err) => Container(color: cardBg),
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
                    // View count badge
                    Positioned(
                      left: 6,
                      bottom: 6,
                      child: Row(
                        children: [
                          const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 14),
                          const SizedBox(width: 2),
                          Text(
                            item['views'] as String,
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
                      child: Icon(Icons.video_library_rounded, color: Colors.white70, size: 14),
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

  Widget _categoryPillItem(String label, IconData icon, Color color, bool isDark) {
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

  Widget _buildPeopleTab(bool isDark, Color cardBg, Color textPrimary, Color textSecondary) {
    if (_loadingTrending && _suggestedCreators.isEmpty) {
      return const Center(child: LoadingStateWidget(message: 'Discovering creators...'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _suggestedCreators.length,
      itemBuilder: (ctx, i) {
        final c = _suggestedCreators[i];
        final rawAvatar = c['avatar_url'] as String? ?? c['avatar'] as String?;
        final resolvedAvatar = rawAvatar != null && rawAvatar.isNotEmpty ? ApiClient.resolveUrl(rawAvatar) : null;
        final name = c['name'] as String? ?? 'Creator';
        final username = c['username'] as String? ?? '';
        final creatorId = (c['id'] as num?)?.toInt() ?? 0;
        final followers = c['followers'] as String? ?? '';

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
                  backgroundImage: resolvedAvatar != null ? CachedNetworkImageProvider(resolvedAvatar) : null,
                  child: resolvedAvatar == null ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'C') : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: textPrimary)),
                      Text('@$username · $followers', style: TextStyle(color: textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DesignTokens.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    if (creatorId > 0) {
                      ref.read(followProvider.notifier).toggleFollow(creatorId);
                    }
                  },
                  child: const Text('Follow'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCommunitiesTab(bool isDark, Color cardBg, Color textPrimary, Color textSecondary) {
    final commState = ref.watch(discoverCommunitiesProvider);
    if (commState.loading && commState.communities.isEmpty) {
      return const Center(child: LoadingStateWidget(message: 'Loading spaces...'));
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
                child: Text(c.name.isNotEmpty ? c.name.substring(0, 1).toUpperCase() : 'C'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: textPrimary)),
                    Text('${c.membersCount} members', style: TextStyle(color: textSecondary, fontSize: 12)),
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

  Widget _buildLiveTab(bool isDark, Color cardBg, Color textPrimary, Color textSecondary) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.live_tv_rounded, color: Color(0xFFDC2626), size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              'No Live Streams Right Now',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'Follow your favorite creators to get notified as soon as they go live.',
              textAlign: TextAlign.center,
              style: TextStyle(color: textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(bool isDark, Color cardBg, Color textPrimary, Color? textSecondary) {
    if (_searching) {
      return const LoadingStateWidget(message: 'Searching creators and topics...');
    }

    if (_userResults.isEmpty && _communityResults.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.person_search_rounded,
        title: 'No results found',
        description: 'No users or channels matching "$_searchQuery". Try another keyword.',
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
            final fullAvatar = avatar != null ? ApiClient.resolveUrl(avatar) : null;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: DesignTokens.primary,
                  backgroundImage: fullAvatar != null ? CachedNetworkImageProvider(fullAvatar) : null,
                  child: fullAvatar == null
                      ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'U', style: const TextStyle(color: Colors.white))
                      : null,
                ),
                title: Text(name, style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary)),
                subtitle: Text('@$username', style: TextStyle(color: textSecondary)),
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
                title: Text(name, style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary)),
                subtitle: Text('$count members', style: TextStyle(color: textSecondary)),
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
      return const Center(child: LoadingStateWidget(message: 'Loading posts...'));
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
          description: 'Follow creators and communities to see updates in your feed.',
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
            onAddComment: (content) => ref.read(postsProvider(source).notifier).addComment(post, content),
          ),
          onLike: () => ref.read(postsProvider(source).notifier).toggleLike(post, myId: myId),
          onSave: () => ref.read(postsProvider(source).notifier).toggleSave(post),
          onShare: () => ref.read(postsProvider(source).notifier).share(post),
          onReport: () => showPostReportDialog(context, post: post),
        );
      },
    );
  }
}
