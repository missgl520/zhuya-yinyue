// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 音乐狗子主页（PetPage）
//
// 位于：pages/pet/pet_page.dart
// 路由：/pet
//
// 功能：
//   1. 展示音乐狗子当前状态（情绪/能量/羁绊/饥饿/快乐/等级）
//   2. 交互按钮（喂食/玩耍/抚摸/对话/睡觉）
//   3. 音乐创作入口（生成音乐 / 歌词库 / 歌曲库）
//
// 设计规范（P0 红线）：
//   - 使用 AppTheme 设计令牌（竹雾底 / 竹绿强调 / 暖金能量）
//   - 使用 AppIcon 门面（禁止 Icons.* / CupertinoIcons.* / emoji）
//   - 卡片圆角上限 16px，间距 4px 网格
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/backend_service.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/vrm_avatar_view.dart';

/// 音乐狗子主页
class PetPage extends StatefulWidget {
  const PetPage({super.key});

  @override
  State<PetPage> createState() => _PetPageState();
}

class _PetPageState extends State<PetPage> with TickerProviderStateMixin {
  Map<String, dynamic> _petState = {};

  // 音乐播放器状态
  bool _isPlaying = false;
  double _progress = 0.0; // 0.0 ~ 1.0
  final int _totalSeconds = 180; // 模拟3分钟
  Timer? _progressTimer;
  late AnimationController _rotateController;

  // 当前播放歌曲（模拟数据）
  final String _currentSong = '竹语·声场';
  final String _currentArtist = '音乐狗子';

  // 交互反馈状态
  String? _feedbackText;
  Color? _feedbackColor;
  String? _pressedAction;

  // 宠物浮动动画
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;

  // 宠物全页面无规则运动
  late AnimationController _moveController;
  late Animation<Alignment> _moveAnimation;
  Alignment _petAlignment = Alignment.topCenter;
  final Random _random = Random();

  void _startRandomMove() {
    // Alignment: x=-1最左, x=1最右, y=-1最上, y=1最下
    // 几乎全屏范围，小狗可以跑到屏幕边缘
    final targetX = (_random.nextDouble() * 2 - 1) * 0.95;
    final targetY = (_random.nextDouble() * 2 - 1) * 0.95;
    final target = Alignment(targetX, targetY);
    _moveAnimation = AlignmentTween(
      begin: _petAlignment,
      end: target,
    ).animate(CurvedAnimation(
      parent: _moveController,
      curve: Curves.easeInOutCubic,
    ));
    _petAlignment = target;
    _moveController.forward(from: 0);
  }

  // 交互反馈配置
  static const Map<String, Map<String, dynamic>> _actionFeedback = {
    'feed': {'text': '好吃！汪汪~', 'color': AppTheme.sun, 'icon': AppIconName.disc},
    'play': {'text': '好开心！再玩一次！', 'color': AppTheme.accent, 'icon': AppIconName.sparkles},
    'pet': {'text': '呼噜呼噜~', 'color': AppTheme.ember, 'icon': AppIconName.heart},
    'talk': {'text': '想和你聊天！', 'color': AppTheme.info, 'icon': AppIconName.messageCircle},
    'sleep': {'text': '晚安...zzZ', 'color': AppTheme.muted, 'icon': AppIconName.moon},
  };

  @override
  void initState() {
    super.initState();
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );
    // 宠物上下浮动动画
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _floatAnimation = Tween<double>(begin: 0, end: 12).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
    _floatController.repeat(reverse: true);

