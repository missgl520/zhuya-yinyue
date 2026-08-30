// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 语音输入按钮（长按说话）
//
// 交互：长按开始录音，松开停止，自动发送识别文字
// 状态：默认(绿) → 按下(红+脉冲) → 停止(恢复)
//
// 依赖：AsrService（speech_to_text 插件）
// 权限：麦克风（Android: RECORD_AUDIO，iOS: NSMicrophoneUsageDescription）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import '../presentation/providers/app_providers.dart';

class VoiceButton extends ConsumerStatefulWidget {
  const VoiceButton({super.key});

  @override
  ConsumerState<VoiceButton> createState() => _VoiceButtonState();
}

class _VoiceButtonState extends ConsumerState<VoiceButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;
  bool _permissionGranted = false;
  // ignore: unused_field
  String _lastRecognized = '';

  @override
  void initState() {
    super.initState();
    _checkPermission();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _pulseAnim = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _checkPermission() async {
    try {
      final asr = ref.read(asrServiceProvider);
      _permissionGranted = await asr.requestPermission();
    } catch (e) {
      // 语音识别不可用时静默降级，绝不阻断页面初始化（避免红屏）
      _permissionGranted = false;
    }
  }

  Future<void> _startListening() async {
    if (!_permissionGranted) {
      _permissionGranted = await ref
          .read(asrServiceProvider)
          .requestPermission();
      if (!_permissionGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('语音识别不可用（设备不支持或未授权），请改用文字输入')),
          );
        }
        return;
      }
    }

    setState(() {});
    _pulseController.repeat();
    ref.read(asrListeningProvider.notifier).state = true;

    final asr = ref.read(asrServiceProvider);

    try {
      await asr.startListening(
        localeId: asr.zhLocaleId ?? 'zh_CN',
        onResult: (String text, bool finalResult) {
          _lastRecognized = text;
          if (finalResult && text.isNotEmpty) {
            // 写入 provider，chat_page 监听后自动发送
            ref.read(asrResultProvider.notifier).state = text;
          }
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('语音识别失败: $e')));
      }
    }
  }

  void _stopListening() {
    final asr = ref.read(asrServiceProvider);
    asr.stopListening();

    _pulseController.stop();
    _pulseController.reset();
    ref.read(asrListeningProvider.notifier).state = false;
  }

  @override
  Widget build(BuildContext context) {
    final isListening = ref.watch(asrListeningProvider);

    return GestureDetector(
      onTapDown: (_) => _startListening(),
      onTapUp: (_) => _stopListening(),
      onTapCancel: _stopListening,

      child: AnimatedBuilder(
        animation: _pulseAnim,
        builder: (context, child) {
          return Transform.scale(
            scale: isListening ? _pulseAnim.value : 1.0,
            child: child,
          );
        },
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isListening ? const Color(0xFFE53935) : AppTheme.bamboo,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: (isListening ? const Color(0xFFE53935) : AppTheme.bamboo)
                    .withValues(alpha: 0.3),
                blurRadius: isListening ? 12 : 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(
            isListening ? Icons.mic : Icons.mic_none,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }
}
