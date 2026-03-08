import 'package:flutter/widgets.dart';

import '../../../l10n/tr.dart';

const Map<String, String> _kSideMenuZh = <String, String>{
  'Accounts': '\u8d26\u6237',
  'Switch Account': '\u5207\u6362\u8d26\u6237',
  'Manage Accounts': '\u8d26\u6237\u7ba1\u7406',
  'Navigate': '\u5bfc\u822a',
  'Stats': '\u7edf\u8ba1',
  'History': '\u5386\u53f2',
  'Analysis': '\u5206\u6790',
  'Recurring': '\u5468\u671f\u4ea4\u6613',
  'Categories': '\u5206\u7c7b\u7ba1\u7406',
  'Import External Bills': '\u5bfc\u5165\u5916\u90e8\u8d26\u5355',
  'Preferences': '\u504f\u597d',
  'Replay Tutorial': '\u91cd\u65b0\u64ad\u653e\u65b0\u624b\u6559\u7a0b',
  'Settings': '\u8bbe\u7f6e',
  'Theme': '\u4e3b\u9898',
  'Sign Out': '\u767b\u51fa',
};

String lsmt(BuildContext context, String en) {
  return tr(context, en: en, zh: _kSideMenuZh[en] ?? en);
}
