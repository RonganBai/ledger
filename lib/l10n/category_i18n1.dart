import 'package:flutter/material.dart';

String categoryLabel(BuildContext context, String raw) {
  final key = raw.trim();
  if (key.isEmpty) return raw;

  final isZh = Localizations.localeOf(context).languageCode == 'zh';
  if (!isZh) return key;

  final k = key.toLowerCase();

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

  // 如果数据库里本来就存了中文名，直接返回原值
  return map[k] ?? key;
}