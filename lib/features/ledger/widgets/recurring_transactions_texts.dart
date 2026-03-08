import 'package:flutter/widgets.dart';

import '../../../l10n/tr.dart';

const Map<String, String> _kRecurringZh = <String, String>{
  'Delete recurring item?': '\u5220\u9664\u5468\u671f\u4ea4\u6613\uff1f',
  'Cancel': '\u53d6\u6d88',
  'Delete': '\u5220\u9664',
  'Daily': '\u6bcf\u5929',
  'Weekly': '\u6bcf\u5468',
  'Monthly': '\u6bcf\u6708',
  'Mon': '\u5468\u4e00',
  'Tue': '\u5468\u4e8c',
  'Wed': '\u5468\u4e09',
  'Thu': '\u5468\u56db',
  'Fri': '\u5468\u4e94',
  'Sat': '\u5468\u516d',
  'Sun': '\u5468\u65e5',
  'Day': '\u7b2c',
  'at': '\u65e5',
  'Recurring Transactions': '\u5468\u671f\u4ea4\u6613',
  'No recurring items yet': '\u8fd8\u6ca1\u6709\u5468\u671f\u4ea4\u6613',
  'Add Recurring': '\u65b0\u589e\u5468\u671f\u4ea4\u6613',
  'Monday': '\u5468\u4e00',
  'Tuesday': '\u5468\u4e8c',
  'Wednesday': '\u5468\u4e09',
  'Thursday': '\u5468\u56db',
  'Friday': '\u5468\u4e94',
  'Saturday': '\u5468\u516d',
  'Sunday': '\u5468\u65e5',
  'Edit Recurring': '\u7f16\u8f91\u5468\u671f\u4ea4\u6613',
  'Title': '\u540d\u79f0',
  'Amount': '\u91d1\u989d',
  'Type': '\u7c7b\u578b',
  'Expense': '\u652f\u51fa',
  'Income': '\u6536\u5165',
  'Cycle': '\u5468\u671f',
  'Weekday': '\u5468\u51e0',
  'Day of month': '\u6bcf\u6708\u65e5\u671f',
  'Auto add time': '\u81ea\u52a8\u6dfb\u52a0\u65f6\u95f4',
  'Memo (optional)': '\u5907\u6ce8\uff08\u53ef\u9009\uff09',
  'Enabled': '\u542f\u7528',
  'Save': '\u4fdd\u5b58',
};

String rrt(BuildContext context, String en) {
  if (en.startsWith('Delete "') && en.endsWith('"?')) {
    final v = en.substring(8, en.length - 2);
    return tr(
      context,
      en: en,
      zh: '\u786e\u5b9a\u5220\u9664\u201c$v\u201d\uff1f',
    );
  }
  return tr(context, en: en, zh: _kRecurringZh[en] ?? en);
}
