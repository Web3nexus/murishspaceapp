/// Violation severity risk classification.
enum ViolationSeverity { low, medium, high, critical }

/// Model representing an auto-flagged content or account violation.
class ContentViolation {
  final String id;
  final int userId;
  final String userName;
  final String userHandle;
  final String userAvatarHex;
  final String contentType; // 'post', 'chat', 'product_title', 'bio', 'escrow_note'
  final String originalContent;
  final List<String> matchedBannedWords;
  final ViolationSeverity severity;
  final int riskScore; // 0 - 100
  final DateTime timestamp;
  final String status; // 'pending_review', 'account_disabled', 'dismissed', 'wallet_frozen'

  ContentViolation({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userHandle,
    required this.userAvatarHex,
    required this.contentType,
    required this.originalContent,
    required this.matchedBannedWords,
    required this.severity,
    required this.riskScore,
    required this.timestamp,
    this.status = 'pending_review',
  });

  ContentViolation copyWith({String? status}) {
    return ContentViolation(
      id: id,
      userId: userId,
      userName: userName,
      userHandle: userHandle,
      userAvatarHex: userAvatarHex,
      contentType: contentType,
      originalContent: originalContent,
      matchedBannedWords: matchedBannedWords,
      severity: severity,
      riskScore: riskScore,
      timestamp: timestamp,
      status: status ?? this.status,
    );
  }
}

/// Automated Content Moderation & Policy Enforcement Service.
class ContentModerationService {
  ContentModerationService._();
  static final ContentModerationService instance = ContentModerationService._();

  final List<String> _bannedWords = [
    'scam',
    'fraud',
    'ponzi',
    'fake bank',
    'hack',
    'phishing',
    'stolen card',
    'counterfeit',
    'hate',
    'bribe',
    'illegal',
    'exploit',
    'send cash outside escrow',
  ];

  List<String> get bannedWords => List.unmodifiable(_bannedWords);

  void addBannedWord(String word) {
    final cleaned = word.trim().toLowerCase();
    if (cleaned.isNotEmpty && !_bannedWords.contains(cleaned)) {
      _bannedWords.add(cleaned);
    }
  }

  void removeBannedWord(String word) {
    _bannedWords.remove(word.trim().toLowerCase());
  }

  /// Scans input text against banned words and returns matched violations.
  ContentViolation? scanText({
    required int userId,
    required String userName,
    required String userHandle,
    required String contentType,
    required String text,
  }) {
    final lower = text.toLowerCase();
    final matched = <String>[];

    for (final word in _bannedWords) {
      if (lower.contains(word)) {
        matched.add(word);
      }
    }

    if (matched.isEmpty) return null;

    // Calculate risk score based on matches
    int score = matched.length * 35;
    if (lower.contains('send cash outside escrow') || lower.contains('stolen card')) {
      score += 40;
    }
    score = score.clamp(0, 100);

    ViolationSeverity severity;
    if (score >= 80) {
      severity = ViolationSeverity.critical;
    } else if (score >= 50) {
      severity = ViolationSeverity.high;
    } else if (score >= 25) {
      severity = ViolationSeverity.medium;
    } else {
      severity = ViolationSeverity.low;
    }

    return ContentViolation(
      id: 'viol_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      userName: userName,
      userHandle: userHandle,
      userAvatarHex: '0xFFFF3B30',
      contentType: contentType,
      originalContent: text,
      matchedBannedWords: matched,
      severity: severity,
      riskScore: score,
      timestamp: DateTime.now(),
    );
  }
}
