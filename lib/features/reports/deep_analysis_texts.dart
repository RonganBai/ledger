import 'package:flutter/widgets.dart';

import '../../l10n/tr.dart';

const Map<String, String> _kDeepZh = <String, String>{
  'All categories': '\u5168\u90e8\u5206\u7c7b',
  'Analysis': '\u5206\u6790',
  'Category Share Change (vs last month)':
      '\u6d88\u8d39\u5206\u7c7b\u5360\u6bd4\u53d8\u5316\uff08\u8f83\u4e0a\u6708\uff09',
  'Close': '\u5173\u95ed',
  'Daily Expense': '\u5355\u65e5\u652f\u51fa',
  'Expense': '\u652f\u51fa',
  'Income': '\u6536\u5165',
  'MoM Expense (M-1 vs M-2)':
      '\u652f\u51fa\u73af\u6bd4\uff08\u4e0a\u6708 vs \u4e0a\u4e0a\u6708\uff09',
  'N/A': '\u65e0\u4e0a\u6708\u6570\u636e',
  'Net': '\u51c0\u989d',
  'Net / Income': '\u51c0\u989d/\u6536\u5165',
  'Peak Curve Category Filter':
      '\u5cf0\u503c\u66f2\u7ebf\u5206\u7c7b\u7b5b\u9009',
  'Range': '\u65f6\u95f4\u8303\u56f4',
  'Select Peak Curve Category':
      '\u9009\u62e9\u5cf0\u503c\u66f2\u7ebf\u5206\u7c7b',
  'Spending Peak Curve (Last 60 Days)':
      '\u6d88\u8d39\u5cf0\u503c\u66f2\u7ebf\uff08\u8fd160\u5929\uff09',
  'Spending Suggestions': '\u6d88\u8d39\u5efa\u8bae',
  'Tx Count': '\u4ea4\u6613\u7b14\u6570',
  'Spending increased quickly': '\u652f\u51fa\u589e\u957f\u8fc7\u5feb',
  'Income-expense balance is negative': '\u6536\u652f\u5e73\u8861\u4e3a\u8d1f',
  'Category concentration is high':
      '\u6d88\u8d39\u5206\u7c7b\u96c6\u4e2d\u5ea6\u8f83\u9ad8',
  'Spending pattern is stable': '\u6d88\u8d39\u7ed3\u6784\u8f83\u7a33\u5b9a',
};

String dat(BuildContext context, String en) {
  if (en.startsWith('Peak spending day detected ')) {
    final day = en.substring('Peak spending day detected '.length);
    return tr(
      context,
      en: en,
      zh: '\u68c0\u6d4b\u5230\u6d88\u8d39\u5cf0\u503c\u65e5 $day',
    );
  }
  if (en.startsWith('Monthly Expense Trend (')) {
    final r = en.substring('Monthly Expense Trend ('.length, en.length - 1);
    return tr(
      context,
      en: en,
      zh: '\u6708\u5ea6\u652f\u51fa\u53d8\u5316\uff08$r\uff09',
    );
  }
  if (en.startsWith('Income-Expense Balance Rate Trend (')) {
    final r = en.substring(
      'Income-Expense Balance Rate Trend ('.length,
      en.length - 1,
    );
    return tr(
      context,
      en: en,
      zh: '\u6536\u652f\u5e73\u8861\u5ea6\u53d8\u5316\uff08$r\uff09',
    );
  }
  if (en.startsWith('Peak: ') && en.contains(' | Avg daily: ')) {
    final body = en.substring('Peak: '.length);
    final idx = body.indexOf(' | Avg daily: ');
    if (idx >= 0) {
      final peak = body.substring(0, idx);
      final avg = body.substring(idx + ' | Avg daily: '.length);
      return tr(
        context,
        en: en,
        zh: '\u5cf0\u503c: $peak | \u65e5\u5747: $avg',
      );
    }
  }
  return tr(context, en: en, zh: _kDeepZh[en] ?? en);
}
