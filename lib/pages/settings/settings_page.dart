// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 设置页（Settings Page）
//
// 从首页入口5进入，承载所有设置项：
//   - 声音设置（音量/语速/音色）
//   - 语音设置（语音唤醒/ASR）
//   - 模型设置（AI 模型选择）
//   - 版本信息
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/theme/app_theme.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SettingsSection(
            title: '声音',
            children: [
              _SettingsTile(
                icon: Icons.volume_up,
                label: '音量',
                subtitle: '调整 AI 语音输出音量',
                onTap: () => _showComingSoon(context),
              ),
              _SettingsTile(
                icon: Icons.speed,
                label: '语速',
                subtitle: '调整 AI 语音播报速度',
                onTap: () => _showComingSoon(context),
              ),
              _SettingsTile(
                icon: Icons.record_voice_over,
                label: '音色',
                subtitle: '选择 AI 语音音色',
                onTap: () => _showComingSoon(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            title: '语音',
            children: [
              _SettingsTile(
                icon: Icons.mic,
                label: '语音唤醒',
                subtitle: '开启后可用语音唤醒 AI',
                onTap: () => _showComingSoon(context),
              ),
              _SettingsTile(
                icon: Icons.keyboard_voice,
                label: '语音识别',
                subtitle: '选择语音识别引擎',
                onTap: () => _showComingSoon(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            title: '模型',
            children: [
              _SettingsTile(
                icon: Icons.smart_toy,
                label: 'AI 模型',
                subtitle: '选择对话使用的 AI 模型',
                onTap: () => _showComingSoon(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            title: '其他',
            children: [
              _SettingsTile(
                icon: Icons.info_outline,
                label: '版本信息',
                subtitle: 'v1.0.0+1',
                onTap: () => context.push('/info'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('功能开发中，敬请期待'), duration: Duration(seconds: 2)),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.bamboo,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(
              color: AppTheme.bamboo.withValues(alpha: 0.15),
              width: 0.5,
            ),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      leading: Icon(icon, color: AppTheme.bamboo, size: 22),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white : AppTheme.softText,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : AppTheme.subText),
      ),
      trailing: Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
      onTap: onTap,
    );
  }
}
