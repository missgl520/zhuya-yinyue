// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 竹笌主题（App Theme）
//
// 位于：core/theme/app_theme.dart
// 职责：定义 App 的颜色、字体、圆角等视觉规范
//
// 设计令牌基线：docs/phase1/design-tokens.json
// 设计语言：竹语·声场（Bamboo Voice × Sound Field）
//   少年感、阳光、直接、有温度；语音优先、角色在场、创作即反馈。
//
// 颜色语义（按用途命名，不按色相）：
//   bg           竹雾 → 页面背景
//   surface      白 → 卡片/容器
//   surfaceWarm  暖米 → 音乐狗子/我的页暖区
//   surfaceSunken 凹陷 → 输入框
//   fg           竹墨 → 主文本
//   fg2          → 次级文本
//   muted        → 辅助/说明
//   meta         → 三级/元数据
//   border       → 默认边框
//   borderSoft   → 内部行分隔
//   accent       竹绿 → 品牌主色（按钮/图标/Logo/发送键）
//   accentDeep   深竹 → 竹底上的文字、按下态
//   accentSoft   → 选中/高亮底（chip、active tab）
//   sun          暖金 → 音乐狗子能量色 + 用户气泡
//   sunSoft      → 暖区底
//   ember        暖珊瑚 → 音乐动作色（录音/生成/播放），暖橙非粉
//   emberSoft    → 动作态底
//   success      → 成功/在线
//   warn         → 警告
//   danger       → 错误/挂断（暖红，非粉）
//   info         → 信息（= accent）
//
// P0 红线：
//   - 禁止紫粉渐变（#7C3AED→#EC4899）
//   - 深色底为竹调深 #0E1512（非紫调 navy #1A1A2E）
//   - 卡片圆角上限 16px
//   - 间距 4px 网格（禁止 5/7/13/15/22/30）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // ════════════════════════════════════════════════════════
  // Surface（表面层）
  // ════════════════════════════════════════════════════════

  /// 竹雾：页面背景（替换旧 #EDF7F0 / #FAFAFA）
  static const Color bg = Color(0xFFF1F6EE);

  /// 白：卡片/容器
  static const Color surface = Color(0xFFFFFFFF);

  /// 暖米：音乐狗子/我的页暖区（替换旧 #F5EFE5 / #FFF8F0）
  static const Color surfaceWarm = Color(0xFFFBF4E9);

  /// 凹陷：输入框/凹陷区
  static const Color surfaceSunken = Color(0xFFE9F0E5);

  // ════════════════════════════════════════════════════════
  // Foreground（前景层）
  // ════════════════════════════════════════════════════════

  /// 竹墨：主文本（替换旧 #212121，加绿调）
  static const Color fg = Color(0xFF1E2B1E);

  /// 次级文本
  static const Color fg2 = Color(0xFF44563F);

  /// 辅助/说明（替换旧 #757575）
  static const Color muted = Color(0xFF6E7C68);

  /// 三级/元数据
  static const Color meta = Color(0xFF9AA89A);

  // ════════════════════════════════════════════════════════
  // Border（边框层）
  // ════════════════════════════════════════════════════════

  /// 默认 1px 边框
  static const Color border = Color(0xFFDDE6D8);

  /// 内部行分隔
  static const Color borderSoft = Color(0xFFEAF0E7);

  // ════════════════════════════════════════════════════════
  // Accent（强调色 —— 每屏 ≤ 2 处可见使用）
  // ════════════════════════════════════════════════════════

  /// 竹绿：品牌主色（按钮/图标/Logo/发送键）（替换旧 #8BC34A）
  static const Color accent = Color(0xFF7CB342);

  /// 深竹：竹底上的文字、按下态、左边线（替换旧 #6B9E78）
  static const Color accentDeep = Color(0xFF4E7C2A);

  /// 选中/高亮底（chip、active tab）
  static const Color accentSoft = Color(0xFFE8F3DE);

  /// 暖金：音乐狗子能量色 + 用户气泡（替换旧 #FFD54F / orange）
  static const Color sun = Color(0xFFF2A33C);

  /// 暖区底
  static const Color sunSoft = Color(0xFFFCEBD2);

  /// 暖珊瑚：音乐动作色（录音/生成/播放），暖橙非粉
  static const Color ember = Color(0xFFFF7A45);

  /// 动作态底
  static const Color emberSoft = Color(0xFFFFE3D6);

  // ════════════════════════════════════════════════════════
  // Semantic（语义色 —— 全部非粉系）
  // ════════════════════════════════════════════════════════

  /// 成功/在线
  static const Color success = Color(0xFF4CAF50);

  /// 警告
  static const Color warn = Color(0xFFE0A106);

  /// 错误/挂断（暖红，非粉）
  static const Color danger = Color(0xFFC1463B);

  /// 信息（= accent）
  static const Color info = accent;

  // ════════════════════════════════════════════════════════
  // 消息气泡
  // ════════════════════════════════════════════════════════

  /// 用户消息气泡：暖金底（替换旧 #FFE8A8）
  static const Color userBubble = Color(0xFFFFF3E0);

  /// 竹笌消息气泡：淡绿底
  static const Color assistantBubble = Color(0xFFE8F5E9);

  // ════════════════════════════════════════════════════════
  // 暗色模式颜色（竹调深，非紫调 navy）
  // ════════════════════════════════════════════════════════

  /// 暗色模式背景：竹调深（替换旧紫调 #1A1A2E）
  static const Color darkBg = Color(0xFF0E1512);

  /// 暗色模式卡片（替换旧 #252540）
  static const Color darkCard = Color(0xFF16201B);

  /// 暗色模式暖区
  static const Color darkSurfaceWarm = Color(0xFF1E1A14);

  /// 暗色模式强调色（亮竹）
  static const Color darkAccent = Color(0xFF8BD14F);

  /// 暗色模式深竹
  static const Color darkAccentDeep = Color(0xFF5E9E2E);

  // ════════════════════════════════════════════════════════
  // 旧符号兼容别名（映射到新设计令牌，避免现有页面大量修改）
  // TODO: 逐步替换为新令牌名称后删除
  // ════════════════════════════════════════════════════════

  /// 旧：竹绿 → 新：accent
  static const Color bamboo = accent;

  /// 旧：深竹 → 新：accentDeep
  static const Color bambooDeep = accentDeep;

  /// 旧：纸白背景 → 新：bg
  static const Color paper = bg;

  /// 旧：主文本 → 新：fg
  static const Color softText = fg;

  /// 旧：次级文本 → 新：muted
  static const Color subText = muted;

  /// 旧：暖黄 → 新：sun
  static const Color warmYellow = sun;

  // ════════════════════════════════════════════════════════
  // 间距（4px 网格，禁止 5/7/13/15/22/30）
  // ════════════════════════════════════════════════════════

  static const double space1 = 4.0;
  static const double space2 = 8.0;
  static const double space3 = 12.0;
  static const double space4 = 16.0;
  static const double space5 = 20.0;
  static const double space6 = 24.0;
  static const double space8 = 32.0;
  static const double space10 = 40.0;
  static const double space12 = 48.0;
  static const double space16 = 64.0;
  static const double space20 = 80.0;

  /// 兼容旧命名
  static const double padding = space4;
  static const double paddingSm = space2;
  static const double paddingLg = space6;

  // ════════════════════════════════════════════════════════
  // 圆角（卡片上限 16px，禁止 ≥24 过度圆滑）
  // ════════════════════════════════════════════════════════

  /// 8：小组件/标签
  static const double radiusSm = 8.0;

  /// 12：卡片
  static const double radius = 12.0;

  /// 16：大卡片（上限）
  static const double radiusLg = 16.0;

  /// 20：气泡/主按钮
  static const double radiusXl = 20.0;

  /// 9999：胶囊
  static const double radiusPill = 9999.0;

  // ════════════════════════════════════════════════════════
  // 字体
  // ════════════════════════════════════════════════════════

  /// 显示字体（少年系短标题）：Smiley Sans, Inter, Noto Sans SC
  static const String fontDisplay = 'Smiley Sans';

  /// 正文字体：Inter, Noto Sans SC
  static const String fontBody = 'Inter';

  /// 等宽字体（歌词时间轴/波形标签）：JetBrains Mono
  static const String fontMono = 'JetBrains Mono';

  /// 字阶（8级）
  static const double textXs = 12.0;
  static const double textSm = 14.0;
  static const double textBase = 16.0;
  static const double textMd = 18.0;
  static const double textLg = 20.0;
  static const double textXl = 24.0;
  static const double text2xl = 32.0;
  static const double text3xl = 40.0;

  /// 兼容旧命名（字体大小）
  static const double fontTitle = textLg;
  static const double fontSizeBody = textBase;
  static const double fontCaption = textXs;

  // ════════════════════════════════════════════════════════
  // 动效（≤200ms，prefers-reduced-motion 关闭非必要动画）
  // ════════════════════════════════════════════════════════

  static const Duration motionFast = Duration(milliseconds: 150);
  static const Duration motionBase = Duration(milliseconds: 200);
  static const Duration motionPage = Duration(milliseconds: 320);

  // ════════════════════════════════════════════════════════
  // 主题数据
  // ════════════════════════════════════════════════════════

  /// 亮色主题（竹雾底 + 白卡，少年感阳光）
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.light,
      surface: surface,
      onSurface: fg,
    ),
    scaffoldBackgroundColor: bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: bg,
      foregroundColor: fg,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLg),
        side: BorderSide(color: border.withValues(alpha: 0.5), width: 0.5),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceSunken,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusXl),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusXl),
        borderSide: const BorderSide(color: accentDeep, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXl),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontSize: text3xl, fontWeight: FontWeight.w700, color: fg),
      displayMedium: TextStyle(fontSize: text2xl, fontWeight: FontWeight.w700, color: fg),
      headlineLarge: TextStyle(fontSize: textXl, fontWeight: FontWeight.w700, color: fg),
      headlineMedium: TextStyle(fontSize: textLg, fontWeight: FontWeight.w600, color: fg),
      titleLarge: TextStyle(fontSize: textMd, fontWeight: FontWeight.w600, color: fg),
      titleMedium: TextStyle(fontSize: textBase, fontWeight: FontWeight.w500, color: fg),
      bodyLarge: TextStyle(fontSize: textBase, color: fg),
      bodyMedium: TextStyle(fontSize: textSm, color: fg2),
      bodySmall: TextStyle(fontSize: textXs, color: muted),
      labelLarge: TextStyle(fontSize: textSm, fontWeight: FontWeight.w500, color: fg),
      labelMedium: TextStyle(fontSize: textXs, fontWeight: FontWeight.w500, color: muted),
    ),
  );

  /// 暗色主题（竹调深底，靠亮度递进表达层级，不靠阴影）
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: darkAccent,
      brightness: Brightness.dark,
      surface: darkCard,
      onSurface: const Color(0xFFE8F0E4),
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
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF0A0F0D),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusXl),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusXl),
        borderSide: const BorderSide(color: darkAccent, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: darkAccent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXl),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontSize: text3xl, fontWeight: FontWeight.w700, color: Color(0xFFE8F0E4)),
      displayMedium: TextStyle(fontSize: text2xl, fontWeight: FontWeight.w700, color: Color(0xFFE8F0E4)),
      headlineLarge: TextStyle(fontSize: textXl, fontWeight: FontWeight.w700, color: Color(0xFFE8F0E4)),
      headlineMedium: TextStyle(fontSize: textLg, fontWeight: FontWeight.w600, color: Color(0xFFE8F0E4)),
      titleLarge: TextStyle(fontSize: textMd, fontWeight: FontWeight.w600, color: Color(0xFFE8F0E4)),
      titleMedium: TextStyle(fontSize: textBase, fontWeight: FontWeight.w500, color: Color(0xFFE8F0E4)),
      bodyLarge: TextStyle(fontSize: textBase, color: Color(0xFFE8F0E4)),
      bodyMedium: TextStyle(fontSize: textSm, color: Color(0xFFB6C4AE)),
      bodySmall: TextStyle(fontSize: textXs, color: Color(0xFF859384)),
      labelLarge: TextStyle(fontSize: textSm, fontWeight: FontWeight.w500, color: Color(0xFFE8F0E4)),
      labelMedium: TextStyle(fontSize: textXs, fontWeight: FontWeight.w500, color: Color(0xFF859384)),
    ),
  );
}
