// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 竹笌主题（App Theme）
//
// 位于：core/theme/app_theme.dart
// 职责：定义 App 的颜色、字体、圆角等视觉规范
//
// 设计定位（按「竹芽 2.0 设定思路」+ 用户确认）：
//   简约少年系 —— 白底 + 亮色点缀，干净直接。
//   语音优先、文字辅助；少年感·阳光·直接。
//
// 颜色语义：
//   bamboo      嫩绿 → 品牌主色（按钮、图标、强调）
//   bambooDeep  深竹绿 → 状态字、发送键、左边线、次级强调
//   warmYellow  暖黄 → 阳光感点缀、用户气泡
//   paper       米白 → 页面底色、卡片底
//   softText    正文 → 接近纯黑但更柔和
//   subText     辅助文字 → 中灰
//
// 设计令牌（Tokens）：圆角 / 间距 / 字阶集中在此，各页引用，杜绝硬编码。
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // ════════════════════════════════════════════════════════
  // 品牌色
  // ════════════════════════════════════════════════════════

  /// 嫩绿：品牌主色
  /// 用于：按钮、高亮、图标、Logo
  static const Color bamboo = Color(0xFF8BC34A);

  /// 深竹绿：次级强调
  /// 用于：状态字、发送键、AI 气泡左边线、环形进度
  static const Color bambooDeep = Color(0xFF6B9E78);

  /// 暖黄：阳光感点缀
  /// 用于：用户气泡、强调
  static const Color warmYellow = Color(0xFFFFD54F);

  /// 已弃用（旧温暖治愈风残留），保留仅为兼容旧引用，新代码勿用。
  static const Color coral = Color(0xFFFF7F7F);
  static const Color mint = Color(0xFFB5EAD7);

  // ════════════════════════════════════════════════════════
  // 背景 & 文字
  // ════════════════════════════════════════════════════════

  /// 米白背景（护眼、简约白底）
  static const Color paper = Color(0xFFFAFAFA);

  /// 正文（比纯黑柔和）
  static const Color softText = Color(0xFF212121);

  /// 次要文字（中灰）
  static const Color subText = Color(0xFF757575);

  // ════════════════════════════════════════════════════════
  // 消息气泡
  // ════════════════════════════════════════════════════════

  /// 用户消息气泡：暖黄底
  static const Color userBubble = Color(0xFFFFE8A8);

  /// 竹笌消息气泡：淡绿底
  static const Color assistantBubble = Color(0xFFE8F5E9);

  // ════════════════════════════════════════════════════════
  // 暗色模式颜色
  // ════════════════════════════════════════════════════════

  /// 暗色模式背景
  static const Color darkBg = Color(0xFF1A1A2E);

  /// 暗色模式卡片
  static const Color darkCard = Color(0xFF252540);

  // ════════════════════════════════════════════════════════
  // 间距 & 圆角
  // ════════════════════════════════════════════════════════

  /// 标准间距
  static const double padding = 16.0;
  static const double paddingSm = 8.0;
  static const double paddingLg = 24.0;

  /// 圆角阶梯：8 小组件/标签 · 12 卡片 · 16 大卡片 · 20 气泡/主按钮
  static const double radiusSm = 8.0;
  static const double radius = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 20.0;

  // ════════════════════════════════════════════════════════
  // 字体
  // ════════════════════════════════════════════════════════

  /// 标题字号
  static const double fontTitle = 20.0;

  /// 正文字号
  static const double fontBody = 16.0;

  /// 辅助字（小字、标签）
  static const double fontCaption = 12.0;

  // ════════════════════════════════════════════════════════
  // 主题数据
  // ════════════════════════════════════════════════════════

  /// 亮色主题（简约少年系 · 白底）
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: bamboo,
      brightness: Brightness.light,
      surface: paper,
      onSurface: softText,
    ),
    scaffoldBackgroundColor: paper,
    appBarTheme: const AppBarTheme(
      backgroundColor: paper,
      foregroundColor: softText,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLg),
        side: const BorderSide(color: Color(0x1A212121), width: 0.5),
      ),
    ),
    // 圆角输入框（胶囊 20）
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusXl),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusXl),
        borderSide: const BorderSide(color: bambooDeep, width: 1.5),
      ),
    ),
    // 圆角主按钮
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: bamboo,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXl),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
  );

  /// 暗色主题
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: bamboo,
      brightness: Brightness.dark,
      surface: darkBg,
    ),
    scaffoldBackgroundColor: darkBg,
    appBarTheme: const AppBarTheme(
      backgroundColor: darkBg,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: darkCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLg),
      ),
    ),
  );
}
