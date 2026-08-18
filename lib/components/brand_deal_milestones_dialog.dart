import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';

/// Interactive Upwork-Style Milestone Escrow & Dispute Dialog for Brand Deals.
class BrandDealMilestonesDialog extends ConsumerStatefulWidget {
  final int dealId;
  final String dealTitle;
  final double budget;

  const BrandDealMilestonesDialog({
    super.key,
    required this.dealId,
    required this.dealTitle,
    required this.budget,
  });

  static void show(
    BuildContext context, {
    required int dealId,
    required String dealTitle,
    required double budget,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1C1C1E)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => BrandDealMilestonesDialog(
        dealId: dealId,
        dealTitle: dealTitle,
        budget: budget,
      ),
    );
  }

  @override
  ConsumerState<BrandDealMilestonesDialog> createState() => _BrandDealMilestonesDialogState();
}

class _BrandDealMilestonesDialogState extends ConsumerState<BrandDealMilestonesDialog> {
  final List<Map<String, dynamic>> _milestones = [
    {
      'id': 101,
      'title': 'Milestone 1: Concept Script & Storyboard',
      'description': 'Deliver draft video script and visual storyboard for review',
      'amount': 300.0,
      'status': 'approved_and_released',
      'proof_notes': 'Storyboard PDF submitted via chat link.',
    },
    {
      'id': 102,
      'title': 'Milestone 2: Final Video Editing & Publication',
      'description': 'Produce 4K video reel and publish to Instagram & TikTok channels',
      'amount': 700.0,
      'status': 'submitted_for_review',
      'proof_notes': 'Reel published: https://instagram.com/p/C982xyz',
    },
  ];

  bool _loading = false;

  void _showAddMilestoneSheet() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController(text: '200');

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2C2C2E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add Milestone (Escrow Protected)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Milestone Title', hintText: 'e.g. Draft Video Review')),
            const SizedBox(height: 10),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Deliverable Scope')),
            const SizedBox(height: 10),
            TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (\$ USD)', prefixText: '\$ ')),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF007AFF), foregroundColor: Colors.white),
                onPressed: () {
                  final title = titleCtrl.text.trim();
                  final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
                  if (title.isEmpty || amount <= 0) return;
                  setState(() {
                    _milestones.add({
                      'id': randId(),
                      'title': title,
                      'description': descCtrl.text.trim(),
                      'amount': amount,
                      'status': 'funded_in_escrow',
                    });
                  });
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Milestone created & funded into escrow!')));
                },
                child: const Text('Fund & Add Milestone', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int randId() => DateTime.now().millisecondsSinceEpoch % 10000;

  void _showSubmitProofSheet(Map<String, dynamic> milestone) {
    final proofCtrl = TextEditingController(text: milestone['proof_notes'] as String? ?? '');

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2C2C2E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Submit Work for ${milestone['title']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: proofCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Work Description & URL Proofs', hintText: 'Include Instagram reel link, drive link, or notes…'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF34C759), foregroundColor: Colors.white),
                onPressed: () {
                  setState(() {
                    milestone['status'] = 'submitted_for_review';
                    milestone['proof_notes'] = proofCtrl.text.trim();
                  });
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Work submitted for brand review!')));
                },
                child: const Text('Submit Deliverable', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDisputeSheet(Map<String, dynamic> milestone) {
    final reasonCtrl = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2C2C2E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Raise Dispute on Milestone ⚠️', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFFF3B30))),
            const SizedBox(height: 8),
            const Text('Admin & Staff moderation team will review chat logs, contract terms, and submitted proof.', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Reason for Dispute', hintText: 'Explain what went wrong or why deliverable is rejected…'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF3B30), foregroundColor: Colors.white),
                onPressed: () {
                  final reason = reasonCtrl.text.trim();
                  if (reason.isEmpty) return;
                  setState(() {
                    milestone['status'] = 'disputed';
                    milestone['dispute_reason'] = reason;
                  });
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dispute opened. Admin & Staff moderation notified!')));
                },
                child: const Text('Open Official Dispute', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

    final totalEscrow = _milestones.fold<double>(0, (sum, m) => sum + (m['amount'] as double));

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: isDark ? Colors.grey[700] : Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF007AFF).withValues(alpha: 0.15),
                  child: const Icon(Icons.shield_outlined, color: Color(0xFF007AFF)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.dealTitle, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: textPrimary)),
                      Text('Upwork-Style Escrow Milestones', style: TextStyle(fontSize: 12, color: textSecondary)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF007AFF)),
                  tooltip: 'Add Milestone',
                  onPressed: _showAddMilestoneSheet,
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Escrow Summary Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF007AFF).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF007AFF).withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _summaryCol('Total Budget', '\$${widget.budget.toStringAsFixed(0)}', textPrimary),
                  _summaryCol('In Escrow', '\$${totalEscrow.toStringAsFixed(0)}', const Color(0xFF007AFF)),
                  _summaryCol('Milestones', '${_milestones.length}', textPrimary),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Milestones List
            Expanded(
              child: ListView.separated(
                itemCount: _milestones.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (ctx, idx) {
                  final m = _milestones[idx];
                  final status = m['status'] as String;
                  final amount = m['amount'] as double;

                  Color statusColor = const Color(0xFF007AFF);
                  String statusLabel = 'Funded in Escrow';

                  if (status == 'submitted_for_review') {
                    statusColor = const Color(0xFFFF9500);
                    statusLabel = 'Submitted for Review';
                  } else if (status == 'approved_and_released') {
                    statusColor = const Color(0xFF34C759);
                    statusLabel = 'Approved & Released';
                  } else if (status == 'disputed') {
                    statusColor = const Color(0xFFFF3B30);
                    statusLabel = 'Under Admin Dispute';
                  }

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text(m['title'] as String, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textPrimary))),
                            Text('\$${amount.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: textPrimary)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(m['description'] as String? ?? '', style: TextStyle(fontSize: 12, color: textSecondary)),
                        const SizedBox(height: 8),

                        // Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                          child: Text(statusLabel, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                        const SizedBox(height: 12),

                        // Actions Row
                        Row(
                          children: [
                            if (status == 'funded_in_escrow')
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF007AFF), foregroundColor: Colors.white),
                                  onPressed: () => _showSubmitProofSheet(m),
                                  icon: const Icon(Icons.upload_file_rounded, size: 16),
                                  label: const Text('Submit Work', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            if (status == 'submitted_for_review') ...[
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF34C759), foregroundColor: Colors.white),
                                  onPressed: () {
                                    setState(() => m['status'] = 'approved_and_released');
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment approved & released to creator!')));
                                  },
                                  icon: const Icon(Icons.check_circle_rounded, size: 16),
                                  label: const Text('Approve & Release', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            if (status != 'approved_and_released' && status != 'disputed')
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFFF3B30), side: const BorderSide(color: Color(0xFFFF3B30))),
                                onPressed: () => _showDisputeSheet(m),
                                icon: const Icon(Icons.warning_amber_rounded, size: 16),
                                label: const Text('Dispute', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
        ),
      ),
    );
  }

  Widget _summaryCol(String label, String val, Color color) {
    return Column(
      children: [
        Text(val, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
