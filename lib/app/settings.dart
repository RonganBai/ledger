import 'package:shared_preferences/shared_preferences.dart';

class Settings {
  static const _kMinBalance = 'min_balance';
  static const _kMaxBalance = 'max_balance';
  static const _kMinBalanceByAccountPrefix = 'min_balance_account_';
  static const _kMaxBalanceByAccountPrefix = 'max_balance_account_';

  static String _minKeyForAccount(int accountId) => '$_kMinBalanceByAccountPrefix$accountId';
  static String _maxKeyForAccount(int accountId) => '$_kMaxBalanceByAccountPrefix$accountId';

  static Future<double?> getMinBalance({int? accountId}) async {
    final sp = await SharedPreferences.getInstance();
    if (accountId != null) {
      final k = _minKeyForAccount(accountId);
      if (sp.containsKey(k)) return sp.getDouble(k);
    }
    return sp.containsKey(_kMinBalance) ? sp.getDouble(_kMinBalance) : null;
  }

  static Future<double?> getMaxBalance({int? accountId}) async {
    final sp = await SharedPreferences.getInstance();
    if (accountId != null) {
      final k = _maxKeyForAccount(accountId);
      if (sp.containsKey(k)) return sp.getDouble(k);
    }
    return sp.containsKey(_kMaxBalance) ? sp.getDouble(_kMaxBalance) : null;
  }

  static Future<void> setMinBalance(double? v, {int? accountId}) async {
    final sp = await SharedPreferences.getInstance();
    if (accountId != null) {
      final k = _minKeyForAccount(accountId);
      if (v == null) {
        await sp.remove(k);
      } else {
        await sp.setDouble(k, v);
      }
      return;
    }
    if (v == null) {
      await sp.remove(_kMinBalance);
    } else {
      await sp.setDouble(_kMinBalance, v);
    }
  }

  static Future<void> setMaxBalance(double? v, {int? accountId}) async {
    final sp = await SharedPreferences.getInstance();
    if (accountId != null) {
      final k = _maxKeyForAccount(accountId);
      if (v == null) {
        await sp.remove(k);
      } else {
        await sp.setDouble(k, v);
      }
      return;
    }
    if (v == null) {
      await sp.remove(_kMaxBalance);
    } else {
      await sp.setDouble(_kMaxBalance, v);
    }
  }
}
