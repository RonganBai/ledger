import 'package:flutter/widgets.dart';

import '../../../l10n/tr.dart';

const Map<String, String> _kExpensePieZh = <String, String>{
  'Expense Breakdown': '\u652f\u51fa\u5360\u6bd4',
  'No expense category data this month':
      '\u672c\u6708\u6682\u65e0\u652f\u51fa\u5206\u7c7b\u6570\u636e',
  'No expenses this month': '\u672c\u6708\u6682\u65e0\u652f\u51fa\u91d1\u989d',
  'Other': '\u5176\u4ed6',
};

String ept(BuildContext context, String en) {
  return tr(context, en: en, zh: _kExpensePieZh[en] ?? en);
}
