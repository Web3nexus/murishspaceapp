import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../components/app_bottom_sheet.dart';
import '../core/api_client.dart';
import '../core/currency_formatter.dart';
import '../core/roles.dart';
import '../models/marketplace_models.dart';
import '../providers/auth_provider.dart';
import '../providers/marketplace_provider.dart';
import '../providers/wallet_provider.dart';

/// MurihSpace Sponsored Ads & Catalog Promotion Center.
class AdsManagerScreen extends ConsumerStatefulWidget {
  const AdsManagerScreen({super.key});

  @override
  ConsumerState<AdsManagerScreen> createState() => _AdsManagerScreenState();
}

class _AdsManagerScreenState extends ConsumerState<AdsManagerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // New Ad Campaign state
  String _selectedObjective = 'Catalog Sales';
  final _campaignTitleController = TextEditingController(text: 'Summer Catalog Special');
  double _dailyBudget = 25.0;
  int _durationDays = 7;
  String _ctaButtonText = 'Shop Now';
  MarketplaceProduct? _selectedCatalogItem;

  // Real campaigns from GET /ads (Status View is server-driven, never mock).
  final List<Map<String, dynamic>> _campaigns = [];
  bool _loadingCampaigns = false;

  // Server-driven ad meta from GET /ads/meta — objectives and CTAs are
  // sourced from the backend, not hardcoded.
  final List<Map<String, dynamic>> _objectives = [];
  final List<String> _ctaOptions = [
    'Shop Now',
    'Send Message',
    'Join Community',
    'Learn More',
  ];
  final List<String> _campaignStatuses = [];
  final List<String> _reviewStatuses = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(marketplaceProvider.notifier).fetchMyProducts();
      _fetchMeta();
      _fetchCampaigns();
    });
  }

  Future<void> _fetchMeta() async {
    try {
      final res = await ApiClient.instance.dio.get('/ads/meta');
      final m = res.data;
      if (m is! Map<String, dynamic>) return;
      final objs = m['objectives'];
      if (objs is List) {
        final parsed = <Map<String, dynamic>>[];
        for (final e in objs) {
          if (e is Map) parsed.add(Map<String, dynamic>.from(e));
        }
        if (parsed.isNotEmpty) setState(() => _objectives..clear()..addAll(parsed));
      }
      final ctas = m['cta_options'];
      if (ctas is List && ctas.isNotEmpty) {
        setState(() => _ctaOptions..clear()..addAll(ctas.map((e) => e.toString())));
      }
      final sts = m['statuses'];
      if (sts is List) {
        setState(() => _campaignStatuses..clear()..addAll(sts.map((e) => e.toString())));
      }
      final rev = m['review_statuses'];
      if (rev is List) {
        setState(() => _reviewStatuses..clear()..addAll(rev.map((e) => e.toString())));
      }
    } catch (_) {}
  }

  Future<void> _fetchCampaigns() async {
    setState(() => _loadingCampaigns = true);
    try {
      final res = await ApiClient.instance.dio.get('/ads');
      final payload = ApiClient.instance.unwrap(res);
      List<dynamic> raw = [];
      if (payload is List) {
        raw = payload;
      } else if (payload is Map && payload['data'] is List) {
        raw = payload['data'] as List<dynamic>;
      }
      final list = <Map<String, dynamic>>[];
      for (final e in raw) {
        if (e is Map) list.add(Map<String, dynamic>.from(e));
      }
      if (mounted) {
        setState(() {
          _campaigns
            ..clear()
            ..addAll(list);
          _loadingCampaigns = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingCampaigns = false);
    }
  }

  String? _objectiveCodeFor(String label) {
    for (final o in _objectives) {
      if (o['label']?.toString() == label) return o['value']?.toString();
    }
    return null;
  }

  String _objectiveLabelFor(String? code) {
    for (final o in _objectives) {
      if (o['value']?.toString() == code) return o['label']?.toString() ?? code ?? '';
    }
    return code?.replaceAll('_', ' ') ?? '';
  }

  @override
  void dispose() {
    _tabController.dispose();
    _campaignTitleController.dispose();
    super.dispose();
  }

  bool _isAccountVerified() {
    final user = ref.read(authProvider).user;
    if (user == null) return false;
    return user.isVerified ||
        user.role == UserRole.creator ||
        user.role == UserRole.vendor ||
        user.role == UserRole.admin;
  }

  void _showVerificationRequiredModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFF9500).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.verified_user_rounded,
                  color: Color(0xFFFF9500), size: 36),
            ),
            const SizedBox(height: 16),
            const Text(
              'Account Verification Required',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'High-conversion Ad Campaigns require a verified Creator or Vendor account to ensure safety and trust across MurihSpace Escrow.',
              style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.push('/kyc');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007AFF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Verify Identity (KYC)', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.push('/upgrade-account');
                },
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Upgrade to Creator or Vendor', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchCampaign() async {
    if (!_isAccountVerified()) {
      _showVerificationRequiredModal();
      return;
    }

    final totalBudget = _dailyBudget * _durationDays;
    final wallet = ref.read(walletProvider);

    final activeW = wallet.wallets.isNotEmpty ? wallet.wallets.first : null;
    final bal = (activeW?.available ?? 0) / 100.0;

    final sysWallet = wallet.wallets.where((w) => w.type == WalletType.system).firstOrNull;
    final localRate = sysWallet?.localRate ?? 0.0;
    final localCurrency = sysWallet?.localCurrency ?? 'USD';

    final confirm = await AppBottomSheet.showConfirmation(
      context: context,
      title: 'Confirm Campaign Launch',
      message: 'Campaign: ${_campaignTitleController.text}\nObjective: $_selectedObjective\nDuration: $_durationDays Days\nTotal Budget: ${CurrencyFormatter.formatDual((totalBudget * 100).round(), localRate: localRate, localCurrency: localCurrency)}\nWallet Balance: \$${bal.toStringAsFixed(2)}',
      confirmText: 'Launch Now',
      icon: Icons.campaign_rounded,
    );

    if (confirm == true) {
      final start = DateTime.now();
      final end = start.add(Duration(days: _durationDays));
      final image = _selectedCatalogItem?.images.firstOrNull ?? '';
      final productId = int.tryParse(_selectedCatalogItem?.id ?? '');

      try {
        final res = await ApiClient.instance.dio.post('/ads', data: {
          'name': _campaignTitleController.text.trim(),
          'objective': _objectiveCodeFor(_selectedObjective) ?? 'product_sales',
          'daily_budget': _dailyBudget,
          'total_budget': totalBudget,
          'start_date': start.toIso8601String(),
          'end_date': end.toIso8601String(),
          'targeting': <String, dynamic>{},
          'placements': ['home_feed', 'community_feed', 'video_feed', 'marketplace', 'search'],
          'headline': _campaignTitleController.text.trim(),
          'description': 'Promoted catalog item via MurihSpace Ads.',
          'cta_text': _ctaButtonText,
          'destination_url': null,
          'media_url': image.isEmpty ? null : image,
          'media_type': image.isEmpty ? null : 'image',
          if (_selectedCatalogItem != null)
            'promotable_type': _selectedCatalogItem!.productType == 'digital' ? 'digital' : 'physical',
          if (_selectedCatalogItem != null && productId != null) 'promotable_id': productId,
        });
        ApiClient.instance.unwrap(res);

        await _fetchCampaigns();
        if (!mounted) return;
        _tabController.animateTo(2);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Campaign launched! It was submitted for review and is now live.'),
            backgroundColor: Color(0xFF34C759),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not launch campaign. Please try again.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF18191A) : const Color(0xFFF2F2F7);
    final cardBg = isDark ? const Color(0xFF242526) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];
    final verified = _isAccountVerified();

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Sponsored Ads & Catalog Hub',
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.w900, fontSize: 20),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF007AFF),
          unselectedLabelColor: textSecondary,
          indicatorColor: const Color(0xFF007AFF),
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'Create Ad'),
            Tab(text: 'Catalog View'),
            Tab(text: 'Status View'),
          ],
        ),
      ),
      body: Column(
        children: [
          // "For You: Create Your Ads Today" Banner Card — Premium Clean Design
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Builder(builder: (context) {
              final isDarkCard = Theme.of(context).brightness == Brightness.dark;
              final cardBg = isDarkCard ? const Color(0xFF1A1D27) : const Color(0xFFF8FAFC);
              final borderColor = isDarkCard ? const Color(0xFF2E3347) : const Color(0xFFDDE3EF);
              final titleColor = isDarkCard ? Colors.white : const Color(0xFF0D1117);
              final subtitleColor = isDarkCard ? const Color(0xFF8B92A5) : const Color(0xFF5A6478);

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: borderColor, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDarkCard ? 0.25 : 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Left accent bar
                    Container(
                      width: 3,
                      height: 64,
                      margin: const EdgeInsets.only(right: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00C9A7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00C9A7).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFF00C9A7).withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: const Text(
                                  'FOR YOU',
                                  style: TextStyle(
                                    color: Color(0xFF00C9A7),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 9,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              if (!verified) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF9500).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Verification Needed',
                                    style: TextStyle(color: Color(0xFFFF9500), fontWeight: FontWeight.bold, fontSize: 9),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Create Your Ads Today',
                            style: TextStyle(
                              color: titleColor,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Promote products & boost high-conversion sales across feeds and messenger.',
                            style: TextStyle(color: subtitleColor, fontSize: 12, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () {
                        _tabController.animateTo(0);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00C9A7),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      child: const Text('Start Ad', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                    ),
                  ],
                ),
              );
            }),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Conversions for Ads (Create Ad Form)
                _buildCreateAdTab(cardBg, textPrimary, textSecondary, isDark),

                // Tab 2: Catalog View (Promote Catalog Items)
                _buildCatalogViewTab(cardBg, textPrimary, textSecondary, isDark),

                // Tab 3: Status View (Promoted Ads Tracking)
                _buildStatusViewTab(cardBg, textPrimary, textSecondary, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 1: Conversions for Ads Creation
  // ---------------------------------------------------------------------------
  Widget _buildCreateAdTab(Color cardBg, Color textPrimary, Color? textSecondary, bool isDark) {
    // Objectives and CTAs come from GET /ads/meta (server-driven), with a
    // safe fallback only while the initial request is in flight.
    final objectives = _objectives.isNotEmpty
        ? _objectives.map((o) => o['label']?.toString() ?? '').where((e) => e.isNotEmpty).toList()
        : const ['Catalog Sales'];
    final ctaOptions = _ctaOptions;

    final sysWallet = ref.watch(walletProvider).wallets.where((w) => w.type == WalletType.system).firstOrNull;
    final localRate = sysWallet?.localRate ?? 0.0;
    final localCurrency = sysWallet?.localCurrency ?? 'USD';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Select Campaign Objective',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: textPrimary)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: objectives.map((obj) {
                final selected = _selectedObjective == obj;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(obj),
                    selected: selected,
                    selectedColor: const Color(0xFF007AFF),
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : textPrimary,
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (val) {
                      if (val) setState(() => _selectedObjective = obj);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 18),

          Text('Campaign Details',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: textPrimary)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                TextField(
                  controller: _campaignTitleController,
                  style: TextStyle(color: textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Campaign Name',
                    labelStyle: TextStyle(color: textSecondary),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _ctaButtonText,
                  dropdownColor: cardBg,
                  decoration: InputDecoration(
                    labelText: 'Call to Action Button',
                    labelStyle: TextStyle(color: textSecondary),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: ctaOptions.map((opt) {
                    return DropdownMenuItem(value: opt, child: Text(opt, style: TextStyle(color: textPrimary)));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _ctaButtonText = val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          Text('Budget & Duration',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: textPrimary)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Daily Budget:', style: TextStyle(color: textSecondary, fontSize: 14)),
                    Text('\$${_dailyBudget.toInt()}/day',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF007AFF))),
                  ],
                ),
                Slider(
                  value: _dailyBudget,
                  min: 5,
                  max: 200,
                  divisions: 39,
                  activeColor: const Color(0xFF007AFF),
                  onChanged: (val) => setState(() => _dailyBudget = val),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Duration:', style: TextStyle(color: textSecondary, fontSize: 14)),
                    Text('$_durationDays Days',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: textPrimary)),
                  ],
                ),
                Slider(
                  value: _durationDays.toDouble(),
                  min: 1,
                  max: 30,
                  divisions: 29,
                  activeColor: const Color(0xFF5856D6),
                  onChanged: (val) => setState(() => _durationDays = val.toInt()),
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Budget:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(
                      CurrencyFormatter.formatDual((_dailyBudget * _durationDays * 100).round(), localRate: localRate, localCurrency: localCurrency),
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF34C759)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _launchCampaign,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text('Launch Ad Campaign', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 2: Catalog View (Promote Catalog Item)
  // ---------------------------------------------------------------------------
  Widget _buildCatalogViewTab(Color cardBg, Color textPrimary, Color? textSecondary, bool isDark) {
    final marketplaceState = ref.watch(marketplaceProvider);
    final products = marketplaceState.myProducts;

    if (marketplaceState.myProductsLoading && products.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Select a Product from Your Catalog to Promote',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          'Promoted items get priority placement at top of feed, search, and catalog view.',
          style: TextStyle(fontSize: 12, color: textSecondary),
        ),
        const SizedBox(height: 16),
        if (products.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                const Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey),
                const SizedBox(height: 12),
                Text('No Catalog Items Yet',
                    style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary)),
                const SizedBox(height: 4),
                Text('Add items to your shop catalog to start promoting.',
                    style: TextStyle(color: textSecondary, fontSize: 12)),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: products.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) {
              final item = products[i];
              final isSelected = _selectedCatalogItem?.id == item.id;

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF007AFF) : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        item.images.isNotEmpty ? item.images.first : 'https://picsum.photos/seed/item/100/100',
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 64,
                          height: 64,
                          color: Colors.grey[800],
                          child: const Icon(Icons.image, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.title,
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text('\$${item.price.toStringAsFixed(2)} USD · ${item.category}',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF34C759), fontSize: 13)),
                          const SizedBox(height: 4),
                          Text('Est. reach: 8,500 - 15,000 views',
                              style: TextStyle(fontSize: 11, color: textSecondary)),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _selectedCatalogItem = item;
                          _campaignTitleController.text = 'Promote: ${item.title}';
                          _selectedObjective = 'Catalog Sales';
                        });
                        _tabController.animateTo(0);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF007AFF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      child: const Text('Promote', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 3: Status View (Promoted Ads Tracking)
  // ---------------------------------------------------------------------------
  Widget _buildStatusViewTab(Color cardBg, Color textPrimary, Color? textSecondary, bool isDark) {
    if (_loadingCampaigns && _campaigns.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _fetchCampaigns,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Active & Past Campaigns',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: textPrimary)),
              Text('${_campaigns.length} Campaigns',
                  style: TextStyle(color: textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 14),
          if (_campaigns.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(20)),
              child: Column(
                children: [
                  Icon(Icons.campaign_outlined, size: 40, color: textSecondary),
                  const SizedBox(height: 10),
                  Text('No campaigns created yet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textPrimary)),
                  const SizedBox(height: 4),
                  Text('Create an ad campaign above to promote products or channels.', style: TextStyle(fontSize: 12, color: textSecondary), textAlign: TextAlign.center),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _campaigns.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (ctx, i) => _buildCampaignCard(_campaigns[i], cardBg, textPrimary, textSecondary),
            ),
        ],
      ),
    );
  }

  Widget _buildCampaignCard(Map<String, dynamic> c, Color cardBg, Color textPrimary, Color? textSecondary) {
    final status = c['status']?.toString() ?? 'draft';
    final reviewStatus = c['review_status']?.toString() ?? 'pending';
    final isLive = status == 'active' && reviewStatus == 'approved';

    final creatives = c['creatives'] is List ? (c['creatives'] as List) : const [];
    String image = '';
    if (creatives.isNotEmpty && creatives.first is Map) {
      image = (creatives.first as Map)['media_url']?.toString() ?? '';
    }

    final dailyBudget = (c['daily_budget'] as num?)?.toDouble();
    final totalBudget = (c['total_budget'] as num?)?.toDouble();
    final objective = _objectiveLabelFor(c['objective']?.toString());

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: image.isNotEmpty
                    ? Image.network(
                        image,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 48,
                          height: 48,
                          color: Colors.grey,
                          child: const Icon(Icons.campaign),
                        ),
                      )
                    : Container(
                        width: 48,
                        height: 48,
                        color: Colors.grey[800],
                        child: const Icon(Icons.campaign, color: Colors.white),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c['name']?.toString() ?? 'Campaign',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text('#${c['id']} · $objective',
                        style: TextStyle(fontSize: 11, color: textSecondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isLive ? const Color(0xFF34C759).withOpacity(0.15) : Colors.grey.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  reviewStatus,
                  style: TextStyle(
                    color: isLive ? const Color(0xFF34C759) : textSecondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _metricBox('Status', status, isLive ? const Color(0xFF34C759) : textPrimary, textSecondary),
              _metricBox('Daily', dailyBudget != null ? '\$${dailyBudget.toStringAsFixed(2)}' : '—', textPrimary, textSecondary),
              _metricBox('Total', totalBudget != null ? '\$${totalBudget.toStringAsFixed(2)}' : '—', const Color(0xFF007AFF), textSecondary),
              _metricBox('Review', reviewStatus, const Color(0xFF5856D6), textSecondary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricBox(String title, String val, Color valColor, Color? textSecondary) {
    return Column(
      children: [
        Text(val, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: valColor)),
        const SizedBox(height: 2),
        Text(title, style: TextStyle(fontSize: 11, color: textSecondary)),
      ],
    );
  }
}
