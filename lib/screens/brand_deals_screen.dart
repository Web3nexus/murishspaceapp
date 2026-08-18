import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/brand_deal_certificate_dialog.dart';
import '../components/brand_deal_milestones_dialog.dart';
import '../providers/admin_moderation_provider.dart';
import 'brand_deals_help_screen.dart';

/// Creator Hub & Brand Deals Marketplace (with Escrow support).
class BrandDealsScreen extends ConsumerStatefulWidget {
  const BrandDealsScreen({super.key});

  @override
  ConsumerState<BrandDealsScreen> createState() => _BrandDealsScreenState();
}

class _BrandDealsScreenState extends ConsumerState<BrandDealsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);

  final List<_BrandDealItem> _availableDeals = [
    _BrandDealItem(
      title: 'MurihSpace Summer Tech Showcase Video',
      brandName: 'Apex Audio Tech',
      budgetEscrow: 1500,
      deliverables: '1 YouTube / Reel Review (60s) + 2 Stories',
      requiredFollowers: '5k+ followers',
      category: 'Tech & Electronics',
      status: 'Open',
    ),
    _BrandDealItem(
      title: 'Fitness Apparel Ambassador Campaign',
      brandName: 'Pulse Activewear',
      budgetEscrow: 850,
      deliverables: '2 High-res Photo Posts + Promo Code',
      requiredFollowers: '2k+ followers',
      category: 'Fitness & Lifestyle',
      status: 'Open',
    ),
    _BrandDealItem(
      title: 'Web3 & FinTech Wallet Launch Review',
      brandName: 'Aether Capital',
      budgetEscrow: 3000,
      deliverables: 'Dedicated Tutorial Video & Live Q&A',
      requiredFollowers: '10k+ followers',
      category: 'FinTech',
      status: 'Open',
    ),
  ];

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _showPostBrandDealDialog() {
    final titleCtrl = TextEditingController();
    final brandCtrl = TextEditingController(text: 'My Brand Store');
    final budgetCtrl = TextEditingController(text: '500');
    final deliverCtrl = TextEditingController();
    String selectedCategory = 'Tech & Electronics';
    String requiredFollowers = '5k+ followers';

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
                    // Top Drag Handle
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

                    // Header Row
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
                                'Post Brand Deal Sponsorship',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: textPrimary,
                                ),
                              ),
                              Text(
                                'Lock budget in Escrow to hire top creators',
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

                    // Campaign Title Input
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

                    // Brand Name Input
                    TextField(
                      controller: brandCtrl,
                      style: TextStyle(color: textPrimary),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.business_rounded),
                        labelText: 'Brand / Store Name',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Category Dropdown Selector
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

                    // Escrow Budget Input with Quick Presets
                    TextField(
                      controller: budgetCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textPrimary),
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
                            label: Text('\$$preset', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            selected: budgetCtrl.text == preset.toString(),
                            onSelected: (_) {
                              setModalState(() => budgetCtrl.text = preset.toString());
                            },
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),

                    // Required Creator Followers
                    DropdownButtonFormField<String>(
                      value: requiredFollowers,
                      dropdownColor: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                      style: TextStyle(color: textPrimary),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.people_alt_rounded),
                        labelText: 'Required Creator Followers',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Open to All', child: Text('Open to All Creators')),
                        DropdownMenuItem(value: '1k+ followers', child: Text('Nano Influencers (1k+ followers)')),
                        DropdownMenuItem(value: '5k+ followers', child: Text('Micro Influencers (5k+ followers)')),
                        DropdownMenuItem(value: '10k+ followers', child: Text('Mid Influencers (10k+ followers)')),
                        DropdownMenuItem(value: '50k+ followers', child: Text('Top Creators (50k+ followers)')),
                      ],
                      onChanged: (v) {
                        if (v != null) setModalState(() => requiredFollowers = v);
                      },
                    ),
                    const SizedBox(height: 12),

                    // Required Deliverables Text Area
                    TextField(
                      controller: deliverCtrl,
                      maxLines: 2,
                      style: TextStyle(color: textPrimary),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.video_library_rounded),
                        labelText: 'Required Deliverables',
                        hintText: 'e.g. 1 Instagram Reel (60s) + 2 Stories with Swipe Up link',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Commitment Deposit Calculation Box (Configurable by Admin)
                    Builder(
                      builder: (context) {
                        final moderation = ref.read(adminModerationProvider);
                        final depositPct = moderation.commitmentDepositPercentage;
                        final feePct = moderation.brandDealEscrowFeePercentage;
                        final budgetVal = double.tryParse(budgetCtrl.text) ?? 500;
                        final depositVal = budgetVal * (depositPct / 100);
                        final feeVal = budgetVal * (feePct / 100);
                        final totalInitial = depositVal + feeVal;

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF007AFF).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFF007AFF).withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Upfront Deposit (${depositPct.toStringAsFixed(0)}% Commitment)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary)),
                                  Text('\$${depositVal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF007AFF))),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Escrow Service Fee (${feePct.toStringAsFixed(1)}%)', style: TextStyle(fontSize: 12, color: textSecondary)),
                                  Text('\$${feeVal.toStringAsFixed(2)}', style: TextStyle(fontSize: 12, color: textSecondary)),
                                ],
                              ),
                              const Divider(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Total Upfront Escrow Deposit', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: textPrimary)),
                                  Text('\$${totalInitial.toStringAsFixed(2)} USD', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF34C759))),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 18),

                    // Launch CTA Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF9500),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          final budget = double.tryParse(budgetCtrl.text) ?? 500;
                          final title = titleCtrl.text.trim();
                          final brand = brandCtrl.text.trim();
                          final deliverables = deliverCtrl.text.trim();

                          setState(() {
                            _availableDeals.insert(
                              0,
                              _BrandDealItem(
                                title: title.isEmpty ? 'New Brand Campaign' : title,
                                brandName: brand.isEmpty ? 'My Brand' : brand,
                                budgetEscrow: budget,
                                deliverables: deliverables.isEmpty ? '1 Video Post + 2 Stories' : deliverables,
                                requiredFollowers: requiredFollowers,
                                category: selectedCategory,
                                status: 'Open',
                              ),
                            );
                          });

                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Brand deal "$title" posted! \$${budget.toStringAsFixed(0)} locked in Escrow.'),
                              backgroundColor: const Color(0xFF34C759),
                            ),
                          );
                        },
                        child: const Text(
                          'Deposit & Launch Brand Deal (Escrow Locked)',
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : const Color(0xFFF2F2F7);
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Creator Hub & Brand Deals',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BrandDealsHelpScreen()),
              );
            },
            icon: const Icon(Icons.help_outline_rounded, color: Color(0xFF007AFF)),
            tooltip: 'Brand Deals & Escrow Guide',
          ),
          IconButton(
            onPressed: _showPostBrandDealDialog,
            icon: Icon(
              Icons.add_chart_rounded,
              color: isDark ? Colors.white : Colors.black,
            ),
            tooltip: 'Post Brand Deal',
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          labelColor: const Color(0xFF007AFF),
          unselectedLabelColor: isDark ? const Color(0xFF8E8E93) : const Color(0xFF61758A),
          indicatorColor: const Color(0xFF007AFF),
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          tabs: const [Tab(text: 'Available Deals'), Tab(text: 'My Active Campaigns')],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          // Available Deals Tab
          ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _availableDeals.length,
            separatorBuilder: (_, _) => const SizedBox(height: 14),
            itemBuilder: (ctx, i) {
              final deal = _availableDeals[i];
              return Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF007AFF).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            deal.category,
                            style: const TextStyle(
                              color: Color(0xFF007AFF),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF34C759).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.shield_outlined, color: Color(0xFF34C759), size: 16),
                              const SizedBox(width: 4),
                              Text(
                                '\$${deal.budgetEscrow.toStringAsFixed(0)} ESCROW',
                                style: const TextStyle(
                                  color: Color(0xFF34C759),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      deal.title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'By ${deal.brandName} · ${deal.requiredFollowers}',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF7FAFC),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.assignment_turned_in_rounded, size: 18, color: Color(0xFF007AFF)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              deal.deliverables,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.grey[300] : Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF007AFF),
                              side: const BorderSide(color: Color(0xFF007AFF)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              BrandDealMilestonesDialog.show(
                                context,
                                dealId: 101,
                                dealTitle: deal.title,
                                budget: deal.budgetEscrow,
                              );
                            },
                            icon: const Icon(Icons.shield_outlined, size: 16),
                            label: const Text('Milestones 🛡️', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFFF9500),
                              side: const BorderSide(color: Color(0xFFFF9500)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              BrandDealCertificateDialog.show(
                                context,
                                dealTitle: deal.title,
                                brandName: deal.brandName,
                                creatorName: 'Verified Ambassador',
                                totalBudget: deal.budgetEscrow,
                                depositAmount: deal.budgetEscrow * 0.3,
                                depositPercentage: 30.0,
                                deliverables: deal.deliverables,
                              );
                            },
                            icon: const Icon(Icons.verified_rounded, size: 16),
                            label: const Text('Contract 📜', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF007AFF),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Pitch submitted to ${deal.brandName}!')),
                              );
                            },
                            child: const Text(
                              'Apply / Pitch for Deal',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),

          // Active Campaigns Tab
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.workspace_premium_rounded, size: 64, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                const SizedBox(height: 12),
                Text(
                  'No Active Campaigns',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Apply for brand deals to start earning locked escrow payouts.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandDealItem {
  final String title;
  final String brandName;
  final double budgetEscrow;
  final String deliverables;
  final String requiredFollowers;
  final String category;
  final String status;

  _BrandDealItem({
    required this.title,
    required this.brandName,
    required this.budgetEscrow,
    required this.deliverables,
    required this.requiredFollowers,
    required this.category,
    required this.status,
  });
}
