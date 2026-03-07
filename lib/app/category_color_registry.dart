import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CategoryColorRegistry {
  static const _kMap = 'category_color_map_v1'; // key -> int ARGB
  static const _kSeed = 'category_color_seed_v1'; // int

  // 颜色“太像”的阈值（0~1）
  static const double _minDistance = 0.18;

  static Future<Map<String, int>> _loadMap() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kMap);
    if (raw == null || raw.isEmpty) return {};
    final m = jsonDecode(raw) as Map<String, dynamic>;
    return m.map((k, v) => MapEntry(k, (v as num).toInt()));
  }

  static Future<void> _saveMap(Map<String, int> map) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kMap, jsonEncode(map));
  }

  static Future<int> _loadSeed() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getInt(_kSeed) ?? 0;
  }

  static Future<void> _saveSeed(int seed) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(_kSeed, seed);
  }

  /// 生成一个“离已有颜色远”的新颜色
  static Color _generateNextColor(int seed) {
    // golden angle (degrees)
    const golden = 137.508;
    final hue = (seed * golden) % 360.0;

    // 固定高饱和度，偏中等亮度：更直观
    const sat = 0.78;
    const light = 0.52;

    return HSLColor.fromAHSL(1.0, hue, sat, light).toColor();
  }

  /// 粗略颜色距离：用 HSV 近似（足够用于“别太像”）
  static double _dist(Color a, Color b) {
    final ha = HSVColor.fromColor(a);
    final hb = HSVColor.fromColor(b);

    // hue 是环形，取最短角距离
    final dhRaw = (ha.hue - hb.hue).abs();
    final dh = (dhRaw > 180) ? 360 - dhRaw : dhRaw;

    final ds = (ha.saturation - hb.saturation).abs();
    final dv = (ha.value - hb.value).abs();

    // 归一化：hue/360
    return (dh / 360.0) * 0.7 + ds * 0.2 + dv * 0.1;
  }

    /// 批量获取颜色：一次性加载/分配/保存，避免并发写入导致“逐渐补齐”
  static Future<List<Color>> getMany(List<String> keys) async {
    // “其他”也走同一套输出，但不写入map
    final map = await _loadMap();
    var seed = await _loadSeed();

    // 已存在颜色集合（包含本次新分配的，保证彼此差异）
    final existingColors = map.values.map((v) => Color(v)).toList();

    Color allocateNew(String key) {
      // “其他”固定灰色，不参与占位
      if (key == '__other__') return Colors.grey;

      for (int attempt = 0; attempt < 120; attempt++) {
        final candidate = _generateNextColor(seed + attempt);

        bool ok = true;
        for (final c in existingColors) {
          if (_dist(candidate, c) < _minDistance) {
            ok = false;
            break;
          }
        }
        if (ok) {
          seed = seed + attempt + 1;
          existingColors.add(candidate);
          map[key] = candidate.value;
          return candidate;
        }
      }

      // 兜底
      final fallback = _generateNextColor(seed);
      seed += 1;
      existingColors.add(fallback);
      map[key] = fallback.value;
      return fallback;
    }

    final out = <Color>[];
    for (final k in keys) {
      if (k == '__other__') {
        out.add(Colors.grey);
        continue;
      }

      final exist = map[k];
      if (exist != null) {
        out.add(Color(exist));
      } else {
        out.add(allocateNew(k));
      }
    }

    // 一次性保存
    await _saveSeed(seed);
    await _saveMap(map);

    return out;
  }
}