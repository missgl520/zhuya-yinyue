// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 设置 Sheet（底部弹出面板）
//
// 触发：聊天页顶栏 ⚙️ 按钮
// 关闭：下拉 Sheet / 点击遮罩层
//
// 菜单项（从上到下）：
//   1. 拖拽条（装饰横条，居中，灰色）
//   2. 关于竹笌
//   3. 声音设置
//   4. 语音设置
//   5. 模型设置
//
// 展开行为：点击菜单项 → 该项展开为详情面板，其他项收起
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../presentation/providers/app_providers.dart';

// 当前展开项（null = 全部收起）
final settingsExpandedProvider = StateProvider<String?>((ref) => null);

class SettingsSheet extends ConsumerWidget {
  const SettingsSheet({super.key});

  // 显示 Sheet 的入口方法（供外部调用）
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(settingsExpandedProvider);
    final isDark = ref.watch(themeProvider);

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
            _dragHandle,

            // ── 菜单项列表 ──
            _MenuItem(
              title: '关于竹笌',
              subtitle: '版本与介绍',
              icon: Icons.info_outline,
              expanded: expanded == 'about',
              onTap: () => _toggle(ref, 'about'),
              children: const _AboutContent(),
            ),

            _MenuDivider(isDark: isDark),

            _MenuItem(
              title: '声音设置',
              subtitle: '语音播报与音色',
              icon: Icons.volume_up_outlined,
              expanded: expanded == 'sound',
              onTap: () => _toggle(ref, 'sound'),
              children: const _SoundContent(),
            ),

            _MenuDivider(isDark: isDark),

            _MenuItem(
              title: '语音设置',
              subtitle: '识别引擎与唤醒词',
              icon: Icons.mic_outlined,
              expanded: expanded == 'voice',
              onTap: () => _toggle(ref, 'voice'),
              children: const _VoiceContent(),
            ),

            _MenuDivider(isDark: isDark),

            _MenuItem(
              title: '模型设置',
              subtitle: 'AI 模型来源',
              icon: Icons.smart_toy_outlined,
              expanded: expanded == 'model',
              onTap: () => _toggle(ref, 'model'),
              children: const _ModelContent(),
            ),

            _MenuDivider(isDark: isDark),

            _MenuItem(
              title: '隐私政策',
              subtitle: '查看隐私条款',
              icon: Icons.privacy_tip_outlined,
              expanded: false,
              onTap: () => context.push('/legal?type=privacy'),
              children: const SizedBox.shrink(),
            ),

            _MenuDivider(isDark: isDark),

            _MenuItem(
              title: '用户协议',
              subtitle: '查看用户协议',
              icon: Icons.description_outlined,
              expanded: false,
              onTap: () => context.push('/legal?type=terms'),
              children: const SizedBox.shrink(),
            ),

            _MenuDivider(isDark: isDark),

            _MenuItem(
              title: '个人信息收集清单',
              subtitle: '我们收集哪些信息',
              icon: Icons.list_alt_outlined,
              expanded: false,
              onTap: () => context.push('/info?type=pi-collection'),
              children: const SizedBox.shrink(),
            ),

            _MenuDivider(isDark: isDark),

            _MenuItem(
              title: '与第三方共享清单',
              subtitle: '信息共享给哪些服务商',
              icon: Icons.share_outlined,
              expanded: false,
              onTap: () => context.push('/info?type=third-party-sharing'),
              children: const SizedBox.shrink(),
            ),

            _MenuDivider(isDark: isDark),

            _MenuItem(
              title: '版本介绍',
              subtitle: '功能与版本历史',
              icon: Icons.new_releases_outlined,
              expanded: false,
              onTap: () => context.push('/info?type=version-intro'),
              children: const SizedBox.shrink(),
            ),

            // 底部安全距离
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _toggle(WidgetRef ref, String key) {
    final cur = ref.read(settingsExpandedProvider);
    ref.read(settingsExpandedProvider.notifier).state = cur == key ? null : key;
  }
}

// ── 拖拽条 ──
Widget get _dragHandle => Padding(
  padding: const EdgeInsets.only(top: 10, bottom: 6),
  child: Container(
    width: 36,
    height: 4,
    decoration: BoxDecoration(
      color: Colors.grey.shade300,
      borderRadius: BorderRadius.circular(2),
    ),
  ),
);

// ── 分隔线 ──
class _MenuDivider extends StatelessWidget {
  final bool isDark;
  const _MenuDivider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 20,
      endIndent: 20,
      color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
    );
  }
}

