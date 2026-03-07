import 'package:flutter/widgets.dart';

import '../../l10n/tr.dart';

const Map<String, String> _kSettingsZh = <String, String>{
  'Settings': '设置',
  'Language': '语言',
  'Stats': '统计',
  'History': '历史记录',
  'Categories': '分类管理',
  'Switch Account': '切换账户',
  'Manage Accounts': '账户管理',
  'Recurring': '周期交易',
  'Analysis': '分析',
  'External Import': '外部账单导入',
  'Indigo': '靛蓝',
  'Forest': '森林',
  'Sunset': '日落',
  'Ocean': '海洋',
  'Low Balance Reminder': '余额不足提醒',
  'Bound to current account and auto-saved': '与当前账户绑定并自动保存',
  'Reminder Amount': '提醒金额',
  'e.g. 100': '例如 100',
  'Saved silently while typing': '手动输入时静默保存',
  'Theme Editor': '主题编辑',
  'Current': '当前',
  'Quick Action Editor': '快捷键编辑',
  'Button 3': '按键3',
  'Button 4': '按键4',
  'Pet Assistant': '宠物助手',
  'Import & Export': '导入导出',
  'Account Security': '账户安全',
  'Close': '关闭',
  'Select Theme Style': '选择主题风格',
  'Background image applied': '背景图片已应用',
  'Failed to select image': '选择图片失败',
  'Dark Mode': '深色模式',
  'Theme Style': '主题风格',
  'Custom Background Image': '自定义背景图片',
  'Configured': '已设置',
  'Not configured': '未设置',
  'Choose Image': '选择图片',
  'Remove': '移除',
  'Background White Mist': '背景白雾强度',
  'Select Button 3 Action': '选择按键3功能',
  'Select Button 4 Action': '选择按键4功能',
  'Search and Add are fixed on home. Customize slot 3 and slot 4 here.':
      '首页“搜索”和“新增”为固定按键，这里仅可自定义按键3和按键4。',
  'Save': '保存',
  'Low': '低',
  'Normal': '中',
  'High': '高',
  'Select Talk Frequency': '选择发言频率',
  'Select Appearance': '选择外观',
  'Enable Pet': '启用宠物',
  'Talk Frequency': '发言频率',
  'Pet Size': '宠物大小',
  'Appearance': '外观',
  'Backup exported': '备份已导出',
  'Export Backup (JSON)': '导出备份（JSON）',
  'Import (Append Only)': '导入（仅追加）',
  'Clear All Stored Bills': '清空已存储账单',
  'Change Password': '修改密码',
  'Email verification required before update': '修改前需先完成邮箱验证码验证',
  'Change Bound Email': '切换绑定邮箱',
  'Email Verification Code': '邮箱验证码',
  'Sending...': '发送中...',
  'Send Code': '发送验证码',
  'Verifying...': '验证中...',
  'Verify': '验证',
  'Verification passed': '验证通过',
  'Current email not found.': '未找到当前登录邮箱。',
  'Please enter a valid 6-digit code.': '请输入有效的 6 位验证码。',
  'Email verified': '邮箱验证成功',
  'Please complete email verification first.': '请先完成邮箱验证码验证。',
  'Password must be at least 6 characters.': '密码长度至少 6 位。',
  'Passwords do not match.': '两次密码输入不一致。',
  'Password updated': '密码已更新',
  'New Password': '新密码',
  'Confirm Password': '确认新密码',
  'Saving...': '保存中...',
  'Update Password': '更新密码',
  'Please enter a valid email.': '请输入有效的邮箱地址。',
  'New email cannot be the same as current.': '新邮箱不能与当前邮箱相同。',
  'New Email': '新邮箱',
  'Update Bound Email': '更新绑定邮箱',
};

String st(BuildContext context, String en) {
  final zh = _dynamicZh(en) ?? _kSettingsZh[en] ?? en;
  return tr(context, en: en, zh: zh);
}

String? _dynamicZh(String en) {
  if (en.startsWith('Current bound email: ')) {
    final email = en.substring('Current bound email: '.length);
    return '当前绑定邮箱：$email';
  }
  if (en.startsWith('Verification code sent to ')) {
    final email = en.substring('Verification code sent to '.length);
    return '验证码已发送到 $email';
  }

  final imported = RegExp(r'^Imported (.+), skipped (.+)$').firstMatch(en);
  if (imported != null) {
    return '已导入 ${imported.group(1)}，跳过 ${imported.group(2)}';
  }

  final cleared = RegExp(r'^Cleared local (.+), cloud (.+)\.$').firstMatch(en);
  if (cleared != null) {
    return '已清空本地 ${cleared.group(1)}，云端 ${cleared.group(2)}。';
  }
  return null;
}
