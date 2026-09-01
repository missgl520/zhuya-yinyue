// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 音乐创作入口面板（生成音乐/歌词库/歌曲库）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/app_icon.dart';

/// 单条音乐入口
class PetMusicEntry extends StatelessWidget {
  final String title;
  final String subtitle;
  final AppIconName icon;
  final Color color;
  final VoidCallback? onTap;

  const PetMusicEntry({super.key, required this.title, required this.subtitle, required this.icon, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.space3, vertical: AppTheme.space2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(children: [
          AppIcon(name: icon, size: AppIconSize.sm, color: color),
          const SizedBox(width: AppTheme.space3),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: AppTheme.textSm, fontWeight: FontWeight.w500, color: AppTheme.fg)),
            Text(subtitle, style: TextStyle(fontSize: AppTheme.textXs, color: AppTheme.muted)),
          ])),
          Icon(Icons.chevron_right, size: 18, color: AppTheme.muted),
        ]),
      ),
    );
  }
}

/// 音乐创作面板卡片
class PetMusicCard extends StatelessWidget {
  final void Function(String route) onTap;

  const PetMusicCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.space4),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('音乐创作', style: TextStyle(fontSize: AppTheme.textMd, fontWeight: FontWeight.w600, color: AppTheme.fg)),
        const SizedBox(height: AppTheme.space3),
        PetMusicEntry(title: '生成音乐', subtitle: 'AI 创作专属音乐', icon: AppIconName.music, color: AppTheme.accent, onTap: () => onTap('/pet/music')),
        const SizedBox(height: AppTheme.space2),
        PetMusicEntry(title: '歌词库', subtitle: '查看已保存歌词', icon: AppIconName.fileText, color: AppTheme.sun, onTap: () => onTap('/pet/library?tab=lyrics')),
        const SizedBox(height: AppTheme.space2),
        PetMusicEntry(title: '歌曲库', subtitle: '查看已生成歌曲', icon: AppIconName.disc, color: AppTheme.ember, onTap: () => onTap('/pet/library?tab=songs')),
      ]),
    );
  }
}
