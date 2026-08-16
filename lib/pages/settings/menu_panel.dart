// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 菜单页面（底部弹出面板）
//
// 触发：聊天页顶栏 Logo 点击
// 关闭：点击遮罩 / 上滑
//
// 职责（对照 Soul of Waifu / 成熟产品）：
//   账户管理 / Live2D 模型选择 / 记忆管理 / 角色设定 / 唤醒词设置
//
// 入口分工（对照 zhuyapp-design-2.0.md）：
//   菜单页 ← Logo（账户、模型、记忆、唤醒词、角色）
//   设置 Sheet ← ⚙️（声音、语音、模型切换、版本信息）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/services/backend_service.dart';
import '../../presentation/providers/app_providers.dart';
import '../voice/voice_call_page.dart';

class MenuPanel extends ConsumerStatefulWidget {
  const MenuPanel({super.key});

  @override
  ConsumerState<MenuPanel> createState() => _MenuPanelState();

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const MenuPanel(),
    );
  }
}

class _MenuPanelState extends ConsumerState<MenuPanel> {
  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);
    final affinity = ref.watch(affinityProvider);
    final currentEmotion = ref.watch(currentEmotionProvider);

    final rawPersona = Hive.box('settings').get('persona', defaultValue: '少年感 · 阳光 · 直接') as String;
    final personaSubtitle = rawPersona.length > 16 ? '${rawPersona.substring(0, 16)}…' : rawPersona;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── 拖拽条 ──
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 6),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── 竹笌头像 + 关系状态 ──
            _RelationshipBanner(
              affinity: affinity,
              currentEmotion: currentEmotion?.emotion ?? 'neutral',
            ),

            const Divider(height: 1, indent: 20, endIndent: 20),

            // ── 角色分组 ──
            const _SectionLabel('角色'),

            // ── Live2D 模型选择 ──
            _MenuTile(
              icon: Icons.pets,
              title: 'Live2D 模型',
              subtitle: '选择竹笌的虚拟形象',
              onTap: () => _showModelPicker(context),
            ),

            // ── 角色设定（可编辑） ──
            _MenuTile(
              icon: Icons.person_outline,
              title: '角色设定',
              subtitle: personaSubtitle,
              onTap: () => _showPersonaEditor(context),
            ),

            // ── 唤醒词设置 ──
            _MenuTile(
              icon: Icons.record_voice_over,
              title: '唤醒词',
              subtitle: '设置专属唤醒词',
              onTap: () => _showWakeWordEditor(context),
            ),

            // ── 互动分组 ──
            const _SectionLabel('互动'),

            // ── 实时语音通话 ──
            _MenuTile(
              icon: Icons.phone_in_talk,
              title: '语音通话',
              subtitle: '实时语音对话',
              onTap: () {
                Navigator.of(context).pop();
                VoiceCallPage.show(context);
              },
            ),

            // ── 记忆管理 ──
            _MenuTile(
              icon: Icons.psychology_outlined,
              title: '记忆管理',
              subtitle: affinity.totalInteractions > 0
                  ? '累计 ${affinity.totalInteractions} 轮对话'
                  : '暂无对话记忆',
              badge: affinity.level != '陌生人' ? affinity.level : null,
              onTap: () => _showMemoryManager(context, ref),
            ),

            // ── 好感度详情 ──
            _AffinityPanel(affinity: affinity),

            // ── 连接分组 ──
            const _SectionLabel('连接'),

            // ── 后端地址 ──
            _MenuTile(
              title: '后端地址',
              subtitle: '管理后端连接',
              onTap: () => _showBackendUrlEditor(context),
            ),

            // 底部安全距离
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showModelPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _Live2DModelPickerDialog(),
    );
  }

  void _showWakeWordEditor(BuildContext context) {
    final controller = TextEditingController(text: BackendConfig.instance.wakeWord);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.record_voice_over, color: AppTheme.bamboo, size: 20),
            SizedBox(width: 8),
            Text('唤醒词'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '说出唤醒词，竹笌就会回应你。',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: '唤醒词',
                hintText: '例如：竹笌竹笌',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              maxLength: 20,
              textInputAction: TextInputAction.done,
              onSubmitted: (v) => _saveWakeWord(ctx, controller.text, ctx),
            ),
            const SizedBox(height: 4),
            Text(
              '2-20字，中英文均可',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => _saveWakeWord(ctx, controller.text, context),
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _saveWakeWord(BuildContext dialogContext, String word, BuildContext scaffoldContext) {
    final trimmed = word.trim();
    if (trimmed.isEmpty) return;
    // 存本地
    BackendConfig.instance.setWakeWord(trimmed);
    // 同步后端
    BackendService.instance.syncWakeWord(trimmed);
    // 关闭弹窗
    Navigator.pop(dialogContext);
    // 刷新菜单 UI
    setState(() {});
    ScaffoldMessenger.of(scaffoldContext).showSnackBar(
      SnackBar(
        content: Text('唤醒词已保存为：$trimmed'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showBackendUrlEditor(BuildContext context) {
    final controller = TextEditingController(text: BackendConfig.instance.baseUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cloud_outlined, color: AppTheme.bamboo, size: 20),
            SizedBox(width: 8),
            Text('后端地址'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '竹笌需要连接到后端才能聊天、记忆与同步。填写后端服务地址（http/https）。',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: '后端地址',
                hintText: '例如 http://192.168.1.100:8000',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              onSubmitted: (v) => _saveBackendUrl(ctx, controller.text, context),
            ),
            const SizedBox(height: 4),
            const Text(
              '本机调试：电脑运行后端后用局域网 IP；安卓模拟器用 http://10.0.2.2:8000。'
              '部署到云服务器后填公网域名，如 http://你的域名:8000（公网建议用 https）。',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => _saveBackendUrl(ctx, controller.text, context),
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveBackendUrl(
    BuildContext dialogContext,
    String url,
    BuildContext scaffoldContext,
  ) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    // 提前捕获 messenger，避免跨 await 使用 BuildContext
    final messenger = ScaffoldMessenger.of(scaffoldContext);
    try {
      BackendService.instance.setBackendUrl(trimmed);
    } catch (_) {
      Navigator.pop(dialogContext);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('地址格式不正确：需以 http:// 或 https:// 开头'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Navigator.pop(dialogContext);
    setState(() {});
    if (!mounted) return;
    messenger.showSnackBar(
      const SnackBar(
        content: Text('后端地址已保存'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    // 探测连通性，给出明确反馈
    final ok = await BackendService.instance.healthCheck();
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(ok
            ? '已成功连接后端 ✅'
            : '已保存，但暂时连不上后端（请确认后端已启动、地址与端口正确）'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showPersonaEditor(BuildContext context) {
    final box = Hive.box('settings');
    final controller = TextEditingController(
      text: box.get('persona', defaultValue: '少年感 · 阳光 · 直接') as String,
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.person_outline, color: AppTheme.bamboo, size: 20),
            SizedBox(width: 8),
            Text('角色设定'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '定义竹笌的性格与说话风格，保存后将在下次对话生效。',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 4,
              maxLength: 200,
              decoration: const InputDecoration(
                hintText: '例如：少年感、阳光、直接、爱用 emoji',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              box.put('persona', controller.text.trim());
              Navigator.pop(ctx);
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('角色设定已保存'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showMemoryManager(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.psychology, color: AppTheme.bamboo, size: 20),
            const SizedBox(width: 8),
            const Text('记忆管理'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.list, size: 20),
              title: const Text('查看对话记忆'),
              onTap: () async {
                Navigator.pop(context);
                context.push('/memory-history');
              },
            ),
            ListTile(
              leading: const Icon(Icons.summarize, size: 20),
              title: const Text('查看对话摘要'),
              onTap: () async {
                Navigator.pop(context);
                final summaries = await ref.read(backendServiceProvider).getSummaries();
                if (context.mounted) {
                  _showSummaries(context, summaries);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
              title: const Text('清空对话记忆', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                _confirmClearMemory(context, ref);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _showSummaries(BuildContext context, List<Map<String, dynamic>> summaries) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('对话摘要'),
        content: SizedBox(
          width: double.maxFinite,
          child: summaries.isEmpty
              ? const Text('暂无摘要，对话够长会自动生成。')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: summaries.length,
                  itemBuilder: (_, i) {
                    final s = summaries[i];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s['created_at']?.toString().substring(0, 10) ?? '',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                            const SizedBox(height: 4),
                            Text(s['summary'] ?? '', style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _confirmClearMemory(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('确认清空记忆？'),
        content: const Text(
          '清空后竹笌会忘记所有对话历史。\n此操作不可恢复。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final ok = await ref.read(backendServiceProvider).clearMemory();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(ok ? '记忆已清空' : '清空失败')),
                );
              }
            },
            child: const Text('确认清空', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ── 关系状态横幅 ──
class _RelationshipBanner extends StatelessWidget {
  final AffinityData affinity;
  final String currentEmotion;

  const _RelationshipBanner({
    required this.affinity,
    required this.currentEmotion,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.bamboo.withValues(alpha: 0.15),
            AppTheme.warmYellow.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          // 竹笌头像（立体吉祥物图标）
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppTheme.bamboo.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Image.asset(
                  'assets/logo_mascot.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      '竹笌',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.bamboo.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        affinity.level,
                        style: const TextStyle(fontSize: 12, color: AppTheme.bamboo),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  affinity.streakDays > 0
                      ? '🔥 ${affinity.streakDays} 天连续 · ${_levelDescription(affinity.level)}'
                      : _levelDescription(affinity.level),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          // 好感度环形进度
          _AffinityRing(affinity: affinity),
        ],
      ),
    );
  }

  String _levelDescription(String level) {
    return switch (level) {
      '灵魂伴侣' => '彼此理解，心有灵犀',
      '知己' => '懂你心思，默契十足',
      '好友' => '相处融洽，互相关心',
      '朋友' => '开始熟悉，愿意倾听',
      '认识' => '初次相识，还在了解',
      _ => '我们刚认识，可以随便聊聊',
    };
  }
}

/// 好感度环形进度（整体好感 = 信任/亲密/熟悉 均值）
class _AffinityRing extends StatelessWidget {
  final AffinityData affinity;

  const _AffinityRing({required this.affinity});

  @override
  Widget build(BuildContext context) {
    final avg = (affinity.trust + affinity.intimacy + affinity.familiarity) / 3;
    final pct = (avg / 100).clamp(0.0, 1.0);
    return SizedBox(
      width: 46,
      height: 46,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: pct,
            strokeWidth: 4,
            backgroundColor: Colors.grey.withValues(alpha: 0.2),
            color: AppTheme.bambooDeep,
            strokeCap: StrokeCap.round,
          ),
          Text(
            '${avg.toInt()}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.bambooDeep,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 好感度详情面板 ──
class _AffinityPanel extends StatelessWidget {
  final AffinityData affinity;

  const _AffinityPanel({required this.affinity});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              '关系状态',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey),
            ),
          ),
          _AffinityBar(label: '信任', value: affinity.trust, max: 100),
          const SizedBox(height: 6),
          _AffinityBar(label: '亲密', value: affinity.intimacy, max: 100),
          const SizedBox(height: 6),
          _AffinityBar(label: '熟悉', value: affinity.familiarity, max: 100),
        ],
      ),
    );
  }
}

class _AffinityBar extends StatelessWidget {
  final String label;
  final double value;
  final double max;

  const _AffinityBar({required this.label, required this.value, required this.max});

  @override
  Widget build(BuildContext context) {
    final pct = (value / max).clamp(0.0, 1.0);
    return Row(
      children: [
        SizedBox(
          width: 32,
          child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ),
        Expanded(
          child: Container(
            height: 6,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: pct,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.bamboo,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 32,
          child: Text(
            '${value.toInt()}/$max',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ),
      ],
    );
  }
}

// ── 通用菜单项 ──
class _MenuTile extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String subtitle;
  final String? badge;
  final void Function()? onTap;

  const _MenuTile({
    this.icon,
    required this.title,
    required this.subtitle,
    this.badge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(
            color: Colors.grey.withValues(alpha: 0.2),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 22, color: AppTheme.bamboo),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: onTap == null ? Colors.grey : null,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppTheme.warmYellow.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            badge!,
                            style: const TextStyle(fontSize: 11, color: Colors.orange),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Live2D 模型选择器弹窗
//
// 逻辑：
//   Step 1 → 扫描本地 .model3.json 文件（file_picker）
//   Step 2a → 找到模型 → 列出供选择 → 加载
//   Step 2b → 没找到 → 询问是否去官网下载
//             → 是 → 跳转 live2d.com/sample
//             → 否 → 关闭弹窗
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _Live2DModelPickerDialog extends ConsumerStatefulWidget {
  const _Live2DModelPickerDialog();

  @override
  ConsumerState<_Live2DModelPickerDialog> createState() =>
      _Live2DModelPickerDialogState();
}

class _Live2DModelPickerDialogState
    extends ConsumerState<_Live2DModelPickerDialog> {
  /// 扫描到的本地模型列表
  /// 每个元素：模型所在文件夹路径
  List<String> _localModels = [];

  /// 当前选中索引（-1 = 未选）
  int _selectedIndex = -1;

  /// 加载状态
  bool _loading = false;

  /// 错误信息
  String? _error;

  /// Step 1：扫描本地模型文件
  Future<void> _scanLocalModels() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 打开目录选择器（仅限目录）
      final result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择 Live2D 模型文件夹',
      );

      if (result == null) {
        // 用户取消 → 保持当前状态
        setState(() => _loading = false);
        return;
      }

      // 在选定目录中递归查找 .model3.json
      final dir = Directory(result);
      final allEntries = await dir.list(recursive: true, followLinks: false).toList();
      final entries = allEntries
          .whereType<File>()
          .where((e) => e.path.endsWith('.model3.json'))
          .map((e) => e.parent.path)
          .toSet()
          .toList();

      if (!mounted) return;
      setState(() {
        _localModels = entries;
        _selectedIndex = entries.isNotEmpty ? 0 : -1;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '扫描失败：$e';
        _loading = false;
      });
    }
  }

  /// Step 2：确认加载选中模型
  Future<void> _loadSelectedModel() async {
    if (_selectedIndex < 0 || _selectedIndex >= _localModels.length) return;

    setState(() => _loading = true);

    final modelPath = _localModels[_selectedIndex];
    final modelFileName = Directory(modelPath)
        .listSync()
        .where((e) => e.path.endsWith('.model3.json'))
        .firstOrNull
        ?.path
        .split('/')
        .last;

    if (modelFileName == null) {
      if (mounted) {
        setState(() {
          _error = '未找到 .model3.json 文件';
          _loading = false;
        });
      }
      return;
    }

    try {
      // 通知 Controller 切换模型
      await ref.read(live2dControllerProvider).loadExternalModel(
            modelPath,
            modelFileName,
          );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('模型已切换：${_getModelName(modelPath)}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '加载失败：$e';
          _loading = false;
        });
      }
    }
  }

  /// 从路径提取模型名称（文件夹名）
  String _getModelName(String path) {
    // pathSeparator 是 /，在 Android 上也一样
    return path.split('/').last;
  }

  /// 打开 Live2D 官方示例下载页
  Future<void> _openLive2DWebsite() async {
    final uri = Uri.parse('https://www.live2d.com/en/learn/sample/');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // 兜底：若系统无法打开外部浏览器，复制链接
      await Clipboard.setData(const ClipboardData(text: 'https://www.live2d.com/en/learn/sample/'));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('无法唤起浏览器，链接已复制到剪贴板'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    // 弹窗打开后自动唤起文件夹选择器，引导用户一步完成「打开文件夹并搜索模型」
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scanLocalModels();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.pets, color: AppTheme.bamboo, size: 20),
          SizedBox(width: 8),
          Text('Live2D 模型'),
        ],
      ),
      content: SizedBox(
        width: 320,
        child: _buildContent(),
      ),
      actions: _buildActions(),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade300, size: 40),
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: Colors.red.shade600, fontSize: 13)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _scanLocalModels,
            child: const Text('重新选择'),
          ),
        ],
      );
    }

    if (_localModels.isEmpty) {
      // Step 2b：未找到模型，引导用户打开文件夹搜索或去官网下载
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_open_outlined, color: Colors.grey.shade400, size: 48),
          const SizedBox(height: 12),
          const Text(
            '未找到 Live2D 模型文件',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 6),
          Text(
            '点击「打开文件夹」选择一个包含 .model3.json 的目录，\n竹笌会自动搜索可用模型',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _scanLocalModels,
            icon: const Icon(Icons.folder_open, size: 16),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.bamboo,
              foregroundColor: Colors.white,
            ),
            label: const Text('打开文件夹'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _openLive2DWebsite,
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('去 Live2D 官网下载'),
          ),
        ],
      );
    }

    // Step 2a：显示找到的模型列表
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '选择要使用的 Live2D 模型',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 10),
        ...List.generate(_localModels.length, (i) {
          final name = _getModelName(_localModels[i]);
          final selected = _selectedIndex == i;
          return ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            leading: Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              color: selected ? AppTheme.bamboo : Colors.grey,
              size: 20,
            ),
            title: Text(
              name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            subtitle: Text(
              _localModels[i],
              style: const TextStyle(fontSize: 10),
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => setState(() => _selectedIndex = i),
          );
        }),
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: _scanLocalModels,
          icon: const Icon(Icons.folder_open, size: 16),
          label: const Text('重新选择文件夹'),
        ),
      ],
    );
  }

  List<Widget> _buildActions() {
    if (_loading) return [];

    if (_localModels.isEmpty) {
      return [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ];
    }

    return [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: _selectedIndex >= 0 ? _loadSelectedModel : null,
        child: const Text('加载'),
      ),
    ];
  }
}

/// 分组标题（角色 / 互动）
class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade500,
          letterSpacing: 1,
        ),
      ),
    );
  }
}