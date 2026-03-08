import 'package:flutter/widgets.dart';

import '../../../l10n/tr.dart';

const Map<String, String> _kQuickActionsZh = <String, String>{
  'Search': '\u641c\u7d22',
  'Add': '\u6dfb\u52a0',
};

String lqat(BuildContext context, String en) {
  return tr(context, en: en, zh: _kQuickActionsZh[en] ?? en);
}
