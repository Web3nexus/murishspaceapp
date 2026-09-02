import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../models/post_models.dart';
import '../providers/auth_provider.dart';
import '../providers/saved_messages_provider.dart';
import 'post_card.dart';

/// Unified Saved Posts & Personal Vault Hub.
class SavedPostsScreen extends ConsumerStatefulWidget {
  const SavedPostsScreen({super.key});

  @override
  ConsumerState<SavedPostsScreen> createState() => _SavedPostsScreenState();
}

class _SavedPostsScreenState extends ConsumerState<SavedPostsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Saved Feed Posts state
  List<Post> _savedPosts = [];
  bool _loadingPosts = true;
  String? _postsError;

  // Saved Notes state
  final _inputCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  String _selectedCategory = 'notes';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchSavedPosts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _inputCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchSavedPosts() async {
    setState(() {
      _loadingPosts = true;
      _postsError = null;
    });

    try {
      final res = await ApiClient.instance.dio.get('/posts/saved');
      final payload = res.data;
      final rawList = payload is Map<String, dynamic>
          ? (payload['data'] is List ? payload['data'] : payload['data']?['data'])
          : payload;

      if (mounted) {
        setState(() {
          if (rawList is List) {
            _savedPosts = rawList
                .whereType<Map<String, dynamic>>()
                .map((j) => Post.fromJson(j))
                .toList();
          } else {
            _savedPosts = [];
          }
          _loadingPosts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _postsError = 'Could not load saved posts.';
          _loadingPosts = false;
        });
      }
    }
  }

  Future<void> _toggleSavePost(Post post) async {
    HapticFeedback.lightImpact();
    try {
      final res = await ApiClient.instance.dio.post('/posts/${post.id}/save');
      final payload = res.data;
      final isSaved = payload is Map<String, dynamic> ? payload['saved'] as bool? ?? false : false;

      if (mounted) {
        if (!isSaved) {
          setState(() => _savedPosts.removeWhere((p) => p.id == post.id));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Removed from Saved Posts.')),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update bookmark.')),
        );
      }
    }
  }

  void _addNote() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    ref.read(savedMessagesProvider.notifier).saveMessage(text, category: _selectedCategory);
    _inputCtrl.clear();
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Note saved to personal vault!'),
        backgroundColor: Color(0xFF34C759),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : const Color(0xFFEFF1F5);
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];
    final myId = ref.watch(authProvider).user?.id ?? 0;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Saved & Bookmarks',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: textPrimary),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF007AFF),
          unselectedLabelColor: textSecondary,
          indicatorColor: const Color(0xFF007AFF),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bookmark_rounded, size: 16),
                  const SizedBox(width: 6),
                  Text('Saved Posts (${_savedPosts.length})'),
                ],
              ),
            ),
            const Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline_rounded, size: 16),
                  SizedBox(width: 6),
                  Text('Personal Vault'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Tab 1: Saved Feed Posts ─────────────────────────────
          RefreshIndicator(
            onRefresh: _fetchSavedPosts,
            child: _loadingPosts
                ? const Center(child: CircularProgressIndicator())
                : _postsError != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_postsError!, style: TextStyle(color: textSecondary)),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _fetchSavedPosts,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _savedPosts.isEmpty
                        ? ListView(
                            children: [
                              SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                              Center(
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF007AFF).withOpacity(0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.bookmark_border_rounded, size: 48, color: Color(0xFF007AFF)),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No Saved Posts Yet',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textPrimary),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Bookmark interesting posts in your feed to read them anytime.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: textSecondary, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            itemCount: _savedPosts.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (ctx, idx) {
                              final post = _savedPosts[idx];
                              return PostCard(
                                post: post,
                                myId: myId,
                                onSave: () => _toggleSavePost(post),
                              );
                            },
                          ),
          ),

          // ── Tab 2: Personal Vault & Notes ───────────────────────
          _buildPersonalVaultTab(isDark, textPrimary, textSecondary),
        ],
      ),
    );
  }

  Widget _buildPersonalVaultTab(bool isDark, Color textPrimary, Color? textSecondary) {
    final state = ref.watch(savedMessagesProvider);
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    final categories = <Map<String, dynamic>>[
      {'id': 'notes', 'label': 'Notes', 'icon': Icons.note_alt_rounded},
      {'id': 'links', 'label': 'Links', 'icon': Icons.link_rounded},
      {'id': 'media', 'label': 'Media', 'icon': Icons.image_rounded},
      {'id': 'code', 'label': 'Code', 'icon': Icons.code_rounded},
    ];

    return Column(
      children: [
        // Category Pills
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: cardBg,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: categories.map((cat) {
                final isSelected = _selectedCategory == cat['id'];
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat['id'] as String),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF007AFF) : (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F4F7)),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(cat['icon'] as IconData, size: 14, color: isSelected ? Colors.white : textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          cat['label'] as String,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : textPrimary),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // Quick Note Input Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: cardBg,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputCtrl,
                  style: TextStyle(color: textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Save a quick note or link to vault…',
                    hintStyle: TextStyle(color: textSecondary, fontSize: 13),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F4F7),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                  ),
                  onSubmitted: (_) => _addNote(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _addNote,
                icon: const Icon(Icons.send_rounded, color: Color(0xFF007AFF)),
              ),
            ],
          ),
        ),

        // Notes List
        Expanded(
          child: state.messages.isEmpty
              ? Center(
                  child: Text('No notes in vault yet.', style: TextStyle(color: textSecondary)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: state.messages.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, idx) {
                    final item = state.messages[idx];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.text, style: TextStyle(fontSize: 14, color: textPrimary)),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF007AFF).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(item.category ?? 'Note', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF007AFF))),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.grey),
                                onPressed: () => ref.read(savedMessagesProvider.notifier).deleteMessage(item.id),
                              ),
                            ],
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
}
