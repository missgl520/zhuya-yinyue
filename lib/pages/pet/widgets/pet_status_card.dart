// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 宠物状态面板（能量/羁绊/饥饿/快乐进度条 + 经验条）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/app_icon.dart';

/// 单条状态进度条
class PetStatBar extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final AppIconName icon;

  const PetStatBar({super.key, required this.label, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      AppIcon(name: icon, size: AppIconSize.xs, color: color),
      const SizedBox(width: AppTheme.space2),
      SizedBox(width: 40, child: Text(label, style: TextStyle(fontSize: AppTheme.textXs, color: AppTheme.muted))),
      Expanded(child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        child: LinearProgressIndicator(value: value.clamp(0, 100) / 100, backgroundColor: AppTheme.surfaceSunken, valueColor: AlwaysStoppedAnimation<Color>(color), minHeight: 8),
      )),
      const SizedBox(width: AppTheme.space2),
      SizedBox(width: 36, child: Text('${value.toInt()}', style: TextStyle(fontSize: AppTheme.textXs, color: AppTheme.fg2), textAlign: TextAlign.right)),
    ]);
  }
}

/// 经验条
class PetExpBar extends StatelessWidget {
  final int exp; final int level;
  const PetExpBar({super.key, required this.exp, required this.level});
  @override
  Widget build(BuildContext context) {
    final need = level * 100;
    return Row(children: [
      const AppIcon(name: AppIconName.star, size: AppIconSize.xs, color: AppTheme.sun),
      const SizedBox(width: AppTheme.space2),
      const SizedBox(width: 40, child: Text('经验', style: TextStyle(fontSize: AppTheme.textXs, color: AppTheme.muted))),
      Expanded(child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        child: LinearProgressIndicator(value: (exp % need) / need, backgroundColor: AppTheme.surfaceSunken, valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.sun), minHeight: 8),
      )),
      const SizedBox(width: AppTheme.space2),
      SizedBox(width: 50, child: Text('$exp/$need', style: TextStyle(fontSize: AppTheme.textXs, color: AppTheme.fg2), textAlign: TextAlign.right)),
    ]);
  }
}

/// 宠物状态面板卡片
class PetStatusCard extends StatelessWidget {
  final Map<String, dynamic> petState;
  const PetStatusCard({super.key, required this.petState});
  @override
  Widget build(BuildContext context) {
    final stats = [
      ('能量', (petState['energy'] ?? 0).toDouble(), AppTheme.accent, AppIconName.zap),
      ('羁绊', (petState['bond'] ?? 0).toDouble(), AppTheme.sun, AppIconName.heart),
      ('饥饿', (petState['hunger'] ?? 0).toDouble(), AppTheme.ember, AppIconName.disc),
      ('快乐', (petState['happiness'] ?? 0).toDouble(), AppTheme.success, AppIconName.smile),
    ];
    return Container(
      padding: const EdgeInsets.all(AppTheme.space4),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('状态', style: TextStyle(fontSize: AppTheme.textMd, fontWeight: FontWeight.w600, color: AppTheme.fg)),
        const SizedBox(height: AppTheme.space3),
        ...stats.map((s) => Padding(padding: const EdgeInsets.only(bottom: AppTheme.space3), child: PetStatBar(label: s.$1, value: s.$2, color: s.$3, icon: s.$4))),
        PetExpBar(exp: (petState['exp'] ?? 0).toInt(), level: (petState['level'] ?? 1).toInt()),
      ]),
    );
  }
}
