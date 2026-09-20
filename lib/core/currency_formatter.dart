class CurrencyFormatter {
  static const Map<String, String> _symbols = {
    'USD': r'$',
    'NGN': '₦',
    'GBP': '£',
    'EUR': '€',
    'GHS': 'GH₵',
    'KES': 'KSh',
    'ZAR': 'R',
    'CAD': r'CA$',
    'AUD': r'A$',
  };

  /// Gets symbol for a given currency code.
  static String getSymbol(String currency) => _symbols[currency.toUpperCase()] ?? '$currency ';

  /// Formats an amount in minor units (e.g. 1000 cents = $10.00) with currency symbol.
  static String format(int minorUnits, String currency) {
    final sym = getSymbol(currency);
    final major = minorUnits / 100.0;
    return '$sym${_formatNumber(major)}';
  }

  /// Formats a string that already represents a major unit (e.g. '10.00').
  static String formatString(String majorUnitsStr, String currency) {
    final sym = getSymbol(currency);
    return '$sym$majorUnitsStr';
  }

  /// Formats a USD minor unit amount with an optional localized currency subtitle.
  /// Example: "$10.00 (≈ ₦13,260.00)"
  static String formatDual(int usdMinorUnits, {double? localRate, String localCurrency = 'NGN'}) {
    final usdFormatted = format(usdMinorUnits, 'USD');
    if (localRate == null || localRate <= 0 || localCurrency.toUpperCase() == 'USD') {
      return usdFormatted;
    }
    final localMajor = (usdMinorUnits / 100.0) * localRate;
    final localFormatted = '${getSymbol(localCurrency)}${_formatNumber(localMajor)}';
    return '$usdFormatted (≈ $localFormatted)';
  }

  /// Standard Peg: 10 Coins = $1.00 USD (driven by server `coin_conversion_rate`).
  /// Admins can tune the rate; the app overrides this from the catalogue response.
  static double coinRate = 10.0;

  /// Updates the coins-per-1-USD rate from the server.
  static void setCoinRate(double rate) {
    if (rate > 0) coinRate = rate;
  }

  /// Formats system coin balance with standard MSH token notation.
  static String formatCoins(int coins) {
    return '$coins MSH';
  }

  /// Formats coins with USD equivalent value.
  /// Example: "500 MSH (≈ $50.00)" at the default 10 coins per USD.
  static String formatCoinsWithUsd(int coins) {
    final usdMajor = coins / coinRate;
    return '$coins MSH (≈ \$${_formatNumber(usdMajor)})';
  }

  static String _formatNumber(double val) {
    final parts = val.toStringAsFixed(2).split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '$intPart.${parts[1]}';
  }
}
