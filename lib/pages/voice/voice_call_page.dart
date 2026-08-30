// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 实时语音通话页面
//
// 触发：菜单 → "语音通话" 按钮
// 退出：点击挂断按钮
//
// 功能：
//   - 麦克风音频自动发布到 LiveKit 房间
//   - AI Agent 音频自动订阅并播放
//   - 通话状态实时显示
//   - 异常重连处理
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/livekit_service.dart';
import '../../core/theme/app_theme.dart';

/// LiveKit 通话状态
final liveKitStateProvider = StateProvider<LiveKitState>(
  (_) => LiveKitState.idle,
);

/// LiveKit 连接错误信息
final liveKitErrorProvider = StateProvider<String?>((_) => null);

/// 当前通话时长（秒）
final callDurationProvider = StateProvider<int>((_) => 0);

class VoiceCallPage extends ConsumerStatefulWidget {
  const VoiceCallPage({super.key});

  static void show(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const VoiceCallPage()));
  }

  @override
  ConsumerState<VoiceCallPage> createState() => _VoiceCallPageState();
}

class _VoiceCallPageState extends ConsumerState<VoiceCallPage>
    with SingleTickerProviderStateMixin {
  final LiveKitService _liveKit = LiveKitService();

  bool _isMuted = false;
  DateTime? _callStartTime;
  Timer? _durationTimer;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat();
    _connect();
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _waveController.dispose();
    _liveKit.disconnect();
    super.dispose();
  }

  Future<void> _connect() async {
    ref.read(liveKitStateProvider.notifier).state = LiveKitState.connecting;

    try {
      await _liveKit.connect(room: 'zhuyapp-voice');

      ref.read(liveKitStateProvider.notifier).state = LiveKitState.connected;
      _callStartTime = DateTime.now();
      _startDurationTimer();
    } catch (e) {
      ref.read(liveKitErrorProvider.notifier).state = e.toString();
      ref.read(liveKitStateProvider.notifier).state = LiveKitState.error;
    }
  }

  void _startDurationTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_callStartTime != null && mounted) {
        final diff = DateTime.now().difference(_callStartTime!).inSeconds;
        ref.read(callDurationProvider.notifier).state = diff;
      }
    });
  }

  void _toggleMute() async {
    setState(() => _isMuted = !_isMuted);
    try {
      await _liveKit.setMuted(_isMuted);
    } catch (e) {
      // 静音失败不影响 UI 状态，仅回退标记
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('麦克风操作失败：$e')));
      }
    }
  }

  void _endCall() {
    Navigator.of(context).pop();
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(liveKitStateProvider);
    final error = ref.watch(liveKitErrorProvider);
    final duration = ref.watch(callDurationProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF16271C),
      body: SafeArea(
        child: Column(
          children: [
            // ── 顶栏 ──
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white70),
                    onPressed: _endCall,
                  ),
                  const Spacer(),
                  if (state == LiveKitState.connected)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _formatDuration(duration),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  const Spacer(),
                  const SizedBox(width: 48), // 占位
                ],
              ),
            ),

            const Spacer(),

            // ── 竹笌头像 + 声波可视化 ──
            Stack(
              alignment: Alignment.center,
              children: [
                if (state == LiveKitState.connected)
                  _SoundWaves(animation: _waveController),
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.bamboo.withValues(alpha: 0.15),
                    border: Border.all(
                      color: AppTheme.bamboo.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: state == LiveKitState.connected
                        ? const Text('🌱', style: TextStyle(fontSize: 52))
                        : const Text('🔗', style: TextStyle(fontSize: 52)),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── 竹笌名字 ──
            const Text(
              '竹笌',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 8),

            // ── 状态文字 ──
            Text(
              _stateText(state),
              style: TextStyle(color: _stateColor(state), fontSize: 15),
            ),

            if (error != null) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  error,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ],

            const Spacer(),

            // ── 控制按钮（毛玻璃） ──
            Padding(
              padding: const EdgeInsets.only(bottom: 48),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 静音按钮
                        _ControlButton(
                          icon: _isMuted ? Icons.mic_off : Icons.mic,
                          label: _isMuted ? '取消静音' : '静音',
                          isActive: !_isMuted,
                          onTap: state == LiveKitState.connected
                              ? _toggleMute
                              : null,
                        ),

                        const SizedBox(width: 40),

                        // 挂断按钮
                        _ControlButton(
                          icon: Icons.call_end,
                          label: '挂断',
                          bgColor: Colors.red,
                          onTap: _endCall,
                        ),

                        const SizedBox(width: 40),

                        // 占位（未来：扬声器）
                        const SizedBox(width: 56),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _stateText(LiveKitState s) {
    return switch (s) {
      LiveKitState.idle => '等待连接...',
      LiveKitState.connecting => '正在连接竹笌...',
      LiveKitState.connected => '通话中',
      LiveKitState.error => '连接失败',
    };
  }

  Color _stateColor(LiveKitState s) {
    return switch (s) {
      LiveKitState.connected => AppTheme.bamboo,
      LiveKitState.error => Colors.red,
      _ => Colors.white54,
    };
  }
}

/// 通话控制按钮
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? bgColor;
  final bool isActive;
  final VoidCallback? onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    this.bgColor,
    this.isActive = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bgColor ?? (isActive ? Colors.white24 : Colors.white12),
            ),
            child: Icon(
              icon,
              color: onTap == null ? Colors.white30 : Colors.white,
              size: 26,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: onTap == null ? Colors.white30 : Colors.white54,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

/// 环形声波可视化（通话中随动画向外扩散）
class _SoundWaves extends StatelessWidget {
  final Animation<double> animation;

  const _SoundWaves({required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) {
        return Stack(
          alignment: Alignment.center,
          children: List.generate(3, (i) {
            final delay = i / 3.0;
            final t = ((animation.value + delay) % 1.0);
            final scale = 1.0 + t * 0.8;
            final opacity = (1.0 - t) * 0.5;
            return Transform.scale(
              scale: scale,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.bamboo.withValues(alpha: opacity),
                    width: 2,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
