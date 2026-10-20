import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../components/brand.dart';
import '../components/buy_coins_sheet.dart';
import '../components/escrow_deal_sheet.dart';
import '../components/refund_balances_card.dart';
import '../components/murih_pay_card.dart';
import '../components/send_money_sheet.dart';
import '../components/transaction_details_sheet.dart';
import '../components/ui_states.dart';
import '../components/wallet_action_grid.dart';
import '../components/wallet_balance_breakdown.dart';
import '../components/wallet_switcher.dart';
import '../components/wallet_transactions_list.dart';
import '../core/currency_formatter.dart';
import '../providers/auth_provider.dart';
import '../providers/gifts_provider.dart';
import '../providers/security_provider.dart';
import '../providers/wallet_provider.dart';

/// Complete MurihPay Financial Hub Screen for Flutter.
/// Implements a consumer banking aesthetic inspired by digital payment cards,
/// clear typography, multi-wallet tabs, 2x2 breakdown, and authoritative ledger actions.
class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  bool _hideBalance = false;
  bool _showLocalCurrency = false;
  WalletType _activeWalletType = WalletType.system;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(walletProvider.notifier).refresh();
      ref.read(giftsProvider.notifier).loadAll();
    });
  }

  Wallet? _getActiveWallet(List<Wallet> wallets) {
    for (final w in wallets) {
      if (w.type == _activeWalletType) return w;
    }
    return wallets.isNotEmpty ? wallets.first : null;
  }

  void _openDepositModal() {
    final amountController = TextEditingController(text: '25');
    String selectedCurrency = 'USD';
    const availableCurrencies = ['USD', 'NGN', 'KES', 'GHS', 'EUR', 'GBP'];
    final rates = {
      'USD': 1.0,
      'NGN': 1326.0,
      'KES': 129.5,
      'GHS': 11.4,
      'EUR': 0.86,
      'GBP': 0.74,
    };

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF161B26)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (modalCtx, setSheetState) {
            final raw = double.tryParse(amountController.text.trim()) ?? 25.0;
            final double usdAmount = selectedCurrency == 'USD'
                ? raw
                : (raw / (rates[selectedCurrency] ?? 1.0));
            final double localAmount = selectedCurrency == 'USD'
                ? (raw * (rates['NGN'] ?? 1326.0))
                : raw;
            final localCurrency = selectedCurrency == 'USD' ? 'NGN' : selectedCurrency;

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Deposit Funds',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF17202B),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: BrandColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Guaranteed Rate · 15m',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: BrandColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Stored in USD to safeguard against local currency volatility.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E2638) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE4E7EC),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedCurrency,
                            dropdownColor: isDark ? const Color(0xFF1E2638) : Colors.white,
                            items: availableCurrencies.map((c) {
                              return DropdownMenuItem<String>(
                                value: c,
                                child: Text(
                                  '$c (${CurrencyFormatter.getSymbol(c)})',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : const Color(0xFF17202B),
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setSheetState(() {
                                  selectedCurrency = val;
                                  amountController.text = val == 'USD' ? '25' : '35000';
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: amountController,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setSheetState(() {}),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF17202B),
                          ),
                          decoration: InputDecoration(
                            prefixText: '${CurrencyFormatter.getSymbol(selectedCurrency)} ',
                            labelText: 'Amount ($selectedCurrency)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE4E7EC),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Conversion preview
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E2638) : const Color(0xFFF0F5FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: BrandColors.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Credited to Wallet:',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475467),
                              ),
                            ),
                            Text(
                              '\$${usdAmount.toStringAsFixed(2)} USD',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF16A34A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Estimated Local Charge:',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475467),
                              ),
                            ),
                            Text(
                              '${CurrencyFormatter.getSymbol(localCurrency)}${localAmount.toStringAsFixed(2)} $localCurrency',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF17202B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BrandColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final nav = Navigator.of(modalCtx);
                        final usdCents = (usdAmount * 100).toInt();
                        await ref.read(walletProvider.notifier).deposit(amount: usdCents, currency: 'USD');
                        if (!mounted) return;
                        nav.pop();
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              'Deposit of \$${usdAmount.toStringAsFixed(2)} USD successfully credited!',
                            ),
                            backgroundColor: const Color(0xFF16A34A),
                          ),
                        );
                      },
                      child: Text(
                        'Deposit \$${usdAmount.toStringAsFixed(2)} USD',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showKycRequiredWithdrawalModal() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF161B26)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shield_outlined, size: 48, color: Color(0xFFD97706)),
              ),
              const SizedBox(height: 16),
              Text(
                'KYC Verification Required',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF17202B),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Before you can withdraw funds to your bank account, your identity must be verified in accordance with financial compliance standards.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: BrandColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  context.push('/kyc');
                },
                icon: const Icon(Icons.verified_user_rounded, size: 18),
                label: const Text(
                  'Complete KYC Verification',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openWithdrawModal() {
    final auth = ref.read(authProvider);
    final kycStatus = auth.user?.kycStatus ?? 'unsubmitted';

    if (kycStatus != 'approved' && kycStatus != 'verified') {
      _showKycRequiredWithdrawalModal();
      return;
    }

    final amountController = TextEditingController(text: '50');
    final pinController = TextEditingController();
    final security = ref.read(securityProvider);
    String destCurrency = 'NGN';
    const destCurrencies = ['NGN', 'KES', 'GHS', 'USD', 'EUR', 'GBP'];
    final rates = {
      'USD': 1.0,
      'NGN': 1326.0,
      'KES': 129.5,
      'GHS': 11.4,
      'EUR': 0.86,
      'GBP': 0.74,
    };

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF161B26)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (modalCtx, setSheetState) {
            final rawUsd = double.tryParse(amountController.text.trim()) ?? 50.0;
            final feeUsd = (rawUsd * 0.015) < 1.0 ? 1.0 : (rawUsd * 0.015);
            final netUsd = rawUsd > feeUsd ? (rawUsd - feeUsd) : 0.0;
            final rate = rates[destCurrency] ?? 1.0;
            final estimatedPayout = netUsd * rate;

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Withdraw to Bank Account',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF17202B),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Live FX Locked',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Disbursed from your USD balance directly into your verified bank account.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E2638) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE4E7EC),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: destCurrency,
                            dropdownColor: isDark ? const Color(0xFF1E2638) : Colors.white,
                            items: destCurrencies.map((c) {
                              return DropdownMenuItem<String>(
                                value: c,
                                child: Text(
                                  '$c (${CurrencyFormatter.getSymbol(c)})',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : const Color(0xFF17202B),
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setSheetState(() => destCurrency = val);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: amountController,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setSheetState(() {}),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF17202B),
                          ),
                          decoration: InputDecoration(
                            prefixText: r'$ ',
                            labelText: 'Amount (USD)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Conversion & Fee Breakdown
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E2638) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE4E7EC),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Requested Gross:',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085),
                              ),
                            ),
                            Text(
                              '\$${rawUsd.toStringAsFixed(2)} USD',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Platform Fee (1.5%):',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085),
                              ),
                            ),
                            Text(
                              '-\$${feeUsd.toStringAsFixed(2)} USD',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFFDC2626),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Exchange Rate:',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085),
                              ),
                            ),
                            Text(
                              '1 USD = ${CurrencyFormatter.getSymbol(destCurrency)}${rate.toStringAsFixed(2)} $destCurrency',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Estimated Payout:',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF17202B),
                              ),
                            ),
                            Text(
                              '${CurrencyFormatter.getSymbol(destCurrency)}${estimatedPayout.toStringAsFixed(2)} $destCurrency',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF16A34A),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),
                  if (security.isTransactionPinSet) ...[
                    TextField(
                      controller: pinController,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock_rounded, size: 20),
                        labelText: 'Enter 4-Digit Transaction PIN',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BrandColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final nav = Navigator.of(modalCtx);
                        final raw = (rawUsd * 100).toInt();
                        if (security.isTransactionPinSet) {
                          final okPin = await ref
                              .read(securityProvider.notifier)
                              .verifyTransactionPin(pinController.text.trim());
                          if (!okPin) {
                            if (!mounted) return;
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Invalid Transaction PIN.')),
                            );
                            return;
                          }
                        }
                        await ref.read(walletProvider.notifier).submitWithdrawal(
                              amountUsdCents: raw,
                              pin: pinController.text.trim().isNotEmpty
                                  ? pinController.text.trim()
                                  : '0000',
                              destinationCurrency: destCurrency,
                            );
                        if (!mounted) return;
                        nav.pop();
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              'Withdrawal of \$${rawUsd.toStringAsFixed(2)} USD (≈ ${CurrencyFormatter.getSymbol(destCurrency)}${estimatedPayout.toStringAsFixed(2)}) initiated!',
                            ),
                            backgroundColor: const Color(0xFF16A34A),
                          ),
                        );
                      },
                      child: Text(
                        'Confirm Withdrawal (\$${rawUsd.toStringAsFixed(2)})',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openInternalTransferModal() {
    final wallets = ref.read(walletProvider).wallets;
    final activeWallet = _getActiveWallet(wallets);
    final available = activeWallet != null ? (activeWallet.available / 100.0) : 0.0;
    final fromType = activeWallet?.type == WalletType.business ? 'business' : 'creator';

    final amountController = TextEditingController(
      text: available > 0 ? (available / 2).toStringAsFixed(0) : '10',
    );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF161B26)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Transfer to Personal Wallet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF17202B),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Instant internal transfer from $fromType earnings into your spendable personal wallet with zero fees.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF17202B),
                ),
                decoration: InputDecoration(
                  prefixText: r'$ ',
                  labelText: 'Amount (USD)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Available in $fromType wallet: \$${available.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BrandColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final nav = Navigator.of(ctx);
                    final raw = double.tryParse(amountController.text.trim()) ?? 0.0;
                    if (raw <= 0) return;
                    final ok = await ref.read(walletProvider.notifier).internalTransfer(
                          fromType: fromType,
                          amount: (raw * 100).toInt(),
                        );
                    if (!mounted) return;
                    nav.pop();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? 'Successfully transferred \$${raw.toStringAsFixed(2)} to Personal Wallet!'
                              : ref.read(walletProvider).error ?? 'Transfer failed.',
                        ),
                        backgroundColor: ok ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                      ),
                    );
                  },
                  child: const Text(
                    'Confirm Transfer',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openCreateEscrowModal() {
    final titleController = TextEditingController();
    final partyController = TextEditingController();
    final amountController = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF161B26)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: BrandColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shield_rounded, color: BrandColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Create Escrow Agreement',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF17202B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: 'Agreement Title / Milestone',
                  hintText: 'e.g., Sponsored Post Campaign',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: partyController,
                decoration: InputDecoration(
                  labelText: 'Counterparty Username',
                  hintText: 'e.g., @creator_handle',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  prefixText: r'$ ',
                  labelText: 'Escrow Amount (USD)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BrandColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    final title = titleController.text.trim();
                    final party = partyController.text.trim();
                    final amount = amountController.text.trim();
                    if (title.isNotEmpty && amount.isNotEmpty) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Escrow agreement "$title" initialized for \$$amount with ${party.isNotEmpty ? party : 'counterparty'}!',
                          ),
                          backgroundColor: const Color(0xFF16A34A),
                        ),
                      );
                    }
                  },
                  child: const Text(
                    'Lock Funds in Escrow',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openReceiveModal() {
    final user = ref.read(authProvider).user;
    final handle = user?.username != null ? '@${user!.username}' : '@murihpay_user';
    final walletId = 'MP-${user?.id ?? 1001}-8829';

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF161B26)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: BrandColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.qr_code_rounded, color: BrandColors.primary, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                'Receive Money',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF17202B),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Share your username or MurihPay Wallet ID to receive funds instantly.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E2638) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE4E7EC),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'MurihPay Handle:',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085),
                          ),
                        ),
                        Text(
                          handle,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF17202B),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Wallet ID:',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085),
                          ),
                        ),
                        Text(
                          walletId,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'monospace',
                            color: BrandColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Done'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BrandColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final walletState = ref.watch(walletProvider);
    final user = ref.watch(authProvider).user;

    final activeWallet = _getActiveWallet(walletState.wallets);
    final availableAmount = activeWallet != null ? (activeWallet.available / 100.0) : 0.0;
    final currency = activeWallet?.currency ?? 'USD';

    final textPrimary = isDark ? Colors.white : const Color(0xFF17202B);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085);
    final pageBg = isDark ? const Color(0xFF0F141C) : const Color(0xFFF3F5F8);

    final userName = (user?.name != null && user!.name.isNotEmpty)
        ? user.name
        : 'Vincent Adetuberu';
    final userTag = (user?.username != null && user!.username.isNotEmpty)
        ? '@${user.username}'
        : '@vincent';

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: pageBg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: Text(
          'Wallet',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            tooltip: _hideBalance ? 'Show Balance' : 'Hide Balance',
            icon: Icon(
              _hideBalance ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              color: textSecondary,
              size: 22,
            ),
            onPressed: () => setState(() => _hideBalance = !_hideBalance),
          ),
          IconButton(
            tooltip: 'Security Settings',
            icon: Icon(
              Icons.shield_outlined,
              color: textSecondary,
              size: 22,
            ),
            onPressed: () => context.push('/security'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: BrandColors.primary,
        onRefresh: () async {
          await Future.wait([
            ref.read(walletProvider.notifier).refresh(),
            ref.read(giftsProvider.notifier).loadAll(),
          ]);
        },
        child: walletState.loading && walletState.wallets.isEmpty
            ? const Center(child: LoadingStateWidget(message: 'Loading MurihPay ledger...'))
            : ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                children: [
                  // 1. Wallet Switcher (Segmented Tab Bar)
                  WalletSwitcher(
                    activeType: _activeWalletType,
                    onChanged: (newType) {
                      setState(() {
                        _activeWalletType = newType;
                      });
                    },
                    hasCreator: walletState.wallets.any((w) => w.type == WalletType.creator) || true,
                    hasBusiness: walletState.wallets.any((w) => w.type == WalletType.business) || true,
                  ),

                  const SizedBox(height: 18),

                  // 2. Premium Digital Payment Card with Available Balance on Card
                  MurihPayCard(
                    walletType: _activeWalletType,
                    userName: userName,
                    userTag: userTag,
                    availableBalance: availableAmount,
                    currency: currency,
                    localCurrency: activeWallet?.localCurrency ?? 'NGN',
                    localRate: (activeWallet?.localRate != null && activeWallet!.localRate > 0)
                        ? activeWallet.localRate
                        : 1326.0,
                    localFormatted: activeWallet?.localFormatted ?? '',
                    isBalanceHidden: _hideBalance,
                    showLocalCurrency: _showLocalCurrency,
                    onToggleCurrency: () {
                      setState(() {
                        _showLocalCurrency = !_showLocalCurrency;
                      });
                    },
                  ),

                  const SizedBox(height: 22),

                  // 4. Financial Actions Grid (Circular icons)
                  WalletActionGrid(
                    walletType: _activeWalletType,
                    onDeposit: _openDepositModal,
                    onWithdraw: _openWithdrawModal,
                    onSendMoney: () => SendMoneySheet.show(context),
                    onBuyCoins: () => BuyCoinsSheet.show(context),
                    onReceive: _openReceiveModal,
                    onTransfer: _openInternalTransferModal,
                    onLockEscrow: _openCreateEscrowModal,
                  ),

                  const SizedBox(height: 24),

                  if (activeWallet?.kycRequiredToWithdraw ?? false) ...[
                    _VerifyToWithdrawBanner(onVerify: () => context.push('/kyc')),
                    const SizedBox(height: 16),
                  ],

                  // 5. 2x2 Balance Metrics Breakdown
                  WalletBalanceBreakdown(
                    pendingFormatted: '\$${((activeWallet?.pending ?? 0) / 100.0).toStringAsFixed(2)}',
                    reservedFormatted: '\$${((activeWallet?.reserved ?? 0) / 100.0).toStringAsFixed(2)}',
                    escrowFormatted: '\$${((activeWallet?.escrow ?? 0) / 100.0).toStringAsFixed(2)}',
                    totalFormatted: '\$${((activeWallet?.total ?? 0) / 100.0).toStringAsFixed(2)}',
                    withdrawableFormatted: '\$${((activeWallet?.withdrawable ?? 0) / 100.0).toStringAsFixed(2)}',
                    heldFormatted: '\$${((activeWallet?.disputed ?? 0) / 100.0).toStringAsFixed(2)}',
                    isBalanceHidden: _hideBalance,
                  ),

                  const SizedBox(height: 16),

                  // Dispute refunds and escrows that still hold funds
                  const RefundBalancesCard(),
                  const SizedBox(height: 16),
                  const ActiveEscrowDeals(),

                  const SizedBox(height: 24),

                  // 6. Transaction History Feed
                  WalletTransactionsList(
                    transactions: walletState.transactions,
                    isBalanceHidden: _hideBalance,
                    onSelect: (txn) {
                      TransactionDetailsSheet.show(context, txn);
                    },
                  ),

                  const SizedBox(height: 40),
                ],
              ),
      ),
    );
  }
}

/// Shown when money is withdrawable but identity is not verified. The balance is kept.
class _VerifyToWithdrawBanner extends StatelessWidget {
  final VoidCallback onVerify;

  const _VerifyToWithdrawBanner({required this.onVerify});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x1AD97706),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x66D97706)),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Verify your identity to withdraw',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                SizedBox(height: 2),
                Text('Your earnings are safe. Withdrawals open once your identity is verified.',
                    style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(onPressed: onVerify, child: const Text('Verify')),
        ],
      ),
    );
  }
}

