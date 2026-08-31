// 主题状态（亮/暗模式）—— 从 legacy providers 迁移而来。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// 主题 Provider：true = 暗色模式，false = 亮色模式
final themeProvider = StateNotifierProvider<ThemeNotifier, bool>((ref) {
  final box = Hive.box('settings');
  // 首次访问时从 Hive 读取（持久化）
  return ThemeNotifier(box.get('isDarkMode', defaultValue: false) as bool);
});

class ThemeNotifier extends StateNotifier<bool> {
  ThemeNotifier(super.initialState) {
    // 确保 Hive 里也有值（防止首次启动为 null）
    final box = Hive.box('settings');
    state = box.get('isDarkMode', defaultValue: false) as bool;
  }

  /// 切换主题（亮 → 暗 / 暗 → 亮）
  void toggle() {
    state = !state;
    // 写入 Hive，下次启动时恢复
    Hive.box('settings').put('isDarkMode', state);
  }
}
