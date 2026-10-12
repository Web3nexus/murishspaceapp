import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../components/brand_deal_certificate_dialog.dart';
import '../components/brand_deal_milestones_dialog.dart';
import '../core/api_client.dart';
import '../core/design_tokens.dart';
import '../providers/auth_provider.dart';
import 'brand_deals_help_screen.dart';

/// Complete Redesigned Brand Deals Marketplace / Brand Studio (Page B/2)
/// Matching MurihSpace visual reference 2:
/// - Header: "Brand Deals" with "Partner with top brands" subtitle, escrow guide & post deal actions
/// - Category Filter Chips: All, Tech & Electronics, Fashion & Beauty, Fitness, FinTech, Food & Travel
/// - 4 Navigation Tabs: Available Deals, My Applications, Active Deals, Completed
/// - Upwork/Fiverr-style escrow cards with verified brand badges, budget pills, deliverables & milestones
/// - Real backend integration via /api/v1/brand-deals & /api/v1/brands
/// - Clean, professional zero/empty states (no fabricated mock brands).
class BrandDealsScreen extends ConsumerStatefulWidget {
  const BrandDealsScreen({super.key});

  @override
  ConsumerState<BrandDealsScreen> createState() => _BrandDealsScreenState();
}

class _BrandDealsScreenState extends ConsumerState<BrandDealsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 4, vsync: this);

  bool _isLoading = true;
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _allDeals = [];
  List<Map<String, dynamic>> _brands = [];

  final List<String> _categories = [
    'All',
    'Tech & Electronics',
    'Fashion & Beauty',
    'Fitness & Lifestyle',
    'FinTech',
    'Gaming & Streaming',
    'Food & Travel',
  ];

  @override
  void initState() {
    super.initState();
    _fetchDealsAndBrands();
  }

  @override
  void dispose() {
    _tab.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchDealsAndBrands() async {
    setState(() => _isLoading = true);

    try {
      // 1. Fetch real brand deals from backend
      List<Map<String, dynamic>> loadedDeals = [];
      try {
        final res = await ApiClient.instance.dio.get('/brand-deals');
        final data = res.data['data'] ?? res.data;
        if (data is List) {
          loadedDeals = List<Map<String, dynamic>>.from(data);
        } else if (data is Map && data['data'] is List) {
          loadedDeals = List<Map<String, dynamic>>.from(data['data']);
        }
      } catch (_) {
        // Fallback gracefully
      }

      // 2. Fetch brands
      List<Map<String, dynamic>> loadedBrands = [];
      try {
        final bRes = await ApiClient.instance.dio.get('/brands');
        final bData = bRes.data['data'] ?? bRes.data;
        if (bData is List) {
          loadedBrands = List<Map<String, dynamic>>.from(bData);
        }
      } catch (_) {
        // Fallback gracefully
      }

      if (mounted) {
        setState(() {
          _allDeals = loadedDeals;
          _brands = loadedBrands;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> _filterDealsByTab(int tabIndex) {
    List<Map<String, dynamic>> filtered = _allDeals;

    // Filter by tab
    if (tabIndex == 0) {
      // Available (pending or open deals)
      filtered = filtered.where((d) {
        final st = (d['status'] ?? 'open').toString().toLowerCase();
        return st == 'open' || st == 'pending' || st == 'available';
      }).toList();
    } else if (tabIndex == 1) {
      // My Applications / Proposals
      filtered = filtered.where((d) {
        final st = (d['status'] ?? '').toString().toLowerCase();
        return st == 'applied' || st == 'negotiating' || st == 'proposal';
      }).toList();
    } else if (tabIndex == 2) {
      // Active Deals
      filtered = filtered.where((d) {
        final st = (d['status'] ?? '').toString().toLowerCase();
        return st == 'active' || st == 'in_progress';
      }).toList();
    } else if (tabIndex == 3) {
      // Completed Deals
      filtered = filtered.where((d) {
        final st = (d['status'] ?? '').toString().toLowerCase();
        return st == 'completed' || st == 'paid' || st == 'settled';
      }).toList();
    }

    // Filter by Category
    if (_selectedCategory != 'All') {
      filtered = filtered.where((d) {
        final cat = d['category'] ?? d['industry'] ?? d['brand']?['industry'] ?? '';
        return cat.toString().toLowerCase().contains(_selectedCategory.toLowerCase());
      }).toList();
    }

    // Filter by Search Query
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((d) {
        final title = (d['title'] ?? '').toString().toLowerCase();
        final brand = (d['brand']?['name'] ?? d['brandName'] ?? '').toString().toLowerCase();
        return title.contains(q) || brand.contains(q);
      }).toList();
    }

    return filtered;
  }

  /// Parses a budget that may arrive as a number or a formatted string.
  double _parseBudget(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      final cleaned = value.replaceAll(RegExp(r'[^0-9.]'), '');
      return double.tryParse(cleaned) ?? 0;
    }
    return 0;
  }

  /// Parses a deal id that may arrive as a number or a string, returning null
  /// when the value is missing or not a valid integer.
  int? _parseDealId(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  void _showPostBrandDealDialog() {
    final titleCtrl = TextEditingController();
    final brandCtrl = TextEditingController();
    final budgetCtrl = TextEditingController(text: '500');
    final deliverCtrl = TextEditingController();
    String selectedCategory = 'Tech & Electronics';
    String selectedDealType = 'sponsored_post';
    bool isSubmitting = false;

    showModalBottomSheet<void>(
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
          builder: (context, setModalState) {
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
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF9500).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.campaign_rounded, color: Color(0xFFFF9500), size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Post Brand Sponsorship',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: textPrimary,
                                ),
                              ),
                              Text(
                                'Lock budget in Escrow to hire verified creators',
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
                      controller: titleCtrl,
                      style: TextStyle(color: textPrimary),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.title_rounded),
                        labelText: 'Campaign Title',
                        hintText: 'e.g. Summer Showcase Video Review',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: brandCtrl,
                      style: TextStyle(color: textPrimary),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.business_rounded),
                        labelText: 'Brand / Company Name',
                        hintText: 'e.g. Acme Tech',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      dropdownColor: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                      style: TextStyle(color: textPrimary),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.category_rounded),
                        labelText: 'Category',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Tech & Electronics', child: Text('Tech & Electronics')),
                        DropdownMenuItem(value: 'Fashion & Beauty', child: Text('Fashion & Beauty')),
                        DropdownMenuItem(value: 'Fitness & Lifestyle', child: Text('Fitness & Lifestyle')),
                        DropdownMenuItem(value: 'FinTech', child: Text('FinTech & Crypto')),
                        DropdownMenuItem(value: 'Gaming & Streaming', child: Text('Gaming & Streaming')),
                        DropdownMenuItem(value: 'Food & Travel', child: Text('Food & Travel')),
                      ],
                      onChanged: (v) {
                        if (v != null) setModalState(() => selectedCategory = v);
                      },
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: budgetCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
                      decoration: InputDecoration(
                        prefixText: '\$ ',
                        labelText: 'Escrow Budget (USD \$)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [250, 500, 1000, 2500].map((preset) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text('\$$preset', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                            selected: budgetCtrl.text == preset.toString(),
                            onSelected: (_) {
                              setModalState(() => budgetCtrl.text = preset.toString());
                            },
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: deliverCtrl,
                      maxLines: 2,
                      style: TextStyle(color: textPrimary),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.assignment_outlined),
                        labelText: 'Required Deliverables',
                        hintText: 'e.g. 1 60s Reel Video + 2 Story mentions with swipe-up link',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final title = titleCtrl.text.trim();
                                final brandName = brandCtrl.text.trim();
                                final budget = double.tryParse(budgetCtrl.text.trim()) ?? 500;
                                final deliverables = deliverCtrl.text.trim();

                                if (title.isEmpty || brandName.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please fill out campaign title and brand name.')),
                                  );
                                  return;
                                }

                                setModalState(() => isSubmitting = true);

                                try {
                                  // Match an existing brand by the entered name (case-insensitive).
                                  int? brandId;
                                  final normalizedName = brandName.trim().toLowerCase();
                                  if (normalizedName.isNotEmpty) {
                                    for (final brand in _brands) {
                                      final name = (brand['name'] as String?)?.trim().toLowerCase();
                                      if (name == normalizedName) {
                                        final rawId = brand['id'];
                                        brandId = rawId is int
                                            ? rawId
                                            : (rawId is num
                                                ? rawId.toInt()
                                                : int.tryParse(rawId?.toString() ?? ''));
                                        break;
                                      }
                                    }
                                  }

                                  if (brandId == null) {
                                    final brandRes = await ApiClient.instance.dio.post('/brands', data: {
                                      'name': brandName,
                                      'industry': selectedCategory,
                                    });
                                    final rawNewId = brandRes.data['data']?['id'] ?? brandRes.data['id'];
                                    brandId = rawNewId is int
                                        ? rawNewId
                                        : (rawNewId is num
                                            ? rawNewId.toInt()
                                            : int.tryParse(rawNewId?.toString() ?? ''));
                                  }

                                  if (brandId == null) {
                                    throw Exception('Could not resolve a brand for this deal.');
                                  }

                                  await ApiClient.instance.dio.post('/brand-deals', data: {
                                    'brand_id': brandId,
                                    'title': title,
                                    'deal_type': selectedDealType,
                                    'budget': budget.toInt(),
                                    'currency': 'USD',
                                    'deliverables': deliverables,
                                  });

                                  if (context.mounted) {
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Brand deal posted and secured in escrow!')),
                                    );
                                    _fetchDealsAndBrands();
                                  }
                                } catch (e) {
                                  setModalState(() => isSubmitting = false);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Failed to post deal: $e')),
                                    );
                                  }
                                }
                              },
                        child: isSubmitting
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                                'Lock Escrow & Publish Deal',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
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

  void _showApplyModal(Map<String, dynamic> deal) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];
    final pitchCtrl = TextEditingController();
    bool submitting = false;

    final title = (deal['title'] ?? 'Brand Campaign').toString();
    final brandName = (deal['brand']?['name'] ?? deal['brandName'] ?? 'Brand Partner').toString();
    final budget = _parseBudget(deal['budget'] ?? deal['budgetEscrow']);
    final deliverables = (deal['deliverables'] ?? 'Deliverables specified in brief').toString();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Campaign Brief & Pitch',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textPrimary),
                          ),
                          Text(
                            brandName,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: DesignTokens.primary),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '\$${budget.toStringAsFixed(0)} ESCROW',
                        style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w800, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textPrimary),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 18, color: DesignTokens.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          deliverables,
                          style: TextStyle(fontSize: 12, color: textPrimary, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: pitchCtrl,
                  maxLines: 4,
                  style: TextStyle(color: textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Introduce yourself, why you are a great match, and propose your production timeline...',
                    hintStyle: TextStyle(color: textSecondary, fontSize: 13),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: submitting
                        ? null
                        : () async {
                            final pitch = pitchCtrl.text.trim();
                            if (pitch.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please write a short pitch to submit proposal.')),
                              );
                              return;
                            }
                            setModalState(() => submitting = true);
                            try {
                              await ApiClient.instance.dio.post('/brand-proposals', data: {
                                'brand_deal_id': deal['id'],
                                'cover_letter': pitch,
                                'proposed_budget': budget.toInt(),
                              });
                            } catch (e) {
                              if (context.mounted) {
                                setModalState(() => submitting = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Could not submit your application: $e')),
                                );
                              }
                              return;
                            }

                            if (context.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Application submitted successfully!')),
                              );
                              _fetchDealsAndBrands();
                            }
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: DesignTokens.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: submitting
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Submit Application & Lock Pitch', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : const Color(0xFFF8F9FA);
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF111827);
    final textSecondary = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final borderColor = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E7EB);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary, size: 20),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Brand Studio',
              style: TextStyle(
                color: textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 19,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              'Partner with top brands & escrow deals',
              style: TextStyle(
                color: textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BrandDealsHelpScreen()),
              );
            },
            icon: const Icon(Icons.shield_outlined, color: Color(0xFF10B981), size: 22),
            tooltip: 'Escrow Protection Guide',
          ),
          IconButton(
            onPressed: _showPostBrandDealDialog,
            icon: const Icon(Icons.add_circle_outline_rounded, color: DesignTokens.primary, size: 24),
            tooltip: 'Post Sponsorship Deal',
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: borderColor, width: 0.8)),
            ),
            child: TabBar(
              controller: _tab,
              labelColor: DesignTokens.primary,
              unselectedLabelColor: textSecondary,
              indicatorColor: DesignTokens.primary,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              tabs: const [
                Tab(text: 'Available'),
                Tab(text: 'Applied'),
                Tab(text: 'Active'),
                Tab(text: 'Completed'),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // ── SEARCH & CATEGORY CHIPS ───────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: TextStyle(color: textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search brand or campaign title...',
                        hintStyle: TextStyle(color: textSecondary, fontSize: 12),
                        prefixIcon: Icon(Icons.search_rounded, size: 18, color: textSecondary),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear_rounded, size: 16, color: textSecondary),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Categories horizontal scroll
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final cat = _categories[i];
                final isSelected = _selectedCategory == cat;
                return ChoiceChip(
                  label: Text(
                    cat,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.white : textSecondary,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: DesignTokens.primary,
                  backgroundColor: cardBg,
                  side: BorderSide(
                    color: isSelected ? DesignTokens.primary : borderColor,
                  ),
                  onSelected: (_) => setState(() => _selectedCategory = cat),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // ── TAB BAR VIEW ──────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: DesignTokens.primary))
                : TabBarView(
                    controller: _tab,
                    children: List.generate(4, (tabIndex) {
                      final deals = _filterDealsByTab(tabIndex);

                      if (deals.isEmpty) {
                        return _buildEmptyState(
                          tabIndex: tabIndex,
                          isDark: isDark,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        );
                      }

                      return RefreshIndicator(
                        onRefresh: _fetchDealsAndBrands,
                        color: DesignTokens.primary,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: deals.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 14),
                          itemBuilder: (ctx, i) => _buildDealCard(
                            deal: deals[i],
                            tabIndex: tabIndex,
                            isDark: isDark,
                            cardBg: cardBg,
                            borderColor: borderColor,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                        ),
                      );
                    }),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required int tabIndex,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    String title = 'No brand deals available';
    String subtitle = 'Check back soon or post a sponsorship brief to hire creators.';
    IconData icon = Icons.campaign_outlined;

    if (tabIndex == 1) {
      title = 'No active applications';
      subtitle = 'Browse available deals and pitch to brands to start working.';
      icon = Icons.assignment_outlined;
    } else if (tabIndex == 2) {
      title = 'No active campaigns';
      subtitle = 'Once a brand approves your proposal, active milestones will appear here.';
      icon = Icons.verified_user_outlined;
    } else if (tabIndex == 3) {
      title = 'No completed deals yet';
      subtitle = 'Successfully delivered brand deals with escrow certificates will appear here.';
      icon = Icons.workspace_premium_outlined;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: DesignTokens.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: DesignTokens.primary),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: textSecondary),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _showPostBrandDealDialog,
              style: FilledButton.styleFrom(
                backgroundColor: DesignTokens.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Post Brand Deal', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDealCard({
    required Map<String, dynamic> deal,
    required int tabIndex,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final title = (deal['title'] ?? 'Campaign Title').toString();
    final brand = deal['brand'] as Map<String, dynamic>?;
    final brandName = (brand?['name'] ?? deal['brandName'] ?? 'Brand Partner').toString();
    final logoUrl = brand?['logo_url'] ?? deal['logo'];
    final category = (deal['category'] ?? brand?['industry'] ?? 'General').toString();
    final budget = _parseBudget(deal['budget'] ?? deal['budgetEscrow']);
    final deliverables = (deal['deliverables'] ?? '1 Reel + 2 Stories').toString();
    final dealId = _parseDealId(deal['id']);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Brand avatar + Name + Escrow Pill
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E7EB),
                backgroundImage: logoUrl != null && logoUrl.toString().isNotEmpty
                    ? CachedNetworkImageProvider(logoUrl.toString())
                    : null,
                child: logoUrl == null || logoUrl.toString().isEmpty
                    ? Text(
                        brandName.isNotEmpty ? brandName[0].toUpperCase() : 'B',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
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
                            brandName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.verified_rounded, color: DesignTokens.primary, size: 15),
                      ],
                    ),
                    Text(
                      category,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: textSecondary),
                    ),
                  ],
                ),
              ),
              // Escrow Protection Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_rounded, color: Color(0xFF10B981), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '\$${budget.toStringAsFixed(0)} ESCROW',
                      style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Title
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: textPrimary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),

          // Deliverables Container
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.assignment_outlined, size: 16, color: DesignTokens.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    deliverables,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: textPrimary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Action Buttons
          Row(
            children: [
              if (tabIndex == 0) ...[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: dealId == null ? null : () => _showApplyModal(deal),
                    style: FilledButton.styleFrom(
                      backgroundColor: DesignTokens.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.send_rounded, size: 16),
                    label: const Text('View Brief & Apply', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ),
              ] else if (tabIndex == 2) ...[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: dealId == null
                        ? null
                        : () {
                            BrandDealMilestonesDialog.show(
                              context,
                              dealId: dealId,
                              dealTitle: title,
                              budget: budget,
                            );
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.rule_folder_rounded, size: 16),
                    label: const Text('Track Milestones', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ),
              ] else if (tabIndex == 3) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: dealId == null
                        ? null
                        : () {
                            final user = ref.read(authProvider).user;
                            BrandDealCertificateDialog.show(
                              context,
                              dealTitle: title,
                              brandName: brandName,
                              creatorName: user?.name ?? 'Creator',
                              totalBudget: budget,
                              depositAmount: budget,
                              depositPercentage: 100,
                              deliverables: deliverables,
                            );
                          },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textPrimary,
                      side: BorderSide(color: borderColor),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 16),
                    label: const Text('View Certificate', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ),
              ] else ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: dealId == null ? null : () => _showApplyModal(deal),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textPrimary,
                      side: BorderSide(color: borderColor),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text('Review Proposal', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
