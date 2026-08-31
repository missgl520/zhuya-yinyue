// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 竹笌主页 - 信纸式对话
//
// 新架构（v2）：
//   UI → ChatNotifier → ChatRepository → BackendApiDataSource → 后端
//
// 状态机：idle → thinking → writing → speaking → idle
//
// 迁移记录（2026-08-31）：
//   - 移除旧 providers 文件引用，全面使用新架构
//   - 主题/TTS/ASR → settings_provider.dart
//   - 消息管理 → ChatNotifier（chat_provider.dart）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'dart:async';
import 'dart:math';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_live2d/flutter_live2d.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../settings/settings_sheet.dart';
import '../settings/menu_panel.dart';
import '../../domain/entities/entities.dart' as entities;
import '../../presentation/providers/chat_provider.dart';
import '../../presentation/providers/settings_provider.dart';
import '../../core/services/emotion_tts_service.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/vrm_avatar_view.dart';
import '../../widgets/voice_button.dart';
import '../../widgets/image_picker_button.dart';

// ════════════════════════════════════════════════════════════
// 情绪工具（保留自原文件）
// ════════════════════════════════════════════════════════════

String emotionEmoji(String label) {
  return switch (label) {
    'happy' => '😊',
    'sad' => '😢',
    'angry' => '😠',
    'surprised' => '😮',
    'fearful' => '😨',
    'disgusted' => '🤢',
    'neutral' => '😐',
    _ => '😐',
  };
}

String emotionLabel(String label) {
  return switch (label) {
    'happy' => '开心',
    'sad' => '难过',
    'angry' => '生气',
    'surprised' => '惊讶',
    'fearful' => '害怕',
    'disgusted' => '讨厌',
    'neutral' => '平静',
    _ => label,
  };
}

