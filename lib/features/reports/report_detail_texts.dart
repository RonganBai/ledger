import 'package:flutter/widgets.dart';

import '../../l10n/tr.dart';

const Map<String, String> _kReportDetailZh = <String, String>{
  'Details': '\u660e\u7ec6',
  'Expense': '\u652f\u51fa',
  'Income': '\u6536\u5165',
  'No transaction details saved in this report yet.':
      '\u8be5\u62a5\u8868\u6682\u65e0\u4ea4\u6613\u660e\u7ec6\u3002',
  'Other': '\u5176\u4ed6',
  'Pending': '\u5f85\u5904\u7406',
  'Report': '\u62a5\u8868',
  'Spending Summary': '\u652f\u51fa\u6c47\u603b',
};

String rdt(BuildContext context, String en) {
  return tr(context, en: en, zh: _kReportDetailZh[en] ?? en);
}
