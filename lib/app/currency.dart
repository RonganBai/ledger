String currencySymbol(String code) {
  switch (code.toUpperCase()) {
    case 'USD':
      return r'$';
    case 'CNY':
      return '\u00A5';
    case 'JPY':
      return '\u00A5';
    case 'EUR':
      return '\u20AC';
    case 'GBP':
      return '\u00A3';
    case 'KRW':
      return '\u20A9';
    case 'HKD':
      return r'HK$';
    default:
      return code.toUpperCase();
  }
}

String formatMoney(double amount, {required String code}) {
  final s = currencySymbol(code);
  return '$s${amount.toStringAsFixed(2)}';
}
