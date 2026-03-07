import 'dart:math';
import 'package:flutter/material.dart';
import 'pet_config.dart';
import 'pet_controller.dart';

enum TxKind { expense, income }

class PetTalker {
  final PetController pet;
  final Random _rng = Random();

  DateTime _lastSpokeAt = DateTime.fromMillisecondsSinceEpoch(0);
  Duration cooldown = const Duration(seconds: 8);

  PetTalker(this.pet);

  bool _canSpeak() {
    final now = DateTime.now();
    if (now.difference(_lastSpokeAt) < cooldown) return false;
    _lastSpokeAt = now;
    return true;
  }

  String _pick(List<String> lines) => lines[_rng.nextInt(lines.length)];

  /// locale 用来决定中英文话术（你也可以只要中文）
  void onTransactionAdded({
    required TxKind kind,
    required int amountCents,
    String? categoryName,
    Locale? locale,
  }) {
    if (!PetConfig.I.enabled) return;

    cooldown = PetConfig.I.speakCooldown;
    if (_rng.nextDouble() > PetConfig.I.speakProbability) return;

    final isZh = (locale?.languageCode ?? 'en').toLowerCase().startsWith('zh');
    final amount = amountCents / 100.0;

    if (kind == TxKind.expense) {
      // 按类别增强提醒（可选）
      final cat = (categoryName ?? '').toLowerCase();

      if (amount < 20) {
        pet.say(_pick(isZh ? _zhExpenseSmall : _enExpenseSmall));
        return;
      }

      if (amount < 200) {
        // 购物/外卖等做轻提醒
        if (cat.contains('shopping') || cat.contains('购物')) {
          pet.say(_pick(isZh ? _zhShoppingMid : _enShoppingMid));
        } else if (cat.contains('food') || cat.contains('餐') || cat.contains('dining')) {
          pet.say(_pick(isZh ? _zhFoodMid : _enFoodMid));
        } else {
          pet.say(_pick(isZh ? _zhExpenseNormal : _enExpenseNormal));
        }
        return;
      }

      // 大额支出提醒
      pet.say(_pick(isZh ? _zhExpenseLarge : _enExpenseLarge));
      return;
    }

    // income
    if (amount >= 500) {
      pet.say(_pick(isZh ? _zhIncomeLarge : _enIncomeLarge));
    } else {
      pet.say(_pick(isZh ? _zhIncomeNormal : _enIncomeNormal));
    }
  }

  // ===== 语料库 =====

  static const _zhExpenseSmall = [
    "记得真及时！小额也记上很专业～",
    "这笔也记了👍 习惯越来越稳了！",
    "不错不错，越细越清楚～",
  ];

  static const _zhExpenseNormal = [
    "记录得很棒！月底复盘会很省心～",
    "稳稳记账中👏 继续保持！",
    "有记录就有掌控感～",
  ];

  static const _zhExpenseLarge = [
    "这笔支出有点大，回头看看是否必要哦。",
    "金额不小，建议补个备注，月底更好复盘。",
    "提醒一下：大额消费最好留凭证/备注～",
  ];

  static const _zhIncomeNormal = [
    "收入记上啦！记得保存来源信息～",
    "这笔收入不错👍 对账会更轻松。",
    "收入也记清楚，账目更完整～",
  ];

  static const _zhIncomeLarge = [
    "这笔收入挺可观，记得留存凭证，报税季更省事。",
    "提醒：大额收入建议备注来源，税务/对账都方便。",
    "不错！收入越清晰，报税越不慌～",
  ];

  static const _zhShoppingMid = [
    "购物这类容易超预算，记得回头看看清单哦～",
    "这笔是购物吗？适度就好，预算要稳住～",
    "记录很棒！购物支出可以月底一起复盘～",
  ];

  static const _zhFoodMid = [
    "餐饮支出记得真及时～外食次数也能看出来啦。",
    "这笔餐饮不错，月底看看外卖占比～",
    "记录一下餐饮，控制起来更容易～",
  ];

  // English versions (简洁版)
  static const _enExpenseSmall = [
    "Nice! Logging small expenses builds great habits.",
    "Good catch 👍 Every detail helps.",
    "Awesome—keep it consistent!",
  ];

  static const _enExpenseNormal = [
    "Great job logging it. Monthly review will be easier!",
    "Steady progress 👏 Keep it up.",
    "Tracking gives you control—nice!",
  ];

  static const _enExpenseLarge = [
    "That’s a big expense—worth reviewing later.",
    "Large amount: add a note/receipt for easier review.",
    "Reminder: big spends are easier to manage with notes.",
  ];

  static const _enIncomeNormal = [
    "Income logged—nice! Keep the source documented.",
    "Good! Reconciliation will be easier later.",
    "Great—clean records help a lot.",
  ];

  static const _enIncomeLarge = [
    "Nice income! Save proof—tax time will thank you.",
    "Large income: note the source for tax/review.",
    "Great! Clear income logs reduce tax-season stress.",
  ];

  static const _enShoppingMid = [
    "Shopping can drift—nice to keep an eye on it.",
    "Looks like shopping—staying on budget feels great.",
    "Good log. You can review shopping total later.",
  ];

  static const _enFoodMid = [
    "Food spend logged—nice! You can track eating-out trends.",
    "Great—food logs make monthly review easy.",
    "Nice record. Helps spot frequent takeout.",
  ];
}