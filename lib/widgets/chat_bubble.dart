// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 聊天气泡组件（已废弃，保留备用）
//
// 当前 ChatPage 使用信纸样式（_LetterEntry）替代了气泡样式。
// 本文件保留用于：日后需要切换回气泡样式时快速恢复。
//
// 气泡样式特点（与信纸样式的区别）：
//   - 气泡有背景色（用户绿 / AI 灰白）
//   - 圆角落在对侧（左上右下 / 右上左下）
//   - 有头像（头像 + 消息 + 打字动画）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
import 'package:flutter/material.dart';
import '../domain/entities/message.dart';
import '../../core/theme/app_theme.dart';

class ChatBubble extends StatelessWidget {
  final Message message;
  final VoidCallback? onLongPress;

  const ChatBubble({super.key, required this.message, this.onLongPress});

  bool get isUser => message.role == 'user';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // AI 头像（左侧）
          if (!isUser) ...[
            _buildAvatar(isUser: false),
            const SizedBox(width: 8),
          ],

          // 气泡
          Flexible(
            child: GestureDetector(
              onLongPress: onLongPress,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isUser
                      ? AppTheme.bamboo
                      : Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF2A2A2A)
                      : const Color(0xFFE8E8E8),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    // 尖角朝向：用户→右下，AI→左下
                    bottomLeft: Radius.circular(isUser ? 18 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 18),
                  ),
                  boxShadow: isUser
                      ? null
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // AI 角色名
                    if (!isUser)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '竹笌',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.bamboo.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    // 消息内容
                    Text(
                      message.content,
                      style: TextStyle(
                        fontSize: 15,
                        color: isUser
                            ? Colors.white
                            : (Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white
                                  : Colors.black87),
                        height: 1.4,
                      ),
                    ),
                    // 流式打字指示器
                    if (message.isStreaming)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildTypingDot(0),
                            const SizedBox(width: 3),
                            _buildTypingDot(1),
                            const SizedBox(width: 3),
                            _buildTypingDot(2),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // 用户头像（右侧）
          if (isUser) ...[const SizedBox(width: 8), _buildAvatar(isUser: true)],
        ],
      ),
    );
  }

  Widget _buildAvatar({required bool isUser}) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isUser ? const Color(0xFF81C784) : AppTheme.bamboo,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        isUser ? Icons.person : Icons.eco,
        size: 18,
        color: Colors.white,
      ),
    );
  }

  // 三个点的打字动画（相位错开）
  Widget _buildTypingDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1.0),
      duration: Duration(milliseconds: 600 + index * 150),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey.withValues(alpha: value),
          ),
        );
      },
    );
  }
}
