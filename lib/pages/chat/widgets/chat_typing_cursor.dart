// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 打字光标 + 思考动画圆点
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// 打字光标（闪烁竖线）
class ChatTypingCursor extends StatefulWidget {
  const ChatTypingCursor({super.key});

  @override
  State<ChatTypingCursor> createState() => _ChatTypingCursorState();
}

class _ChatTypingCursorState extends State<ChatTypingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    duration: const Duration(milliseconds: 600),
    vsync: this,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Container(
        width: 2,
        height: 14,
        margin: const EdgeInsets.only(left: 4),
        color: AppTheme.bambooDeep.withValues(alpha: _c.value),
      ),
    );
  }
}

/// 思考动画圆点（三个点依次跳动）
class ChatThinkingDot extends StatelessWidget {
  final int delay; // 0, 1, 2
  final double anim; // 0.0~1.0 循环

  const ChatThinkingDot({
    super.key,
    required this.delay,
    required this.anim,
  });

  @override
  Widget build(BuildContext context) {
    final t = ((anim + delay * 0.33) % 1.0);
    final scale = math.sin(t * math.pi);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.bambooDeep.withValues(alpha: 0.3 + 0.7 * scale),
      ),
    );
  }
}

/// 思考动画容器（驱动三个圆点）
class ChatThinkingDots extends StatefulWidget {
  const ChatThinkingDots({super.key});

  @override
  State<ChatThinkingDots> createState() => _ChatThinkingDotsState();
}

class _ChatThinkingDotsState extends State<ChatThinkingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    duration: const Duration(milliseconds: 1200),
    vsync: this,
  )..repeat();

  @override
  void dispose() => _c.dispose();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) => AnimatedBuilder(
        animation: _c,
        builder: (_, __) => ChatThinkingDot(delay: i, anim: _c.value),
      )),
    );
  }
}
