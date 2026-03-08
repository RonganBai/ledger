import 'package:flutter/widgets.dart';

import '../../l10n/tr.dart';

const Map<String, String> _kLedgerHomeZh = <String, String>{
  'Add Bill': '新增账单',
  'All Set': '已完成',
  'Analysis': '分析',
  'Back': '上一步',
  'Batch Delete': '批量删除',
  'Batch delete appears after long-pressing at least one bill.':
      '长按至少一条账单后，会显示批量删除功能。',
  'Cancel': '取消',
  'Categories': '分类',
  'Customize Quick Actions': '自定义快捷操作',
  'Delete': '删除',
  'Delete selected?': '删除已选记录？',
  'Done': '完成',
  'Edit / Delete': '编辑删除',
  'External Import': '外部账单导入',
  'History': '历史',
  'Home Tutorial': '新手教程',
  'Ledger': '记账',
  'Long-press a bill to enter selection mode, then use Select all / Delete in the top bar.':
      '长按账单进入选择模式，然后在顶部使用全选和删除。',
  'Manage Accounts': '账户管理',
  'Menu': '菜单',
  'Next': '下一步',
  'No bill yet. Add one first, then you can swipe right to edit and left to delete.':
      '还没有账单。先新增一条，之后可右滑编辑、左滑删除。',
  'Open Search': '打开搜索',
  'Recurring': '周期交易',
  'Search & Filters': '搜索与筛选',
  'Select all': '全选',
  'Settings': '设置',
  'Skip': '跳过',
  'Slot 3/4 quick actions can be customized from Settings.':
      '可在设置中自定义第3和第4个快捷按钮。',
  'Stats': '统计',
  'Swipe right on a bill to edit, swipe left to delete.': '账单向右滑可编辑，向左滑可删除。',
  'Switch Account': '切换账户',
  'Tap search to expand/collapse the filter panel.': '点击搜索可展开或收起筛选面板。',
  'Tap this button to create a new transaction.': '点击此按钮创建一笔新交易。',
  'This cannot be undone.': '此操作无法撤销。',
  'This guide shows adding bills, editing/deleting, searching, batch delete, and quick actions.':
      '本教程将演示：新增账单、编辑删除、搜索筛选、批量删除和快捷操作。',
  'You can do fuzzy keyword search and combine date/category filters.':
      '支持关键词模糊搜索，并可组合日期和分类筛选。',
  'You can replay this tutorial anytime from the side menu.':
      '可随时在侧边菜单重新播放本教程。',
};

String lht(BuildContext context, String en) {
  if (en.startsWith('Edit Button ')) {
    final v = en.substring('Edit Button '.length);
    return tr(context, en: en, zh: '编辑按键 $v');
  }
  if (en.startsWith('Current: ')) {
    final v = en.substring('Current: '.length);
    return tr(context, en: en, zh: '当前：$v');
  }
  if (en.startsWith('Selected ')) {
    final v = en.substring('Selected '.length);
    return tr(context, en: en, zh: '已选 $v');
  }
  return tr(context, en: en, zh: _kLedgerHomeZh[en] ?? en);
}
