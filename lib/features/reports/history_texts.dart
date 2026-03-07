import 'package:flutter/widgets.dart';

import '../../l10n/tr.dart';

const Map<String, String> _kHistoryZh = <String, String>{
  'Delete report?': '删除报表？',
  'Cancel': '取消',
  'Delete': '删除',
  'History': '历史记录',
  'Refresh': '刷新',
  'No archived monthly reports yet for this account.': '该账户暂无月度归档报表。',
  'Income': '收入',
  'Expense': '支出',
  'Tap to view': '点击查看',
};

String ht(BuildContext context, String en) {
  if (en.startsWith('This will remove the archived report file for ')) {
    final monthKey = en
        .substring('This will remove the archived report file for '.length)
        .replaceAll('.', '');
    return tr(context, en: en, zh: '这将删除 $monthKey 的归档报表文件。');
  }
  if (en.startsWith('Error: ')) {
    final msg = en.substring('Error: '.length);
    return tr(context, en: en, zh: '出错：$msg');
  }
  return tr(context, en: en, zh: _kHistoryZh[en] ?? en);
}
