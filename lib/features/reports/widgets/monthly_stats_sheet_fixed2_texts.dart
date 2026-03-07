import 'package:flutter/widgets.dart';

import '../../../l10n/tr.dart';

const Map<String, String> _kMonthlyStats2Zh = <String, String>{
  '3D': '3\u5929',
  '7D': '7\u5929',
  'Balance Trend': '\u4f59\u989d\u8d8b\u52bf',
  'Expense': '\u652f\u51fa',
  'Income': '\u6536\u5165',
  'No expense category data this month':
      '\u672c\u6708\u6682\u65e0\u652f\u51fa\u5206\u7c7b\u6570\u636e',
  'No expense category data this week':
      '\u672c\u5468\u6682\u65e0\u652f\u51fa\u5206\u7c7b\u6570\u636e',
};

String mst2(BuildContext context, String en) {
  if (en.startsWith('This Month (') && en.endsWith(')')) {
    final v = en.substring('This Month ('.length, en.length - 1);
    return tr(context, en: en, zh: '\u672c\u6708\u7edf\u8ba1\uff08$v\uff09');
  }
  if (en.startsWith('This Week (') && en.endsWith(')')) {
    final v = en.substring('This Week ('.length, en.length - 1);
    return tr(context, en: en, zh: '\u672c\u5468\u7edf\u8ba1\uff08$v\uff09');
  }
  if (en.startsWith('Daily Balance (') && en.endsWith(')')) {
    final v = en.substring('Daily Balance ('.length, en.length - 1);
    return tr(context, en: en, zh: '\u6bcf\u65e5\u4f59\u989d\uff08$v\uff09');
  }
  if (en.startsWith('Last ') &&
      en.contains(' Days (') &&
      en.endsWith(')') &&
      en.contains('\${r.monthKey}')) {
    final n = en.substring('Last '.length, en.indexOf(' Days ('));
    final v = en.substring(
      en.indexOf(' Days (') + ' Days ('.length,
      en.length - 1,
    );
    return tr(context, en: en, zh: '\u6700\u8fd1$n\u5929\uff08$v\uff09');
  }
  if (en.startsWith('No expense category data in last ') &&
      en.endsWith(' days')) {
    final n = en.substring(
      'No expense category data in last '.length,
      en.length - ' days'.length,
    );
    return tr(
      context,
      en: en,
      zh: '\u6700\u8fd1$n\u5929\u6682\u65e0\u652f\u51fa\u5206\u7c7b\u6570\u636e',
    );
  }
  if (en.startsWith('Last ') && en.contains(' day(s)') && en.contains('min')) {
    final body = en.substring('Last '.length);
    final idx = body.indexOf(' day(s)');
    final n = idx > 0 ? body.substring(0, idx) : '';
    final minTag = 'min \$';
    final maxTag = 'max \$';
    final iMin = en.indexOf(minTag);
    final iMax = en.indexOf(maxTag);
    if (iMin >= 0 && iMax > iMin) {
      final minV = en.substring(iMin + minTag.length, iMax).trim();
      final maxV = en.substring(iMax + maxTag.length).trim();
      return tr(
        context,
        en: en,
        zh: '\u6700\u8fd1$n\u5929  \u2022  \u6700\u4f4e\$$minV  \u6700\u9ad8\$$maxV',
      );
    }
  }
  return tr(context, en: en, zh: _kMonthlyStats2Zh[en] ?? en);
}
