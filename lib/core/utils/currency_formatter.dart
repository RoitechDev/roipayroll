import 'package:intl/intl.dart';

class CurrencyFormatter {
  static const Map<String, String> _symbols = {
    'NGN': 'NGN ',
    'USD': r'$',
    'EUR': 'EUR ',
    'GBP': 'GBP ',
  };

  static const Map<String, String> _locales = {
    'NGN': 'en_NG',
    'USD': 'en_US',
    'EUR': 'en_IE',
    'GBP': 'en_GB',
  };

  static String normalizeCurrencyCode(String? code) {
    final normalized = (code ?? 'NGN').trim().toUpperCase();
    if (_symbols.containsKey(normalized)) return normalized;
    return 'NGN';
  }

  static String currencySymbol(String? code) {
    return _symbols[normalizeCurrencyCode(code)] ?? 'NGN ';
  }

  static String formatCurrency(
    double amount, {
    String currencyCode = 'NGN',
    int decimalDigits = 2,
  }) {
    final code = normalizeCurrencyCode(currencyCode);
    final formatter = NumberFormat.currency(
      symbol: _symbols[code],
      decimalDigits: decimalDigits,
      locale: _locales[code],
    );
    return formatter.format(amount);
  }

  static String formatNaira(double amount) {
    return formatCurrency(amount, currencyCode: 'NGN');
  }

  static String formatNairaNoDecimals(double amount) {
    return formatCurrency(amount, currencyCode: 'NGN', decimalDigits: 0);
  }

  static String formatAmount(double amount) {
    final formatter = NumberFormat('#,##0.00', 'en_NG');
    return formatter.format(amount);
  }

  static String formatAmountNoDecimals(double amount) {
    final formatter = NumberFormat('#,##0', 'en_NG');
    return formatter.format(amount);
  }

  static double? parseNaira(String value) {
    try {
      String cleanValue = value
          .replaceAll('NGN', '')
          .replaceAll(r'$', '')
          .replaceAll('EUR', '')
          .replaceAll('GBP', '')
          .replaceAll(',', '')
          .trim();
      return double.parse(cleanValue);
    } catch (e) {
      return null;
    }
  }

  static String formatCompact(double amount) {
    if (amount >= 1000000) {
      final millions = amount / 1000000;
      return 'NGN ${millions.toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      final thousands = amount / 1000;
      return 'NGN ${thousands.toStringAsFixed(0)}K';
    } else {
      return formatNaira(amount);
    }
  }

  static String formatPercentage(double percentage) {
    return '${percentage.toStringAsFixed(2)}%';
  }

  static String formatAsInput(String value) {
    if (value.isEmpty) return value;

    final digitsOnly = value.replaceAll(RegExp(r'[^\d.]'), '');
    final parts = digitsOnly.split('.');
    final integerPart = parts[0];
    var formattedInteger = '';

    var count = 0;
    for (int i = integerPart.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) {
        formattedInteger = ',$formattedInteger';
      }
      formattedInteger = integerPart[i] + formattedInteger;
      count++;
    }

    if (parts.length > 1) {
      var decimalPart = parts[1];
      if (decimalPart.length > 2) {
        decimalPart = decimalPart.substring(0, 2);
      }
      return '$formattedInteger.$decimalPart';
    }

    return formattedInteger;
  }

  static double calculatePercentage(double amount, double percentage) {
    return (amount * percentage) / 100;
  }

  static String addAndFormat(double amount1, double amount2) {
    return formatNaira(amount1 + amount2);
  }

  static String subtractAndFormat(double amount1, double amount2) {
    return formatNaira(amount1 - amount2);
  }

  static String formatWithSign(double amount) {
    final sign = amount >= 0 ? '+' : '';
    return '$sign${formatNaira(amount)}';
  }

  static String getAmountColor(double amount) {
    return amount >= 0 ? 'green' : 'red';
  }

  static String format(
    num amount, {
    String symbol = '₦',
    int decimalDigits = 2,
  }) {
    return NumberFormat.currency(
      locale: 'en_NG',
      symbol: symbol,
      decimalDigits: decimalDigits,
    ).format(amount);
  }
}
