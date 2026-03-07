import 'package:flutter/material.dart';

/// Convert a stable category key (e.g. 'food') to a localized label.
/// Database should store keys, NOT display strings.
String categoryLabel(BuildContext context, String rawKey) {
  final key = rawKey.trim();
  if (key.isEmpty) return rawKey;

  final lang = Localizations.localeOf(context).languageCode;

  final k = key.toLowerCase();

  const zh = <String, String>{
    'food': '餐饮',
    'transport': '交通',
    'shopping': '购物',
    'bills': '账单',
    'entertainment': '娱乐',
    'health': '医疗',
    'salary': '工资',
    'refund': '退款',
    'rent': '房租',
    'utilities': '水电',
    'travel': '旅行',
    'medical': '医疗',
    'gift': '礼物',
    'transfer': '转账',
    'other': '其他',
  };

  const en = <String, String>{
    'food': 'Food',
    'transport': 'Transport',
    'shopping': 'Shopping',
    'bills': 'Bills',
    'entertainment': 'Entertainment',
    'health': 'Health',
    'salary': 'Salary',
    'refund': 'Refund',
    'rent': 'Rent',
    'utilities': 'Utilities',
    'travel': 'Travel',
    'medical': 'Medical',
    'gift': 'Gift',
    'transfer': 'Transfer',
    'other': 'Other',
  };

  if (lang == 'zh') return zh[k] ?? key;
  return en[k] ?? _titleizeKey(k);
}

String _titleizeKey(String key) {
  // fallback: 'car_maintenance' -> 'Car Maintenance'
  final parts = key.split(RegExp(r'[_\-\s]+')).where((p) => p.isNotEmpty);
  return parts.map((p) => p[0].toUpperCase() + p.substring(1)).join(' ');
}
