import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/content_moderation_service.dart';

/// Transaction record for Admin Financial Monitoring.
class AdminTransactionRecord {
  final String id;
  final String user;
  final String type; // 'Wallet Deposit', 'Escrow Lock', 'Gift Transfer', 'Wallet Withdrawal', 'Coin Purchase'
  final String amount;
  final String currency;
  final DateTime timestamp;
  final String status; // 'completed', 'escrow_locked', 'flagged_suspicious', 'disputed'
  final bool isHighValue;

  AdminTransactionRecord({
    required this.id,
    required this.user,
    required this.type,
    required this.amount,
    required this.currency,
    required this.timestamp,
    required this.status,
    this.isHighValue = false,
  });

  AdminTransactionRecord copyWith({String? status}) {
    return AdminTransactionRecord(
      id: id,
      user: user,
      type: type,
      amount: amount,
      currency: currency,
      timestamp: timestamp,
      status: status ?? this.status,
      isHighValue: isHighValue,
    );
  }
}

class AdminModerationState {
  final List<AdminTransactionRecord> transactions;
  final List<ContentViolation> violations;
  final List<int> disabledUserIds;
  final List<int> frozenWalletUserIds;
  final List<String> bannedWords;
  final double commitmentDepositPercentage;
  final double brandDealEscrowFeePercentage;
  final bool isLoading;

  AdminModerationState({
    this.transactions = const [],
    this.violations = const [],
    this.disabledUserIds = const [],
    this.frozenWalletUserIds = const [],
    this.bannedWords = const [],
    this.commitmentDepositPercentage = 30.0,
    this.brandDealEscrowFeePercentage = 5.0,
    this.isLoading = false,
  });

  AdminModerationState copyWith({
    List<AdminTransactionRecord>? transactions,
    List<ContentViolation>? violations,
    List<int>? disabledUserIds,
    List<int>? frozenWalletUserIds,
    List<String>? bannedWords,
    double? commitmentDepositPercentage,
    double? brandDealEscrowFeePercentage,
    bool? isLoading,
  }) {
    return AdminModerationState(
      transactions: transactions ?? this.transactions,
      violations: violations ?? this.violations,
      disabledUserIds: disabledUserIds ?? this.disabledUserIds,
      frozenWalletUserIds: frozenWalletUserIds ?? this.frozenWalletUserIds,
      bannedWords: bannedWords ?? this.bannedWords,
      commitmentDepositPercentage: commitmentDepositPercentage ?? this.commitmentDepositPercentage,
      brandDealEscrowFeePercentage: brandDealEscrowFeePercentage ?? this.brandDealEscrowFeePercentage,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AdminModerationNotifier extends Notifier<AdminModerationState> {
  @override
  AdminModerationState build() {
    _initSampleData();
    return AdminModerationState(
      bannedWords: ContentModerationService.instance.bannedWords,
    );
  }

  void _initSampleData() {
    final sampleTx = [
      AdminTransactionRecord(
        id: 'tx_9801',
        user: 'Samuel Okeke (@samuel_o)',
        type: 'Wallet Deposit',
        amount: '₦50,000.00',
        currency: 'NGN',
        timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
        status: 'completed',
      ),
      AdminTransactionRecord(
        id: 'tx_9802',
        user: 'Unknown Vendor (@quick_cash)',
        type: 'Escrow Lock',
        amount: '₦450,000.00',
        currency: 'NGN',
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
        status: 'flagged_suspicious',
        isHighValue: true,
      ),
      AdminTransactionRecord(
        id: 'tx_9803',
        user: 'Kemi Adebayo (@kemi_brand)',
        type: 'Gift Transfer (1,000 MSH)',
        amount: '1,000 MSH',
        currency: 'MSH',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        status: 'completed',
      ),
      AdminTransactionRecord(
        id: 'tx_9804',
        user: 'Chioma Eze (@chioma_e)',
        type: 'Wallet Withdrawal',
        amount: '₦120,000.00',
        currency: 'NGN',
        timestamp: DateTime.now().subtract(const Duration(hours: 4)),
        status: 'disputed',
        isHighValue: true,
      ),
    ];

    final sampleViolations = [
      ContentViolation(
        id: 'viol_101',
        userId: 401,
        userName: 'Quick Money Hub',
        userHandle: '@quick_cash',
        userAvatarHex: '0xFFFF3B30',
        contentType: 'post',
        originalContent: 'Contact me now on WhatsApp for fake bank alert and send cash outside escrow guaranteed double payout!',
        matchedBannedWords: ['fake bank', 'send cash outside escrow', 'scam'],
        severity: ViolationSeverity.critical,
        riskScore: 95,
        timestamp: DateTime.now().subtract(const Duration(minutes: 22)),
      ),
      ContentViolation(
        id: 'viol_102',
        userId: 402,
        userName: 'Crypto Master',
        userHandle: '@crypto_fast',
        userAvatarHex: '0xFFFF9500',
        contentType: 'chat',
        originalContent: 'Invest 100k for 500k in 2 hours ponzi scheme hack available.',
        matchedBannedWords: ['ponzi', 'hack'],
        severity: ViolationSeverity.high,
        riskScore: 78,
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      ),
    ];

    state = AdminModerationState(
      transactions: sampleTx,
      violations: sampleViolations,
      bannedWords: ContentModerationService.instance.bannedWords,
    );
  }

  void disableAccount(int userId) {
    final updatedDisabled = List<int>.from(state.disabledUserIds)..add(userId);
    final updatedViolations = state.violations.map((v) {
      if (v.userId == userId) {
        return v.copyWith(status: 'account_disabled');
      }
      return v;
    }).toList();

    state = state.copyWith(
      disabledUserIds: updatedDisabled,
      violations: updatedViolations,
    );
  }

  void freezeWallet(int userId) {
    final updatedFrozen = List<int>.from(state.frozenWalletUserIds)..add(userId);
    final updatedViolations = state.violations.map((v) {
      if (v.userId == userId) {
        return v.copyWith(status: 'wallet_frozen');
      }
      return v;
    }).toList();

    state = state.copyWith(
      frozenWalletUserIds: updatedFrozen,
      violations: updatedViolations,
    );
  }

  void dismissFlag(String violationId) {
    final updatedViolations = state.violations.map((v) {
      if (v.id == violationId) {
        return v.copyWith(status: 'dismissed');
      }
      return v;
    }).toList();

    state = state.copyWith(violations: updatedViolations);
  }

  void addBannedWord(String word) {
    ContentModerationService.instance.addBannedWord(word);
    state = state.copyWith(bannedWords: ContentModerationService.instance.bannedWords);
  }

  void removeBannedWord(String word) {
    ContentModerationService.instance.removeBannedWord(word);
    state = state.copyWith(bannedWords: ContentModerationService.instance.bannedWords);
  }

  void updateBrandDealSettings({double? depositPct, double? feePct}) {
    state = state.copyWith(
      commitmentDepositPercentage: depositPct ?? state.commitmentDepositPercentage,
      brandDealEscrowFeePercentage: feePct ?? state.brandDealEscrowFeePercentage,
    );
  }
}

final adminModerationProvider = NotifierProvider<AdminModerationNotifier, AdminModerationState>(() {
  return AdminModerationNotifier();
});
