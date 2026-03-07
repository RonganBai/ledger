import 'package:flutter/widgets.dart';

import '../../../l10n/tr.dart';

const Map<String, String> _kMonthlyStatsZh = <String, String>{
  '7D': '7\u5929',
  'Month': '\u672c\u6708',
  'Year': '\u5168\u5e74',
  'Balance': '\u4f59\u989d',
  'Balance Trend': '\u4f59\u989d\u8d8b\u52bf',
  'Expense': '\u652f\u51fa',
  'Income': '\u6536\u5165',
  'Net': '\u51c0\u989d',
};

String mst(BuildContext context, String en) {
  return tr(context, en: en, zh: _kMonthlyStatsZh[en] ?? en);
}
