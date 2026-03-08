import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PetFrequency { low, normal, high }

class PetSkin {
  final String id;
  final String name;
  final String left;
  final String right;
  final String drag;

  const PetSkin({
    required this.id,
    required this.name,
    required this.left,
    required this.right,
    required this.drag,
  });
}

class PetConfig extends ChangeNotifier {
  PetConfig._();
  static final PetConfig I = PetConfig._();

  // ====== 可配置项 ======
  bool enabled = false;
  PetFrequency frequency = PetFrequency.normal;
  String skinId = 'default';
  int sizeLevel = 2; // 0..4 => 0.5x..1.5x, default 1.0x

  // 你可以在这里添加更多皮肤
  static const List<PetSkin> skins = [
    PetSkin(
      id: 'default',
      name: '凑企鹅',
      left: 'assets/skins/pet_left.png',
      right: 'assets/skins/pet_right.png',
      drag: 'assets/skins/pet_drag.png',
    ),
    PetSkin(
      id: 'cat',
      name: '粉奶龙',
      left: 'assets/skins/yifeng_left.png',
      right: 'assets/skins/yifeng_right.png',
      drag: 'assets/skins/yifeng_drag.png',
    ),
  ];

  PetSkin get skin =>
      skins.firstWhere((s) => s.id == skinId, orElse: () => skins.first);

  double get sizeScale => 0.5 + (sizeLevel * 0.25);

  // ====== 频率映射（给 PetTalker 用）======
  /// 每次记账“有多大概率发言”
  double get speakProbability {
    switch (frequency) {
      case PetFrequency.low:
        return 0.18;
      case PetFrequency.normal:
        return 0.40;
      case PetFrequency.high:
        return 0.75;
    }
  }

  /// 发言冷却时间（防刷屏）
  Duration get speakCooldown {
    switch (frequency) {
      case PetFrequency.low:
        return const Duration(seconds: 18);
      case PetFrequency.normal:
        return const Duration(seconds: 8);
      case PetFrequency.high:
        return const Duration(seconds: 3);
    }
  }

  // ====== 持久化 ======
  static const _kEnabled = 'pet_enabled';
  static const _kFreq = 'pet_freq';
  static const _kSkin = 'pet_skin';
  static const _kSizeLevel = 'pet_size_level';

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    enabled = sp.getBool(_kEnabled) ?? false;
    skinId = sp.getString(_kSkin) ?? 'default';
    sizeLevel = (sp.getInt(_kSizeLevel) ?? 2).clamp(0, 4).toInt();
    final freqStr = sp.getString(_kFreq) ?? 'normal';
    frequency = PetFrequency.values.firstWhere(
      (e) => e.name == freqStr,
      orElse: () => PetFrequency.normal,
    );
    notifyListeners();
  }

  Future<void> setEnabled(bool v) async {
    enabled = v;
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kEnabled, v);
  }

  Future<void> setFrequency(PetFrequency v) async {
    frequency = v;
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kFreq, v.name);
  }

  Future<void> setSkin(String id) async {
    skinId = id;
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kSkin, id);
  }

  Future<void> setSizeLevel(int v) async {
    sizeLevel = v.clamp(0, 4).toInt();
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(_kSizeLevel, sizeLevel);
  }
}
