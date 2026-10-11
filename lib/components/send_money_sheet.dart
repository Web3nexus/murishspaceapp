import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/design_tokens.dart';
import '../providers/security_provider.dart';
import '../providers/wallet_provider.dart';

class SendMoneySheet extends ConsumerStatefulWidget {
  const SendMoneySheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SendMoneySheet(),
    );
  }

  @override
  ConsumerState<SendMoneySheet> createState() => _SendMoneySheetState();
}

class _SendMoneySheetState extends ConsumerState<SendMoneySheet> {
  final TextEditingController _recipientCtrl = TextEditingController();
  final TextEditingController _amountCtrl = TextEditingController(text: '50.00');
  final TextEditingController _noteCtrl = TextEditingController();
  final TextEditingController _pinCtrl = TextEditingController();

  String _selectedAmount = '50';
  bool _loading = false;

  final _presets = ['10', '20', '50', '100'];

  final _recentContacts = [
    const _Contact('Alex', 'alex', 'A'),
    const _Contact('Sarah', 'sarah', 'S'),
    const _Contact('Daniel', 'daniel', 'D'),
    const _Contact('Amina', 'amina', 'M'),
  ];

  @override
  void dispose() {
    _recipientCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    final recipient = _recipientCtrl.text.trim();
    final rawAmt = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
    final minor = (rawAmt * 100).toInt();

    if (recipient.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or enter a recipient username.')),
      );
      return;
    }

    if (minor <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid transfer amount.')),
      );
      return;
    }

    final security = ref.read(securityProvider);
    if (security.isTransactionPinSet) {
      final pin = _pinCtrl.text.trim();
      if (pin.length != 4) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter your 4-digit transaction PIN.')),
        );
        return;
      }

      final ok = await ref.read(securityProvider.notifier).verifyTransactionPin(pin);
      if (!ok) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid Transaction PIN.')),
        );
        return;
      }
    }

    setState(() => _loading = true);

    try {
      final dio = ApiClient.instance.dio;
      await dio.post('/wallet/transfers/send', data: {
        'recipient_username': recipient.replaceFirst('@', ''),
        'amount': minor,
        'currency': 'USD',
        'note': _noteCtrl.text.trim().isNotEmpty ? _noteCtrl.text.trim() : null,
        if (security.isTransactionPinSet) 'pin': _pinCtrl.text.trim(),
      });

      await ref.read(walletProvider.notifier).refresh();

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully sent \$${rawAmt.toStringAsFixed(2)} to @$recipient!'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transfer failed. Please check recipient details and available balance.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF14171E) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF111827);
    final textSecondary = isDark ? Colors.grey[400] : const Color(0xFF6B7280);
    final borderColor = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E7EB);
    final media = MediaQuery.of(context);
    final security = ref.watch(securityProvider);

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: media.viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Row
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.arrow_back_rounded, color: textPrimary, size: 22),
                ),
                const SizedBox(width: 12),
                Text(
                  'Send Money',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: textPrimary,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Recipient Search
            Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor, width: 0.8),
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, size: 20, color: textSecondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _recipientCtrl,
                      style: TextStyle(fontSize: 14, color: textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Search people, username or phone...',
                        hintStyle: TextStyle(fontSize: 14, color: textSecondary),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Recent Contacts Avatars Row
            Row(
              children: [
                ..._recentContacts.map((c) {
                  final isSel = _recipientCtrl.text == c.username;
                  return Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: GestureDetector(
                      onTap: () => setState(() => _recipientCtrl.text = c.username),
                      child: Column(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSel ? DesignTokens.primary : (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E7EB)),
                              border: Border.all(
                                color: isSel ? DesignTokens.primary : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                c.avatar,
                                style: TextStyle(
                                  color: isSel ? Colors.white : textPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            c.name,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                // More button
                Column(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF3F4F6),
                        border: Border.all(color: borderColor, width: 0.8),
                      ),
                      child: Icon(Icons.more_horiz_rounded, color: textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text('More', style: TextStyle(fontSize: 11, color: textSecondary)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Amount Input Card
            Text(
              'Amount',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: textSecondary,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        r'$ ',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: textPrimary,
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _amountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: textPrimary,
                            letterSpacing: -0.5,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (val) {
                            setState(() => _selectedAmount = val);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor, width: 0.8),
                  ),
                  child: Row(
                    children: [
                      const Text('🇺🇸', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(
                        'USD',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: textSecondary),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Quick Amount Chips
            Row(
              children: _presets.map((p) {
                final isSel = _selectedAmount == p || _amountCtrl.text == p || _amountCtrl.text == '$p.00';
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedAmount = p;
                          _amountCtrl.text = '$p.00';
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isSel ? DesignTokens.primary.withValues(alpha: 0.12) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSel ? DesignTokens.primary : borderColor,
                            width: isSel ? 1.5 : 0.8,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '\$$p',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: isSel ? DesignTokens.primary : textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Note Input
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Add a note (optional)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: textSecondary,
                  ),
                ),
                Text(
                  '${_noteCtrl.text.length}/100',
                  style: TextStyle(fontSize: 10.5, color: textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor, width: 0.8),
              ),
              child: TextField(
                controller: _noteCtrl,
                maxLength: 100,
                maxLines: 2,
                style: TextStyle(fontSize: 13, color: textPrimary),
                decoration: InputDecoration(
                  hintText: 'Thanks for your help! 🙏',
                  hintStyle: TextStyle(fontSize: 13, color: textSecondary),
                  border: InputBorder.none,
                  counterText: '',
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 16),

            // Security PIN if configured
            if (security.isTransactionPinSet) ...[
              Text(
                'Transaction Authorization PIN',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor, width: 0.8),
                ),
                child: Center(
                  child: TextField(
                    controller: _pinCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    obscureText: true,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 8,
                      color: textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: '••••',
                      hintStyle: TextStyle(letterSpacing: 8, color: textSecondary),
                      border: InputBorder.none,
                      counterText: '',
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Continue Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: DesignTokens.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _loading ? null : _handleSend,
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                      )
                    : const Text(
                        'Continue',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Contact {
  final String name;
  final String username;
  final String avatar;

  const _Contact(this.name, this.username, this.avatar);
}

