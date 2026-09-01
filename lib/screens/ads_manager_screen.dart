import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../components/app_bottom_sheet.dart';
import '../core/design_tokens.dart';
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
  String _selectedObjective = 'Conversions for Ads';
  final _campaignTitleController = TextEditingController(text: 'Summer Catalog Special');
  double _dailyBudget = 25.0;
  int _durationDays = 7;
  String _ctaButtonText = 'Shop Now';
  MarketplaceProduct? _selectedCatalogItem;

  // Mock Active Campaigns List for Status View
  final List<Map<String, dynamic>> _mockCampaigns = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final activeW = wallet.wallets.isNotEmpty ? wallet.wallets.first : null;
    final bal = (activeW?.available ?? 0) / 100.0;

    final confirm = await AppBottomSheet.showConfirmation(
      context: context,
      title: 'Confirm Campaign Launch',
      message: 'Campaign: ${_campaignTitleController.text}\nObjective: $_selectedObjective\nDuration: $_durationDays Days\nTotal Budget: \$${totalBudget.toStringAsFixed(2)}\nWallet Balance: \$${bal.toStringAsFixed(2)}',
      confirmText: 'Launch Now',
      icon: Icons.campaign_rounded,
    );

    if (confirm == true) {
      setState(() {
        _mockCampaigns.insert(0, {
          'id': 'AD-${(1000 + _mockCampaigns.length * 17)}',
          'title': _campaignTitleController.text.trim(),
          'objective': _selectedObjective,
          'status': 'ACTIVE',
          'impressions': 0,
          'clicks': 0,
          'conversions': 0,
          'spent': 0.0,
          'budget': totalBudget,
          'image': _selectedCatalogItem?.images.firstOrNull ?? 'https://picsum.photos/seed/ad/200/200',
        });
      });

      _tabController.animateTo(2); // Jump to Status View

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Campaign launched successfully! It is now live.'),
          backgroundColor: Color(0xFF34C759),
        ),
      );
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
          // "For You: Create Your Ads Today" Banner Card
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Container(
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
                    color: const Color(0xFF007AFF).withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
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
                            const SizedBox(width: 8),
                            if (!verified)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF9500),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Verification Needed',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
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
                          'Promote products & boost high-conversion sales across feeds and messenger.',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
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
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF007AFF),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text('Start Ad', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
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
    final objectives = [
      'Conversions for Ads',
      'Catalog Sales',
      'Profile & Reach',
      'Lead Generation',
    ];

    final ctaOptions = ['Shop Now', 'Send Message', 'Join Community', 'Learn More'];

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
                    Text('\$${(_dailyBudget * _durationDays).toStringAsFixed(2)} USD',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF34C759))),
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
    final products = marketplaceState.products;

    if (marketplaceState.isLoading && products.isEmpty) {
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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Active & Past Campaigns',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: textPrimary)),
            Text('${_mockCampaigns.length} Campaigns',
                style: TextStyle(color: textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 14),
        if (_mockCampaigns.isEmpty)
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
            itemCount: _mockCampaigns.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (ctx, i) {
            final ad = _mockCampaigns[i];
            final status = ad['status'] as String;
            final isLive = status == 'ACTIVE';

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
                        child: Image.network(
                          ad['image'] as String,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 48,
                            height: 48,
                            color: Colors.grey,
                            child: const Icon(Icons.campaign),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ad['title'] as String,
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: textPrimary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            Text('${ad['id']} · ${ad['objective']}',
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
                          status,
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

                  // Metrics Grid
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _metricBox('Impressions', '${ad['impressions']}', textPrimary, textSecondary),
                      _metricBox('Clicks', '${ad['clicks']}', textPrimary, textSecondary),
                      _metricBox('Conversions', '${ad['conversions']}', const Color(0xFF007AFF), textSecondary),
                      _metricBox('Spent', '\$${ad['spent']}', const Color(0xFF34C759), textSecondary),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
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
