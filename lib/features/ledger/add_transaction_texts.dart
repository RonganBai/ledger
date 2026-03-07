import 'package:flutter/widgets.dart';

import '../../l10n/tr.dart';

const Map<String, String> _kAddTxZh = <String, String>{
  'Add': '添加',
  'Amount': '金额',
  'At the top, pick the bill date first.': '从上到下，先设置账单日期。',
  'Back': '上一步',
  'Back to Tutorial': '返回教程',
  'Categories': '类别',
  'Category': '分类',
  'Choose Expense or Income. This changes available categories.':
      '选择支出或收入，下方可选分类会随之变化。',
  'Content': '内容',
  'Date': '日期',
  'Done': '完成',
  'Edit': '编辑',
  'Edit Page': '编辑页面',
  'Enter the amount for this bill.': '输入本次账单金额。',
  'Expense': '支出',
  'Fill in notes/content to make this record easier to find later.':
      '填写备注内容，后续搜索更方便。',
  'Income': '收入',
  'Lunch with colleagues': '和同事午餐',
  'New category': '新增类别',
  'Next': '下一步',
  'Open Category and select one (you can also add a new category).':
      '打开分类并选择一个，也可以新增分类。',
  'Save': '保存',
  'Save Bill': '保存账单',
  'Select': '请选择',
  'Skip Section': '跳过此节',
  'Step 1: Date': '第 1 步：日期',
  'Step 2: Income/Expense': '第 2 步：收支类型',
  'Step 3: Amount': '第 3 步：金额',
  'Step 4: Category': '第 4 步：分类',
  'Step 5: Content': '第 5 步：内容',
  'Step 6: Save': '第 6 步：保存',
  'Tap the highlighted Save/Add button to finish and create this bill.':
      '点击高亮保存/添加按钮，完成并成功新增账单。',
  'This is the edit page. It is almost the same as Add page. Return to continue delete tutorial.':
      '这是编辑页面，和添加页面基本一致。返回后继续删除功能教程。',
};

String at(BuildContext context, String en) {
  if (en.startsWith('Failed to add category: ')) {
    final err = en.substring('Failed to add category: '.length);
    return tr(context, en: en, zh: '新增类别失败：$err');
  }
  return tr(context, en: en, zh: _kAddTxZh[en] ?? en);
}