    // 宠物全页面无规则运动
    _moveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _startRandomMove();
    _moveController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _startRandomMove();
      }
    });
    // 先显示默认状态，后台异步刷新（避免后端不可达时长时间白屏）
    _petState = _defaultPetState();
    _loadState();
  }

  Map<String, dynamic> _defaultPetState() => {
    'mood': 'neutral',
    'energy': 80.0,
    'bond': 10.0,
    'hunger': 30.0,
    'happiness': 60.0,
    'level': 1,
    'exp': 0,
    'total_interactions': 0,
  };

  @override
  void dispose() {
    _progressTimer?.cancel();
    _rotateController.dispose();
    _floatController.dispose();
    _moveController.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    try {
      final state = await BackendService.instance.getPetState().timeout(
        const Duration(seconds: 3),
        onTimeout: () => {},
      );
      if (state.isNotEmpty && mounted) {
        setState(() => _petState = state);
      }
    } catch (_) {
      // 后端不可达时静默降级，保持默认状态显示
    }
  }

  Future<void> _interact(String action) async {
    // 显示按下状态
    setState(() => _pressedAction = action);
    await Future.delayed(const Duration(milliseconds: 150));
    setState(() => _pressedAction = null);

    // 对话按钮：先增加好感度，再跳转到聊天页
    if (action == 'talk') {
      _showFeedback(action);
      try {
        await BackendService.instance.petInteract(action).timeout(
          const Duration(seconds: 3),
          onTimeout: () => {},
        );
      } catch (_) {}
      if (mounted) context.go('/chat');
      return;
    }

    // 其他交互：调用后端 + 显示反馈
    _showFeedback(action);
    try {
      final state = await BackendService.instance.petInteract(action).timeout(
        const Duration(seconds: 3),
        onTimeout: () => {},
      );
      if (state.isNotEmpty && mounted) {
        setState(() => _petState = state);
      }
    } catch (_) {
      // 后端不可达时静默降级
    }
  }

  void _showFeedback(String action) {
    final fb = _actionFeedback[action];
    if (fb == null) return;
    setState(() {
      _feedbackText = fb['text'] as String;
      _feedbackColor = fb['color'] as Color;
    });
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _feedbackText = null);
    });
  }

  // ════════════════════════════════════════════════════════
  // 音乐播放器控制
  // ════════════════════════════════════════════════════════

  void _togglePlay() {
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        _rotateController.repeat();
        _startProgressTimer();
      } else {
        _rotateController.stop();
        _stopProgressTimer();
      }
    });
  }

  void _nextSong() {
    setState(() {
      _progress = 0.0;
      // 模拟切换歌曲
    });
  }

  void _prevSong() {
    setState(() {
      _progress = 0.0;
    });
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _progress += 1 / _totalSeconds;
        if (_progress >= 1.0) {
          _progress = 0.0;
          _nextSong();
        }
      });
    });
  }

  void _stopProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  String _formatTime(double progress) {
    final total = (progress * _totalSeconds).toInt();
    final min = total ~/ 60;
    final sec = total % 60;
    return '$min:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        elevation: 0,
        title: const Text('音乐狗子', style: TextStyle(color: AppTheme.fg, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: const AppIcon(name: AppIconName.arrowLeft, color: AppTheme.fg),
          onPressed: () => context.go('/chat'),
        ),
        actions: [
          IconButton(
            icon: const AppIcon(name: AppIconName.library, color: AppTheme.fg),
            onPressed: () => context.push('/pet/library'),
            tooltip: '音乐库',
          ),
          IconButton(
            icon: const AppIcon(name: AppIconName.maximize, color: AppTheme.fg),
            onPressed: () => context.push('/pet/full'),
            tooltip: '全屏查看',
          ),
        ],
      ),
      body: Stack(
        children: [
          // 下层：可滚动内容（UI卡片）
          ListView(
            padding: const EdgeInsets.fromLTRB(AppTheme.space4, 200, AppTheme.space4, AppTheme.space4),
            children: [
              // 音乐播放器
              _buildPetDisplay(),
              const SizedBox(height: AppTheme.space4),
              // 状态面板
              _buildStatusPanel(),
              const SizedBox(height: AppTheme.space4),
              // 交互按钮
              _buildInteractPanel(),
              const SizedBox(height: AppTheme.space4),
              // 音乐创作入口
              _buildMusicPanel(),
            ],
          ),
          // 上层：3D 宠物（小容器 + 全屏无规则运动，容器小所以看不到方框）
          Positioned.fill(
            child: AnimatedBuilder(
              animation: Listenable.merge([_moveAnimation, _floatAnimation]),
              builder: (context, child) {
                final align = _moveAnimation.value;
                return Align(
                  alignment: align,
                  child: Transform.translate(
                    offset: Offset(0, _floatAnimation.value),
                    child: child,
                  ),
                );
              },
              child: GestureDetector(
                onTap: () => _interact('pet'),
                child: const SizedBox(
                  width: 200,
                  height: 200,
                  child: VrmAvatarView(
                    asset: kDogAvatarAsset,
                    cameraOrbit: '0deg 70deg 5.5m',
                    cameraTarget: '0m 0.1m 0m',
                    fieldOfView: '50deg',
                  ),
                ),
              ),
            ),
          ),
          // 最上层：浮动交互反馈
          if (_feedbackText != null)
            Positioned(
              top: 220,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                opacity: _feedbackText != null ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.space4, vertical: AppTheme.space2),
                    decoration: BoxDecoration(
                      color: (_feedbackColor ?? AppTheme.accent).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                      boxShadow: [
                        BoxShadow(
                          color: (_feedbackColor ?? AppTheme.accent).withValues(alpha: 0.3),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Text(
                      _feedbackText!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: AppTheme.textSm,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPetDisplay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.surfaceWarm.withValues(alpha: 0.85),
            AppTheme.sunSoft.withValues(alpha: 0.4),
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space4),
        child: Column(
          children: [
            // 专辑封面（圆形，播放时旋转）
            RotationTransition(
              turns: _rotateController,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppTheme.sun, AppTheme.ember],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.sun.withValues(alpha: 0.4),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: AppTheme.surfaceWarm,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: AppIcon(name: AppIconName.dog, size: AppIconSize.xs, color: AppTheme.sun),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.space3),
            // 歌曲信息
            Text(
              _currentSong,
              style: TextStyle(fontSize: AppTheme.textMd, fontWeight: FontWeight.w600, color: AppTheme.fg),
            ),
            Text(
              _currentArtist,
              style: TextStyle(fontSize: AppTheme.textXs, color: AppTheme.muted),
            ),
            const SizedBox(height: AppTheme.space3),
            // 进度条
            Row(
              children: [
                Text(_formatTime(_progress), style: TextStyle(fontSize: 10, color: AppTheme.muted)),
                const SizedBox(width: AppTheme.space2),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _progress,
                      backgroundColor: AppTheme.surfaceSunken,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.ember),
                      minHeight: 4,
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.space2),
                Text(_formatTime(1.0), style: TextStyle(fontSize: 10, color: AppTheme.muted)),
              ],
            ),
            const SizedBox(height: AppTheme.space3),
            // 播放控制按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _prevSong,
                  icon: const AppIcon(name: AppIconName.skipBack, size: AppIconSize.sm, color: AppTheme.fg2),
                ),
                const SizedBox(width: AppTheme.space4),
                GestureDetector(
                  onTap: _togglePlay,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      color: AppTheme.ember,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: AppTheme.ember, blurRadius: 12, spreadRadius: 1),
                      ],
                    ),
                    child: Center(
                      child: AppIcon(
                        name: _isPlaying ? AppIconName.pause : AppIconName.play,
                        size: AppIconSize.md,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.space4),
                IconButton(
                  onPressed: _nextSong,
                  icon: const AppIcon(name: AppIconName.skipForward, size: AppIconSize.sm, color: AppTheme.fg2),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPanel() {
    final stats = [
      ('能量', (_petState['energy'] ?? 0).toDouble(), AppTheme.accent, AppIconName.zap),
      ('羁绊', (_petState['bond'] ?? 0).toDouble(), AppTheme.sun, AppIconName.heart),
      ('饥饿', (_petState['hunger'] ?? 0).toDouble(), AppTheme.ember, AppIconName.disc),
      ('快乐', (_petState['happiness'] ?? 0).toDouble(), AppTheme.success, AppIconName.smile),
    ];

    return Container(
      padding: const EdgeInsets.all(AppTheme.space4),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('状态', style: TextStyle(fontSize: AppTheme.textMd, fontWeight: FontWeight.w600, color: AppTheme.fg)),
          const SizedBox(height: AppTheme.space3),
          ...stats.map((s) => Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.space3),
            child: _buildStatBar(s.$1, s.$2, s.$3, s.$4),
          )),
          // 经验值
          _buildExpBar(),
        ],
      ),
    );
  }

  Widget _buildStatBar(String label, double value, Color color, AppIconName icon) {
    return Row(
      children: [
        AppIcon(name: icon, size: AppIconSize.xs, color: color),
        const SizedBox(width: AppTheme.space2),
        SizedBox(width: 40, child: Text(label, style: TextStyle(fontSize: AppTheme.textXs, color: AppTheme.muted))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            child: LinearProgressIndicator(
              value: value.clamp(0, 100) / 100,
              backgroundColor: AppTheme.surfaceSunken,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(width: AppTheme.space2),
        SizedBox(width: 36, child: Text('${value.toInt()}', style: TextStyle(fontSize: AppTheme.textXs, color: AppTheme.fg2), textAlign: TextAlign.right)),
      ],
    );
  }

  Widget _buildExpBar() {
    final exp = (_petState['exp'] ?? 0).toInt();
    final level = (_petState['level'] ?? 1).toInt();
    final need = level * 100;
    return Row(
      children: [
        const AppIcon(name: AppIconName.star, size: AppIconSize.xs, color: AppTheme.sun),
        const SizedBox(width: AppTheme.space2),
        const SizedBox(width: 40, child: Text('经验', style: TextStyle(fontSize: AppTheme.textXs, color: AppTheme.muted))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            child: LinearProgressIndicator(
              value: (exp % need) / need,
              backgroundColor: AppTheme.surfaceSunken,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.sun),
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(width: AppTheme.space2),
        SizedBox(width: 36, child: Text('$exp/$need', style: TextStyle(fontSize: AppTheme.textXs, color: AppTheme.fg2), textAlign: TextAlign.right)),
      ],
    );
  }

  Widget _buildInteractPanel() {
    final actions = [
      ('喂食', AppIconName.disc, AppTheme.sun, 'feed'),
      ('玩耍', AppIconName.sparkles, AppTheme.accent, 'play'),
      ('抚摸', AppIconName.heart, AppTheme.ember, 'pet'),
      ('对话', AppIconName.messageCircle, AppTheme.info, 'talk'),
      ('睡觉', AppIconName.moon, AppTheme.muted, 'sleep'),
    ];

    return Container(
      padding: const EdgeInsets.all(AppTheme.space4),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('互动', style: TextStyle(fontSize: AppTheme.textMd, fontWeight: FontWeight.w600, color: AppTheme.fg)),
          const SizedBox(height: AppTheme.space3),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: actions.map((a) => _buildInteractButton(a.$1, a.$2, a.$3, a.$4)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractButton(String label, AppIconName icon, Color color, String action) {
    final isPressed = _pressedAction == action;
    return GestureDetector(
      onTap: () => _interact(action),
      child: AnimatedScale(
        scale: isPressed ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isPressed ? color.withValues(alpha: 0.25) : color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: isPressed ? Border.all(color: color, width: 1.5) : null,
              ),
              child: Center(child: AppIcon(name: icon, size: AppIconSize.sm, color: color)),
            ),
            const SizedBox(height: AppTheme.space1),
            Text(
              label,
              style: TextStyle(
                fontSize: AppTheme.textXs,
                color: isPressed ? color : AppTheme.fg2,
                fontWeight: isPressed ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMusicPanel() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.space4),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('音乐创作', style: TextStyle(fontSize: AppTheme.textMd, fontWeight: FontWeight.w600, color: AppTheme.fg)),
          const SizedBox(height: AppTheme.space3),
          _buildMusicEntry('生成音乐', '用歌词或灵感创作一首新歌', AppIconName.music, AppTheme.ember, () {
            context.push('/pet/library');
          }),
          const SizedBox(height: AppTheme.space2),
          _buildMusicEntry('歌词库', '管理你的歌词创作', AppIconName.fileText, AppTheme.accent, () {
            context.push('/pet/library');
          }),
          const SizedBox(height: AppTheme.space2),
          _buildMusicEntry('歌曲库', '收听已生成的歌曲', AppIconName.headphones, AppTheme.sun, () {
            context.push('/pet/library');
          }),
        ],
      ),
    );
  }

  Widget _buildMusicEntry(String title, String desc, AppIconName icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.space3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(AppTheme.radius),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Center(child: AppIcon(name: icon, size: AppIconSize.sm, color: color)),
            ),
            const SizedBox(width: AppTheme.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: AppTheme.textSm, fontWeight: FontWeight.w500, color: AppTheme.fg)),
                  Text(desc, style: TextStyle(fontSize: AppTheme.textXs, color: AppTheme.muted)),
                ],
              ),
            ),
            const AppIcon(name: AppIconName.chevronRight, size: AppIconSize.xs, color: AppTheme.muted),
          ],
        ),
      ),
    );
  }
}