// ════════════════════════════════════════════════════════════
// 页面
// ════════════════════════════════════════════════════════════

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  late AnimationController _thinkingController;

  @override
  void initState() {
    super.initState();
    _thinkingController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _thinkingController.forward(from: 0);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 新架构：监听 ChatNotifier 状态
      ref.listenManual(chatNotifierProvider, (_, state) {
        if (state.errorMessage != null ||
            state.messages.any((m) => m.isStreaming)) {
          _thinkingController.repeat(reverse: true);
        } else {
          _thinkingController.stop();
        }
        _scrollToBottom();
      });

      // ASR 语音识别结果
      ref.listenManual(asrResultProvider, (_, text) {
        if (text != null && text.isNotEmpty) {
          _inputController.text = text;
          _send();
          ref.read(asrResultProvider.notifier).state = null;
        }
      });

      // 监听对话完成，触发 TTS 朗读
      ref.listenManual(chatNotifierProvider, (prev, next) {
        final prevLast = prev?.messages.isNotEmpty == true
            ? prev!.messages.last
            : null;
        final nextLast =
            next.messages.isNotEmpty ? next.messages.last : null;
        if (nextLast != null &&
            nextLast.role == 'assistant' &&
            prevLast?.id != nextLast.id) {
          _speakReply(nextLast.content, emotion: nextLast.emotion);
        }
      });
    });
  }

  // ━━━ TTS 朗读 ━━━

  Future<void> _speakReply(String text, {String? emotion}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    try {
      await ref.read(emotionTtsEngineProvider).speak(trimmed, emotion: emotion ?? 'neutral');
    } catch (_) {
      // 朗读失败不影响对话完整性
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _thinkingController.dispose();
    super.dispose();
  }

  // ━━━ 发送消息 ━━━

  void _send() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    // 清空输入框，收起键盘
    _inputController.clear();
    _focusNode.unfocus();
    _scrollToBottom();

    // 交给 ChatNotifier（核心逻辑走新架构）
    ref.read(chatNotifierProvider.notifier).sendMessage(text);
  }

  // ━━━ 图片选择回调 ━━━

  void _onImagePicked(String path) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text('已选择图片：${path.split('/').last}（多模态发送待接入）'),
      ),
    );
  }

  // ━━━ 滚动 ━━━

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // UI
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatNotifierProvider);
    final status = ref.watch(conversationStatusProvider);
    final isDark = ref.watch(themeProvider);
    final messages = chatState.messages;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(
            child: ColoredBox(color: Color(0xFFEDF7F0)),
          ),
          _WanderingLive2D(),
          Positioned(
            bottom: 140,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.38,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _focusNode.unfocus(),
              child: (messages.isEmpty &&
                      !(status == ConversationStatus.writing &&
                          (chatState.currentText?.isNotEmpty ?? false)))
                  ? _buildEmptyOrErrorPlaceholder(chatState, isDark)
                  : _buildLetterList(chatState, status),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(isDark),
                const Spacer(),
                _buildInputArea(status),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ━━━ 顶栏 ━━━

  Widget _buildTopBar(bool isDark) {
    final currentEmotion = ref.watch(currentEmotionProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => MenuPanel.show(context),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Image.asset(
                'assets/logo_mascot.png',
                width: 36,
                height: 36,
                fit: BoxFit.contain,
              ),
            ),
          ),
          if (currentEmotion != null && currentEmotion.emotion != 'neutral')
            _buildEmotionChip(currentEmotion.emotion),
          const Spacer(),
          _buildStatusBadge(),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => context.push('/avatar/customize'),
            child: const _TopIcon(icon: Icons.style_outlined),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => context.push('/pet'),
            child: const _TopIcon(icon: Icons.pets),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => SettingsSheet.show(context),
            child: const _TopIcon(icon: Icons.settings_outlined),
          ),
        ],
      ),
    );
  }

  Widget _buildEmotionChip(String label) {
    return Container(
      margin: const EdgeInsets.only(left: 10),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emotionEmoji(label), style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(
            emotionLabel(label),
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white,
              letterSpacing: 1,
              shadows: [
                Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 1)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    final status = ref.watch(conversationStatusProvider);
    final chatState = ref.watch(chatNotifierProvider);

    if (chatState.errorMessage != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '出错了',
          style: TextStyle(
            fontSize: 12,
            color: Colors.red.shade700,
            fontWeight: FontWeight.w500,
            letterSpacing: 1,
          ),
        ),
      );
    }

    if (status == ConversationStatus.idle) {
      return const SizedBox.shrink();
    }

    final label = switch (status) {
      ConversationStatus.idle => '',
      ConversationStatus.thinking => '在想',
      ConversationStatus.writing => '在写',
      ConversationStatus.speaking => '在说',
    };

    final color = switch (status) {
      ConversationStatus.idle => AppTheme.bambooDeep,
      ConversationStatus.thinking => const Color(0xFFB8A07A),
      ConversationStatus.writing => AppTheme.bambooDeep,
      ConversationStatus.speaking => AppTheme.bambooDeep,
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildEmptyHint(bool isDark, ConversationStatus status) {
    final label = status == ConversationStatus.idle ? '竹笌在这里' : '竹笌在等你';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.bamboo.withValues(alpha: 0.35),
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          color: Theme.of(context).textTheme.bodySmall?.color,
          letterSpacing: 2,
        ),
      ),
    );
  }

  Widget _buildEmptyOrErrorPlaceholder(ChatState chatState, bool isDark) {
    final hasError = chatState.errorMessage != null;
    if (!hasError) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 12),
        child: Row(
          children: [
            Image.asset(
              'assets/logo_mascot.png',
              width: 22,
              height: 22,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 8),
            Text(
              '竹笌在这里，等你说第一句话',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.bambooDeep.withValues(alpha: 0.75),
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: 18,
                color: AppTheme.bambooDeep,
              ),
              const SizedBox(width: 8),
              const Text(
                '竹笌连不上',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.bambooDeep,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            chatState.errorMessage!,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).textTheme.bodySmall?.color,
              height: 1.5,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '检查后端地址或点击重试 · 写点什么给竹笌 ↑',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.bambooDeep.withValues(alpha: 0.55),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ━━━ 信纸列表 ━━━

  Widget _buildLetterList(ChatState chatState, ConversationStatus status) {
    final messages = chatState.messages;
    final typing = status == ConversationStatus.writing &&
        (chatState.currentText?.isNotEmpty ?? false);
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      itemCount: messages.length + 1 + (typing ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == 0) return const SizedBox(height: 8);
        final msgIndex = index - 1;
        if (typing && msgIndex == messages.length) {
          return _LetterEntry.typing(chatState.currentText!);
        }
        return _LetterEntry(
          message: messages[msgIndex],
          distanceFromBottom: messages.length - msgIndex,
        );
      },
    );
  }

  // ━━━ 输入区 ━━━

  Widget _buildInputArea(ConversationStatus status) {
    final isWorking = status == ConversationStatus.thinking ||
        status == ConversationStatus.writing;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 0.5,
          ),
        ),
      ),
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isWorking) _buildThinkingIndicator(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ImagePickerButton(onImagePicked: _onImagePicked),
                  const VoiceButton(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      focusNode: _focusNode,
                      maxLines: null,
                      minLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      enabled: !isWorking,
                      style: Theme.of(context).textTheme.bodyLarge,
                      decoration: InputDecoration(
                        hintText: '写给竹笌…',
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusXl),
                          borderSide: BorderSide(
                            color: Theme.of(context).dividerColor,
                            width: 0.5,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusXl),
                          borderSide: BorderSide(
                            color: Theme.of(context).dividerColor,
                            width: 0.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusXl),
                          borderSide: const BorderSide(
                            color: AppTheme.bambooDeep,
                            width: 1,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ListenableBuilder(
                    listenable: _inputController,
                    builder: (_, _) {
                      final hasText = _inputController.text.trim().isNotEmpty;
                      return !isWorking && hasText
                          ? IconButton(
                              onPressed: _send,
                              icon: const Icon(
                                Icons.arrow_upward,
                                color: AppTheme.bambooDeep,
                              ),
                            )
                          : const SizedBox(width: 48);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ━━━ 思考中动画 ━━━

  Widget _buildThinkingIndicator() {
    return AnimatedBuilder(
      animation: _thinkingController,
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < 3; i++) _Dot(delay: i, anim: _thinkingController.value),
              const SizedBox(width: 8),
              Text(
                '竹笌在想',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 顶栏图标
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _TopIcon extends StatelessWidget {
  final IconData icon;
  const _TopIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Icon(
      icon,
      size: 24,
      color: Colors.white,
      shadows: [
        Shadow(
          color: Colors.black.withValues(alpha: 0.45),
          blurRadius: 6,
          offset: const Offset(0, 1),
        ),
        Shadow(
          color: Colors.black.withValues(alpha: 0.2),
          blurRadius: 14,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 消息条目
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _LetterEntry extends StatelessWidget {
  final entities.Message message;
  final int distanceFromBottom;

  const _LetterEntry({required this.message, required this.distanceFromBottom});

  _LetterEntry.typing(String text)
      : message = entities.Message(
          id: '__typing__',
          role: 'assistant',
          content: text,
          timestamp: DateTime.now(),
          isStreaming: true,
        ),
        distanceFromBottom = 1;

  bool get isUser => message.role == 'user';

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
                  const _TypingCursor(),
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

// 打字光标
class _TypingCursor extends StatefulWidget {
  const _TypingCursor();

  @override
  State<_TypingCursor> createState() => _TypingCursorState();
}

class _TypingCursorState extends State<_TypingCursor>
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

// 思考动画圆点
class _Dot extends StatelessWidget {
  final int delay;
  final double anim;

  const _Dot({required this.delay, required this.anim});

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

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Live2D 漂移 + 3D 模型（保留自原文件）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _WanderingLive2D extends ConsumerStatefulWidget {
  const _WanderingLive2D();

  @override
  ConsumerState<_WanderingLive2D> createState() => _WanderingLive2DState();
}

class _WanderingLive2DState extends ConsumerState<_WanderingLive2D>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(vsync: this);
  final math.Random _rnd = math.Random();

  Size? _screen;
  Offset _offset = Offset.zero;
  Timer? _timer;
  Animation<Offset>? _anim;
  Animation<Offset>? _prevAnim;

  Timer? _keepAliveT;
  double _keepAlivePhase = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _screen = MediaQuery.of(context).size;
      _scheduleNextDrift();
    });
    _keepAliveT = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(() => _keepAlivePhase += 0.1);
    });
  }

  void _scheduleNextDrift() {
    if (!mounted) return;
    _timer = Timer(
      Duration(milliseconds: 3500 + _rnd.nextInt(5000)),
      _driftToRandom,
    );
  }

  void _onAnimTick() {
    if (mounted) setState(() => _offset = _anim!.value);
  }

  void _driftToRandom() {
    if (!mounted || _screen == null) {
      _scheduleNextDrift();
      return;
    }
    final sw = _screen!.width;
    final sh = _screen!.height;
    final target = Offset(
      (_rnd.nextDouble() * 2 - 1) * sw * 0.28,
      (_rnd.nextDouble() * 2 - 1) * sh * 0.22,
    );

    _prevAnim?.removeListener(_onAnimTick);
    _anim = Tween<Offset>(begin: _offset, end: target).animate(
      CurvedAnimation(parent: _drift, curve: Curves.easeInOutSine),
    );
    _anim!.addListener(_onAnimTick);
    _prevAnim = _anim;

    _drift.duration = Duration(milliseconds: 4000 + _rnd.nextInt(4000));
    _drift.forward(from: 0).then((_) {
      if (!mounted) return;
      _offset = target;
      _scheduleNextDrift();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _keepAliveT?.cancel();
    _prevAnim?.removeListener(_onAnimTick);
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _offset.dx,
      top: _offset.dy - (math.sin(_keepAlivePhase * 12.0) * 0.5),
      child: SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height * 0.78,
        child: const VrmAvatarView(),
      ),
    );
  }
}
