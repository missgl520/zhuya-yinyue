// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 信纸式消息条目
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/entities.dart' as entities;
import 'chat_typing_cursor.dart';

/// 消息条目组件（用户 / AI 分开样式，流式打字光标）
class ChatLetterEntry extends StatelessWidget {
  final entities.Message message;
  final int distanceFromBottom;

  const ChatLetterEntry({
    super.key,
    required this.message,
    required this.distanceFromBottom,
  }) : _isTyping = false;

  ChatLetterEntry.typing(String text)
      : message = entities.Message(
          id: '__typing__',
          role: 'assistant',
          content: text,
          timestamp: DateTime.now(),
          isStreaming: true,
        ),
        distanceFromBottom = 1,
        _isTyping = true;

  final bool _isTyping;

  bool get isUser => message.role == 'user';

  /// 远端消息渐显（离底部越远越透明）
  Widget _buildEntry(Widget realContent) {
    if (distanceFromBottom <= 3) {
      return AnimatedOpacity(
        opacity: 1.0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        child: realContent,
      );
    }
    const double step = 0.25;
    final double alpha =
        (1.0 - step * (distanceFromBottom - 3)).clamp(0.18, 1.0);
    return AnimatedOpacity(
      opacity: alpha,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      child: realContent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget realContent = Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // 发送者标签
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isUser) ...[
                Image.asset(
                  'assets/logo_mascot.png',
                  width: 18,
                  height: 18,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                isUser ? '我' : '竹笌',
                style: TextStyle(
                  fontSize: 11,
                  color: isUser
                      ? Theme.of(context).textTheme.bodySmall?.color
                      : AppTheme.bambooDeep.withValues(alpha: 0.7),
                  letterSpacing: 3,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (!isUser) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppTheme.bambooDeep.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'AI 生成',
                    style: TextStyle(
                      fontSize: 9,
                      color: AppTheme.bambooDeep,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          // 消息气泡
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.62,
            ),
            decoration: BoxDecoration(
              color: isUser
                  ? AppTheme.bambooDeep
                  : Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(16),
              border: isUser
                  ? null
                  : Border.all(
                      color: AppTheme.bamboo.withValues(alpha: 0.3),
                      width: 0.5,
                    ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.content,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    color: isUser ? Colors.white : AppTheme.bambooDeep,
                  ),
                ),
                if (message.isStreaming) ...[
                  const SizedBox(height: 2),
                  const ChatTypingCursor(),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    return _buildEntry(realContent);
  }
}
