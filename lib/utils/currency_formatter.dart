import 'package:intl/intl.dart';

class CurrencyFormatter {
  static String format(num amount, {String symbol = '₦', int decimalDigits = 2}) {
    return NumberFormat.currency(locale: 'en_NG', symbol: symbol, decimalDigits: decimalDigits)
        .format(amount);
  }
}