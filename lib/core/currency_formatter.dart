import 'package:intl/intl.dart';

class CurrencyFormatter {
  /// Formats an amount in minor units (e.g. 1000 = $10.00) into a string with the currency symbol.
  static String format(int minorUnits, String currency) {
    final syms = const {'NGN': '₦', 'USD': r'$', 'GBP': '£', 'EUR': '€'};
    final sym = syms[currency] ?? '$currency ';
    return '$sym${(minorUnits / 100).toStringAsFixed(2)}';
  }

  /// Formats a string that already represents a major unit (e.g. '10.00').
  static String formatString(String majorUnitsStr, String currency) {
    final syms = const {'NGN': '₦', 'USD': r'$', 'GBP': '£', 'EUR': '€'};
    final sym = syms[currency] ?? '$currency ';
    return '$sym$majorUnitsStr';
  }
}