// ── 可展开菜单项 ──
class _MenuItem extends ConsumerWidget {
  final String title;
  final IconData? icon;
  final String? subtitle;
  final bool expanded;
  final VoidCallback onTap;
  final Widget children;

  const _MenuItem({
    required this.title,
    this.icon,
    this.subtitle,
    required this.expanded,
    required this.onTap,
    required this.children,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider);
    return Column(
      children: [
        InkWell(
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
                  Icon(icon, size: 20, color: AppTheme.bamboo),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
        ),
        // 展开内容
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: children,
          crossFadeState: expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),
      ],
    );
  }
}

// ── 关于竹笌 内容 ──
class _AboutContent extends StatelessWidget {
  const _AboutContent();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.bamboo.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.bamboo.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.eco,
                        color: AppTheme.bamboo,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '竹笌',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '版本 1.0.0',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  '竹笌是一个情感陪伴 AI，随时倾听你的心声。',
                  style: TextStyle(fontSize: 14, height: 1.6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 声音设置 内容 ──
class _SoundContent extends ConsumerWidget {
  const _SoundContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ttsEnabled = ref.watch(ttsEnabledProvider);
    final ttsMode = ref.watch(ttsModeProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Column(
        children: [
          // TTS 总开关
          _SwitchRow(
            title: '语音播报',
            subtitle: 'AI 回复自动朗读',
            value: ttsEnabled,
            onChanged: (v) {
              ref.read(ttsEnabledProvider.notifier).state = v;
              Hive.box('settings').put('ttsEnabled', v);
            },
          ),
          if (ttsEnabled) ...[
            const SizedBox(height: 12),
            // 音色选择
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '音色',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _ModeChip(
                          label: 'MiniMax 语音',
                          selected: ttsMode == 'minimax',
                          onTap: () {
                            ref.read(ttsModeProvider.notifier).state =
                                'minimax';
                            Hive.box('settings').put('ttsMode', 'minimax');
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ModeChip(
                          label: '🔊 系统 TTS',
                          selected: ttsMode == 'system',
                          onTap: () {
                            ref.read(ttsModeProvider.notifier).state = 'system';
                            Hive.box('settings').put('ttsMode', 'system');
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── 语音设置 内容 ──
class _VoiceContent extends StatelessWidget {
  const _VoiceContent();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Column(
        children: [
          _InfoRow(icon: Icons.mic, text: '语音识别引擎', value: '系统默认'),
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.record_voice_over,
            text: '唤醒词',
            value: BackendConfig.instance.wakeWord,
          ),
        ],
      ),
    );
  }
}

// ── 模型设置 内容 ──
// 支持：Agnes 国内版 / 国际版（预设）+ 自定义 API 链接模型
class _ModelContent extends ConsumerStatefulWidget {
  const _ModelContent();

  @override
  ConsumerState<_ModelContent> createState() => _ModelContentState();
}

class _ModelContentState extends ConsumerState<_ModelContent> {
  final _baseUrlCtrl = TextEditingController();
  final _apiKeyCtrl = TextEditingController();
  final _modelIdCtrl = TextEditingController();
  late String _source;
  String? _hint;
  bool _saving = false;

  static const _kSource = 'apiModelSource';
  static const _kBaseUrl = 'customApiBaseUrl';
  static const _kApiKey = 'customApiKey';
  static const _kModelId = 'customModelId';

  @override
  void initState() {
    super.initState();
    final box = Hive.box('settings');
    _source = box.get(_kSource, defaultValue: 'agnes-cn') as String;
    _baseUrlCtrl.text = box.get(_kBaseUrl, defaultValue: '') as String;
    _apiKeyCtrl.text = box.get(_kApiKey, defaultValue: '') as String;
    _modelIdCtrl.text = box.get(_kModelId, defaultValue: '') as String;
  }

  @override
  void dispose() {
    _baseUrlCtrl.dispose();
    _apiKeyCtrl.dispose();
    _modelIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _setSource(String source) async {
    if (source == 'agnes-intl' && _source == 'agnes-cn') {
      final ok = await _confirmCrossBorder(context);
      if (!ok) return;
      Hive.box('settings').put('agnesUseCNCrossBorderAck', true);
    }
    setState(() => _source = source);

    final box = Hive.box('settings');
    await box.put(_kSource, source);
    // 兼容旧 Provider
    final useCN = source == 'agnes-cn';
    box.put('agnesUseCN', useCN);
    ref.read(agnesServiceProvider).setUseCN(useCN);
  }

  Future<void> _saveCustomApi() async {
    final baseUrl = _baseUrlCtrl.text.trim();
    final modelId = _modelIdCtrl.text.trim();

    if (baseUrl.isEmpty || modelId.isEmpty) {
      setState(() => _hint = '请填写 API 地址与模型 ID');
      return;
    }
    if (!baseUrl.startsWith('http://') && !baseUrl.startsWith('https://')) {
      setState(() => _hint = 'API 地址需以 http:// 或 https:// 开头');
      return;
    }

    setState(() => _saving = true);
    final box = Hive.box('settings');
    await box.put(_kBaseUrl, baseUrl);
    await box.put(_kApiKey, _apiKeyCtrl.text.trim());
    await box.put(_kModelId, modelId);
    await box.put(_kSource, 'custom');
    setState(() {
      _source = 'custom';
      _saving = false;
      _hint = '自定义 API 已保存 ✓';
    });
    box.put('agnesUseCN', false);
    ref.read(agnesServiceProvider).setUseCN(false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '添加 API 链接模型',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ModeChip(
                  label: '🇨🇳 国内版',
                  selected: _source == 'agnes-cn',
                  onTap: () => _setSource('agnes-cn'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ModeChip(
                  label: '🌐 国际版',
                  selected: _source == 'agnes-intl',
                  onTap: () => _setSource('agnes-intl'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ModeChip(
                  label: '🔗 自定义',
                  selected: _source == 'custom',
                  onTap: () => _setSource('custom'),
                ),
              ),
            ],
          ),
          if (_source == 'agnes-intl') _buildCrossBorderBanner(),
          if (_source == 'custom') ...[
            const SizedBox(height: 16),
            TextField(
              controller: _baseUrlCtrl,
              decoration: const InputDecoration(
                labelText: 'API 地址',
                hintText: '例如 https://api.agnes-ai.cn/v1',
                border: OutlineInputBorder(),
                isDense: true,
                prefixIcon: Icon(Icons.link, size: 18),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _apiKeyCtrl,
              decoration: const InputDecoration(
                labelText: 'API 密钥',
                hintText: 'sk-...',
                border: OutlineInputBorder(),
                isDense: true,
                prefixIcon: Icon(Icons.key, size: 18),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _modelIdCtrl,
              decoration: const InputDecoration(
                labelText: '模型 ID',
                hintText: '例如 agnes-2.0-flash',
                border: OutlineInputBorder(),
                isDense: true,
                prefixIcon: Icon(Icons.memory, size: 18),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _saveCustomApi,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save, size: 18),
                    label: const Text('保存 API 链接'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.bamboo,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (_hint != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                _hint!,
                style: TextStyle(
                  fontSize: 12,
                  color: _hint!.contains('✓')
                      ? AppTheme.bamboo
                      : Colors.red.shade600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCrossBorderBanner() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.warmYellow.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppTheme.warmYellow.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.warning_amber_outlined,
            color: Color(0xFFB5811F),
            size: 18,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '国际版模型部署在境外，对话内容将被传输至境外处理。',
              style: TextStyle(fontSize: 12, color: Color(0xFF8A6D1B)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 开关行 ──
class _SwitchRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          // ignore: deprecated_member_use
          activeColor: AppTheme.bamboo,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

// ── 信息行 ──
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final String value;

  const _InfoRow({required this.icon, required this.text, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 13)),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 13, color: Colors.grey)),
      ],
    );
  }
}

// ── 选择标签 ──
class _ModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.bamboo.withValues(alpha: 0.15)
              : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppTheme.bamboo : Colors.transparent,
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              color: selected ? AppTheme.bamboo : Colors.grey.shade700,
            ),
          ),
        ),
      ),
    );
  }
}

/// 切换到「国际版」模型前的跨境数据传输风险提示与确认。
/// 返回 true 表示用户已明确同意，false 表示取消。
Future<bool> _confirmCrossBorder(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('切换到国际版'),
      content: const Text(
        '国际版模型服务部署在境外，切换后您的对话内容等个人信息将被传输至境外处理。'
        '根据《个人信息保护法》，数据出境需您单独明确同意。\n\n'
        '如仅在国内使用，建议保持「国内版」。是否仍要切换？',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('保持国内版'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('仍要切换（同意出境）'),
        ),
      ],
    ),
  );
  return result == true;
}
