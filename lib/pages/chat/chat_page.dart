// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 竹笌主页 - 信纸式对话
//
// 新架构（v2）：
//   UI → ChatNotifier → ChatRepository → BackendApiDataSource → 后端
//
// 状态机：idle → thinking → writing → speaking → idle
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../settings/settings_sheet.dart';
import '../settings/menu_panel.dart';
import '../../providers/app_providers_legacy.dart' as old_msg;
import '../../presentation/providers/app_providers.dart' as old_providers;
import '../../domain/entities/entities.dart' as entities;
import '../../presentation/providers/app_providers.dart' as new_providers;
import '../../presentation/providers/chat_provider.dart';
import '../../widgets/live2d_controller.dart';
import '../../widgets/live2d_widget.dart';
import '../../widgets/voice_button.dart';
import '../../widgets/image_picker_button.dart';
import '../../widgets/dashed_container.dart';
import '../../core/theme/app_theme.dart';

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

  // ━━━ 生命周期 ━━━

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
      // 初始化 Live2D
      ref.read(old_providers.live2dControllerProvider).init();

      // 新架构：监听 ChatNotifier 状态
      ref.listenManual(chatNotifierProvider, (_, state) {
        if (state.errorMessage != null || state.messages.any((m) => m.isStreaming)) {
          _thinkingController.repeat(reverse: true);
        } else {
          _thinkingController.stop();
        }
        _scrollToBottom();
      });

      // 新架构：监听对话状态，同步 Live2D
      ref.listenManual(conversationStatusProvider, (_, status) {
        _syncLive2DStatus(status);
      });

      // 新架构：监听情绪变化，同步 Live2D 表情
      ref.listenManual(currentEmotionProvider, (_, emotion) {
        _syncLive2DEmotion(emotion?.emotion ?? 'neutral');
      });

      // 旧架构：语音识别结果
      ref.listenManual(old_providers.asrResultProvider, (_, text) {
        if (text != null && text.isNotEmpty) {
          _inputController.text = text;
          _send();
          ref.read(old_providers.asrResultProvider.notifier).state = null;
        }
      });

      // 新架构：监听对话完成，触发 TTS 朗读（语音陪聊核心能力）
      ref.listenManual(chatNotifierProvider, (prev, next) {
        final prevLast =
            prev?.messages.isNotEmpty == true ? prev!.messages.last : null;
        final nextLast =
            next.messages.isNotEmpty ? next.messages.last : null;
        // 仅当新增了一条 assistant 消息时才朗读，
        // 避免 thinking/writing 等状态变化重复触发
        if (nextLast != null &&
            nextLast.role == 'assistant' &&
            prevLast?.id != nextLast.id) {
          _speakReply(nextLast.content);
        }
      });
    });
  }

  // ━━━ TTS 朗读 ━━━

  /// 触发竹笌回复的语音朗读（语音陪聊核心能力）。
  /// - 按设置页的 TTS 模式选择 MiniMax / 系统 TTS；
  /// - MiniMax 未配置或失败时自动降级到系统 TTS，保证一定出声；
  /// - 朗读期间同步 Live2D 的「说话」动画。
  Future<void> _speakReply(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final ttsEnabled = ref.read(old_providers.ttsEnabledProvider);
    if (!ttsEnabled) return;

    final l2dCtrl = ref.read(old_providers.live2dControllerProvider);
    l2dCtrl.setStatus(ZhuaLive2DStatus.speaking);
    l2dCtrl.startLipSync(); // TTS 朗读期间驱动 Live2D 唇形同步（嘴巴随说话开合）

    final mode = ref.read(old_providers.ttsModeProvider);
    try {
      if (mode == 'minimax') {
        final ok = await ref
            .read(old_providers.miniMaxTtsServiceProvider)
            .speak(trimmed);
        if (!ok) {
          await ref.read(old_providers.ttsServiceProvider).speak(trimmed);
        }
      } else {
        await ref.read(old_providers.ttsServiceProvider).speak(trimmed);
      }
    } catch (_) {
      // 朗读失败不影响对话完整性
    } finally {
      l2dCtrl.stopLipSync(); // 停止唇形同步并闭嘴复位
      l2dCtrl.setStatus(ZhuaLive2DStatus.idle);
    }
  }

  // ━━━ Live2D 同步 ━━━

  void _syncLive2DStatus(ConversationStatus status) {
    final ctrl = ref.read(old_providers.live2dControllerProvider);
    switch (status) {
      case ConversationStatus.idle:
        // 空闲时强制恢复到待机常态：停止唇形同步、闭嘴、回默认表情、重播 Idle。
        ctrl.resetToIdle();
      case ConversationStatus.thinking:
        ctrl.setStatus(ZhuaLive2DStatus.thinking);
      case ConversationStatus.writing:
        ctrl.setStatus(ZhuaLive2DStatus.thinking);
      case ConversationStatus.speaking:
        ctrl.setStatus(ZhuaLive2DStatus.speaking);
    }
  }

  void _syncLive2DEmotion(String emotion) {
    final ctrl = ref.read(old_providers.live2dControllerProvider);
    switch (emotion) {
      case 'happy':  ctrl.setEmotion('happy');
      case 'sad':    ctrl.setEmotion('sad');
      case 'angry':  ctrl.setEmotion('angry');
      case 'surprised': ctrl.setEmotion('surprised');
      case 'anxious': ctrl.setEmotion('anxious');
      default:       ctrl.setEmotion('neutral');
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

    // 旧 provider（Hive 持久化兼容）
    final userMsg = old_msg.Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'user',
      content: text,
      timestamp: DateTime.now(),
    );
    ref.read(old_providers.messagesProvider.notifier).addMessage(userMsg);

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
        content: Text('已选择图片：${path.split('/').last}（多模态发送待接入）'),
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
    final isDark = ref.watch(old_providers.themeProvider);

    final messages = chatState.messages;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Live2D 全屏底层（包括顶部状态栏区域），让角色成为背景视觉主角。
          //    顶栏透明叠加在模型上方，实现「顶层透明，显示 2D 模型层」。
          Positioned.fill(
            child: Consumer(
              builder: (context, ref, _) {
                final l2dCtrl =
                    ref.watch(old_providers.live2dControllerProvider);
                final lipSync =
                    ref.watch(new_providers.lipSyncStreamProvider);
                lipSync.whenData((mouth) {
                  l2dCtrl.viewController.setParameter(
                    'ParamMouthOpenY',
                    mouth.clamp(0.0, 0.75),
                  );
                });
                return ZhuaLive2DWidget(
                  controller: l2dCtrl.viewController,
                  onTap: () {},
                );
              },
            ),
          ),

          // 2. 主内容层：SafeArea 保证状态栏/导航栏安全，
          //    顶栏透明，消息/输入区正常叠加。
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(isDark),
                Expanded(
                  child: Stack(
                    children: [
                      // 消息半透明浮层（中层，嫩绿虚线边框，让人物透出）
                      Positioned.fill(
                        child: GestureDetector(
                          onTap: () => _focusNode.unfocus(),
                          child: DashedContainer(
                            borderColor: AppTheme.bamboo.withValues(alpha: 0.5),
                            borderRadius: 0,
                            backgroundColor: isDark
                                ? Colors.black.withValues(alpha: 0.34)
                                : AppTheme.bamboo.withValues(alpha: 0.06),
                            padding: EdgeInsets.zero,
                            child: (messages.isEmpty &&
                                    !(status == ConversationStatus.writing &&
                                        (chatState.currentText?.isNotEmpty ??
                                            false)))
                                ? const SizedBox.shrink()
                                : _buildLetterList(chatState, status),
                          ),
                        ),
                      ),

                      // 空状态提示：放在输入框上方（主屏底部），而不是屏幕中央。
                      if (messages.isEmpty &&
                          !(status == ConversationStatus.writing &&
                              (chatState.currentText?.isNotEmpty ?? false)))
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _buildEmptyHint(isDark, status),
                          ),
                        ),
                    ],
                  ),
                ),
                _buildInputArea(status, chatState.errorMessage),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ━━━ 顶栏 ━━━

  Widget _buildTopBar(bool isDark) {
    // 顶栏作为透明 overlay：不设置背景色，让下方 Live2D 模型透出来。
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          // 菜单入口：保留，但不再放 logo
          GestureDetector(
            onTap: () => MenuPanel.show(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isDark ? Colors.black : Colors.white)
                    .withValues(alpha: 0.45),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.menu, size: 20, color: Colors.grey.shade600),
            ),
          ),
          const Spacer(),
          _buildStatusBadge(),
          const SizedBox(width: 12),
          // 设置按钮也加半透明底，避免在复杂模型背景上看不清
          Container(
            decoration: BoxDecoration(
              color: (isDark ? Colors.black : Colors.white)
                  .withValues(alpha: 0.45),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: () => SettingsSheet.show(context),
              icon: Icon(
                Icons.settings_outlined,
                size: 22,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    final status = ref.watch(conversationStatusProvider);
    final chatState = ref.watch(chatNotifierProvider);

    // 错误优先显示
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

    // 空闲状态不需要状态徽章，保持顶栏简洁
    if (status == ConversationStatus.idle) {
      return const SizedBox.shrink();
    }

    final label = switch (status) {
      ConversationStatus.idle     => '',
      ConversationStatus.thinking => '在想',
      ConversationStatus.writing => '在写',
      ConversationStatus.speaking => '在说',
    };

    final color = switch (status) {
      ConversationStatus.idle     => AppTheme.bambooDeep,
      ConversationStatus.thinking => const Color(0xFFB8A07A),
      ConversationStatus.writing  => AppTheme.bambooDeep,
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

  // ━━━ 空状态提示 ━━━

  /// 空状态时显示在输入框上方的轻提示（而不是屏幕中央），
  /// 避免遮挡居中的 Live2D 角色。
  Widget _buildEmptyHint(bool isDark, ConversationStatus status) {
    final label = status == ConversationStatus.idle ? '竹笌在这里' : '竹笌在等你';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: (isDark ? Colors.black : Colors.white)
            .withValues(alpha: 0.55),
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

  // ━━━ 信纸列表 ━━━

  Widget _buildLetterList(ChatState chatState, ConversationStatus status) {
    final messages = chatState.messages;
    // 打字中且已有输出片段：在末尾追加一条"正在输入"的临时条目，
    // 让 SSE 流式文字实时可见（否则只有 done 后整段突然出现）。
    final typing = status == ConversationStatus.writing &&
        (chatState.currentText?.isNotEmpty ?? false);
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      itemCount: messages.length + 1 + (typing ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == 0) return const SizedBox(height: 40);
        final msgIndex = index - 1;
        if (typing && msgIndex == messages.length) {
          return _LetterEntry.typing(chatState.currentText!);
        }
        return _LetterEntry(message: messages[msgIndex]);
      },
    );
  }

  // ━━━ 输入区 ━━━

  Widget _buildInputArea(ConversationStatus status, String? errorMessage) {
    final isWorking =
        status == ConversationStatus.thinking ||
        status == ConversationStatus.writing;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 思考中提示
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: isWorking ? _buildThinkingIndicator() : const SizedBox.shrink(),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ImagePickerButton(onImagePicked: _onImagePicked),
                  VoiceButton(),
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
                          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                          borderSide: BorderSide(
                            color: Theme.of(context).dividerColor,
                            width: 0.5,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                          borderSide: BorderSide(
                            color: Theme.of(context).dividerColor,
                            width: 0.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
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
              for (int i = 0; i < 3; i++)
                _Dot(delay: i, anim: _thinkingController.value),
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
// 消息条目
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _LetterEntry extends StatelessWidget {
  final entities.Message message;

  const _LetterEntry({required this.message});

  /// 打字中临时条目：展示 SSE 正在流式输出的文字 + 打字光标。
  _LetterEntry.typing(String text)
      : message = entities.Message(
          id: '__typing__',
          role: 'assistant',
          content: text,
          timestamp: DateTime.now(),
          isStreaming: true,
        );

  bool get isUser => message.role == 'user';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
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
              maxWidth: MediaQuery.of(context).size.width * 0.72,
            ),
            decoration: isUser
                ? null
                : BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: AppTheme.bambooDeep.withValues(alpha: 0.28),
                        width: 1.5,
                        strokeAlign: BorderSide.strokeAlignInside,
                      ),
                    ),
                  ),
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              message.content,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          if (message.isStreaming)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: _TypingCursor(),
            ),
        ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 打字光标
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _TypingCursor extends StatefulWidget {
  @override
  State<_TypingCursor> createState() => _TypingCursorState();
}

class _TypingCursorState extends State<_TypingCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => Container(
        width: 2,
        height: 16,
        color: AppTheme.bambooDeep.withValues(alpha: _c.value),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 思考中的三个点
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _Dot extends StatelessWidget {
  final int delay;
  final double anim;

  const _Dot({required this.delay, required this.anim});

  @override
  Widget build(BuildContext context) {
    final offset = (anim + delay * 0.33) % 1.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Container(
        width: 4,
        height: 4,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFB8A07A).withValues(alpha: 0.3 + offset * 0.5),
        ),
      ),
    );
  }
}
