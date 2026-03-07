import 'package:flutter/material.dart';

String tr(BuildContext context, {required String en, required String zh}) {
  final code = Localizations.localeOf(context).languageCode;
  return code == 'zh' ? zh : en;
}

String translateCategory(BuildContext context, String raw) {
  final isZh = Localizations.localeOf(context).languageCode == 'zh';
  if (!isZh) return raw;

  final key = raw.trim().toLowerCase();
  const map = {
    'food': '餐饮',
    'transport': '交通',
    'salary': '工资',
    'shopping': '购物',
    'entertainment': '娱乐',
    'rent': '房租',
    'utilities': '水电',
    'travel': '旅行',
    'medical': '医疗',
    'gift': '礼物',
    'transfer': '转账',
    'other': '其他',
  };
  return map[key] ?? raw;
}
