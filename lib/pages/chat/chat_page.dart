// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 竹笌主页 - 信纸式对话
//
// 新架构（v2）：
//   UI → ChatNotifier → ChatRepository → BackendApiDataSource → 后端
//
// 状态机：idle → thinking → writing → speaking → idle
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_live2d/flutter_live2d.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../settings/settings_sheet.dart';
import '../settings/menu_panel.dart';
import '../../providers/app_providers_legacy.dart' as old_msg;
import '../../presentation/providers/app_providers.dart' as old_providers;
import '../../domain/entities/entities.dart' as entities;
import '../../presentation/providers/app_providers.dart' as new_providers;
import '../../presentation/providers/chat_provider.dart';
import '../../domain/entities/emotion.dart';
import '../../widgets/live2d_controller.dart';
import '../../widgets/live2d_widget.dart';
import '../../widgets/vrm_avatar_view.dart';
import '../../widgets/voice_button.dart';
import '../../widgets/image_picker_button.dart';
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
    _thinkingController =
        AnimationController(
          duration: const Duration(milliseconds: 1200),
          vsync: this,
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            _thinkingController.forward(from: 0);
          }
        });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 初始化 Live2D（仅在使用 2D 角色时；3D 人形不需要）
      if (!kUseVrmAvatar) {
        ref.read(old_providers.live2dControllerProvider).init();
      }

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
        final prevLast = prev?.messages.isNotEmpty == true
            ? prev!.messages.last
            : null;
        final nextLast = next.messages.isNotEmpty ? next.messages.last : null;
        // 仅当新增了一条 assistant 消息时才朗读，
        // 避免 thinking/writing 等状态变化重复触发
        if (nextLast != null &&
            nextLast.role == 'assistant' &&
            prevLast?.id != nextLast.id) {
          _speakReply(nextLast.content, emotion: nextLast.emotion);
        }
      });
    });
  }

  // ━━━ TTS 朗读 ━━━

  /// 触发竹笌回复的语音朗读（语音陪聊核心能力）。
  /// - 按设置页的 TTS 模式选择 MiniMax / 系统 TTS；
  /// - MiniMax 未配置或失败时自动降级到系统 TTS，保证一定出声；
  /// - 朗读期间同步 Live2D 的「说话」动画。
  Future<void> _speakReply(String text, {String? emotion}) async {
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
          await ref
              .read(old_providers.ttsServiceProvider)
              .speak(trimmed, emotion: emotion);
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
      case 'happy':
        ctrl.setEmotion('happy');
      case 'sad':
        ctrl.setEmotion('sad');
      case 'angry':
        ctrl.setEmotion('angry');
      case 'surprised':
        ctrl.setEmotion('surprised');
      case 'anxious':
        ctrl.setEmotion('anxious');
      default:
        ctrl.setEmotion('neutral');
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
      SnackBar(content: Text('已选择图片：${path.split('/').last}（多模态发送待接入）')),
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
    final l2dCtrl = ref.watch(old_providers.live2dControllerProvider);
    final Live2DViewController live2dViewController = l2dCtrl.viewController;

    final messages = chatState.messages;

    return Scaffold(
      // 聊天页背景透明，让 Live2D 平台视图作为全屏底层透出来，
      // 顶栏/输入区等 UI 只是半透明叠加层。
      // 禁止 Scaffold 随键盘自动 resize，避免键盘弹出时压缩 Live2D 视口导致人物偏移。
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 1. Live2D 整屏放在 Stack 底层；flutter_live2d 用 HybridComposition
          //    把原生 GL 视图合成在 Flutter 之上，所以这一层全屏就让人物成为
          //    背景。消息区/输入区靠几何遮挡 + 半透明磨砂浮层叠在上面（见区块 2/3）。
          // 1. 底层柔和背景：与 Live2D 默认底色 (0xFFEDF7F0) 一致，
          //    人物在全屏内无规则游走时，露出/移过的背景无缝衔接。
          const Positioned.fill(child: ColoredBox(color: Color(0xFFEDF7F0))),

          // 1.5 漂移的 Live2D：人物在整屏范围内无规则缓慢游走，
          //     叠加模型自带 Idle 微动 + 主动小动作，显得活泼自然。
          _WanderingLive2D(),

          // 2. 消息区：不要任何外层容器（虚线框/磨砂玻璃/圆角卡片），让气泡
          //    直接浮在 Live2D 全屏背景之上 —— 用户反馈外框挡住人物。
          //    仅保留：占位（输入框上方的让位）+ 收键盘手势 + ListView 内部 padding。
          Positioned(
            bottom: 140, // 紧贴输入区上方
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.38,
            child: GestureDetector(
              // 用户点消息区空白处收起键盘（不再有外框收焦点时）
              behavior: HitTestBehavior.opaque,
              onTap: () => _focusNode.unfocus(),
              child:
                  (messages.isEmpty &&
                      !(status == ConversationStatus.writing &&
                          (chatState.currentText?.isNotEmpty ?? false)))
                  ? _buildEmptyOrErrorPlaceholder(chatState, isDark)
                  : _buildLetterList(chatState, status),
            ),
          ),
          // 3. 顶栏 + 输入区：SafeArea 保证不被状态栏/导航栏遮挡，
          //    绘制在虚线框之上。
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(isDark),
                const Spacer(),
                // 输入区监听模型就绪状态，「竹笌在这里」只在模型未加载/未就绪时
                // 紧贴输入框上方显示；模型加载成功后消失，不遮挡人物。
                ListenableBuilder(
                  listenable: live2dViewController,
                  builder: (context, _) {
                    final state = live2dViewController.value;
                    // 3D 人形（model_viewer_plus）一旦构建即视为就绪；
                    // 2D 仍按 Live2D 控制器状态判断。
                    final modelReady = kUseVrmAvatar
                        ? true
                        : (state.isAttached &&
                              !state.isLoadingModel &&
                              state.loadedModel != null &&
                              state.lastError == null);
                    return _buildInputArea(
                      status,
                      chatState.errorMessage,
                      isDark,
                      modelReady,
                      messages,
                      chatState,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ━━━ 顶栏 ━━━

  Widget _buildTopBar(bool isDark) {
    // 顶栏作为透明 overlay：不设置任何背景/圆底，只保留带阴影的线型图标，
    // 让 Live2D 人物/模型从图标后面完全透出来。
    // 情绪胶囊：竹笌当前情绪（非「平静」时才显示，避免空状态干扰）
    final currentEmotion = ref.watch(currentEmotionProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          // 左上角：竹笌立体吉祥物 logo（点击仍打开菜单面板），无圆底保持顶栏透明
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
          // 情绪胶囊（仅非平静时显示）
          if (currentEmotion != null && currentEmotion.emotion != 'neutral')
            _buildEmotionChip(currentEmotion.emotion),
          const Spacer(),
          _buildStatusBadge(),
          const SizedBox(width: 12),
          // 音乐狗子入口（Phase 1 新增：宠物状态 + 音乐创作）
          GestureDetector(
            onTap: () => context.push('/pet'),
            child: const _TopIcon(icon: Icons.pets),
          ),
          const SizedBox(width: 12),
          // 设置按钮
          GestureDetector(
            onTap: () => SettingsSheet.show(context),
            child: const _TopIcon(icon: Icons.settings_outlined),
          ),
        ],
      ),
    );
  }

  // ━━━ 情绪胶囊 ━━━

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
                Shadow(
                  color: Colors.black45,
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
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

  // ━━━ 空状态提示 ━━━

  /// 模型未就绪时显示在输入框上方的轻提示；模型加载成功后立即消失，
  /// 不遮挡正常显示的人物。
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

  // ━━━ 空状态 / 错误占位 ━━━

  /// 消息列表为空时的占位：错误时显示「竹笌连不上 + 错误详情」，
  /// 无错误时显示「竹笌在这里」轻提示。两者都在虚线消息框内（输入框上方），
  /// 避免「出错了」徽章独自飘在顶栏让用户感觉聊天错位。
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
    // 打字中且已有输出片段：在末尾追加一条"正在输入"的临时条目，
    // 让 SSE 流式文字实时可见（否则只有 done 后整段突然出现）。
    final typing =
        status == ConversationStatus.writing &&
        (chatState.currentText?.isNotEmpty ?? false);
    return ListView.builder(
      controller: _scrollController,
      // 消息区域已挪到底部（输入框上方），不再预留顶栏空间。
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      // 顶部 +1 是给一个 8px 间距（避免首条气泡贴边）。
      // 错误提示统一走顶部「出错了」徽章（_buildStatusBadge），不
      // 再在消息区中央叠 banner——免得挡住 Live2D 人物。
      itemCount: messages.length + 1 + (typing ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == 0) return const SizedBox(height: 8);
        final msgIndex = index - 1;
        if (typing && msgIndex == messages.length) {
          return _LetterEntry.typing(chatState.currentText!);
        }
        return _LetterEntry(
          message: messages[msgIndex],
          distanceFromBottom: messages.length - msgIndex, // 1 = 最新
        );
      },
    );
  }

  // ━━━ 输入区 ━━━

  Widget _buildInputArea(
    ConversationStatus status,
    String? errorMessage,
    bool isDark,
    bool modelReady,
    List<entities.Message> messages,
    ChatState chatState,
  ) {
    final isWorking =
        status == ConversationStatus.thinking ||
        status == ConversationStatus.writing;

    // 手动跟随键盘高度上移输入区；Scaffold 已禁止自动 resize，
    // 避免键盘弹出时压缩 Live2D 视口导致人物偏移。
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      // 输入区透明叠加在 Live2D 全屏背景之上（不做磨砂），仅保留一条
      // 极细的顶部分隔线区分输入区与上方消息浮层。
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
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
              // 模型未就绪时的轻提示：只在加载/未加载时显示，模型出来即消失。
              if (!modelReady &&
                  messages.isEmpty &&
                  !(status == ConversationStatus.writing &&
                      (chatState.currentText?.isNotEmpty ?? false)))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildEmptyHint(isDark, status),
                ),
              // 思考中提示
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: isWorking
                    ? _buildThinkingIndicator()
                    : const SizedBox.shrink(),
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
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusXl,
                          ),
                          borderSide: BorderSide(
                            color: Theme.of(context).dividerColor,
                            width: 0.5,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusXl,
                          ),
                          borderSide: BorderSide(
                            color: Theme.of(context).dividerColor,
                            width: 0.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusXl,
                          ),
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
// 顶栏图标
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// 顶栏图标：去掉圆底/背景，用白色图标 + 深色投影保证在任意模型背景上都可见。
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

  /// 这条消息距离列表底部多远（1 = 最新，n = 最旧）。
  /// 用于「互动三条后渐隐」：最近 3 条完全不透明，更早的逐条变淡。
  final int distanceFromBottom;

  const _LetterEntry({required this.message, required this.distanceFromBottom});

  /// 打字中临时条目：展示 SSE 正在流式输出的文字 + 打字光标。
  _LetterEntry.typing(String text)
    : message = entities.Message(
        id: '__typing__',
        role: 'assistant',
        content: text,
        timestamp: DateTime.now(),
        isStreaming: true,
      ),
      // 正在输入的条目视为最新，保持完全不透明。
      distanceFromBottom = 1;

  bool get isUser => message.role == 'user';

  /// 根据距离底部的差值计算渐隐 alpha，并用 AnimatedOpacity 平滑过渡。
  Widget _buildEntry(Widget realContent) {
    // 最近 3 条（distanceFromBottom 1/2/3）始终完全不透明。
    if (distanceFromBottom <= 3) {
      return AnimatedOpacity(
        opacity: 1.0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        child: realContent,
      );
    }
    const double step = 0.25;
    final double alpha = (1.0 - step * (distanceFromBottom - 3)).clamp(
      0.18,
      1.0,
    );
    // 第4条 0.75 / 第5条 0.5 / 第6条 0.25 / 更旧 clamp 在 0.18（保证可读）。
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
        crossAxisAlignment: isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
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
          // 聊天气泡：用户（我）竹笌绿实底 + 白字靠右；AI（竹笌）浅白底 + 深字靠左。
          // 圆角 + 一圈细边 + 轻投影，从原来的「左侧竖线半透明块」升级为真正的气泡。
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.62,
            ),
            decoration: BoxDecoration(
              color: isUser
                  ? AppTheme.bambooDeep.withValues(alpha: 0.92)
                  : Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isUser
                    ? AppTheme.bambooDeep.withValues(alpha: 0.92)
                    : AppTheme.bambooDeep.withValues(alpha: 0.18),
                width: 1,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(0, 0, 0, 0.08),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            child: Text(
              message.content,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isUser ? Colors.white : null,
              ),
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
    return _buildEntry(realContent);
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

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 全屏无规则游走的 Live2D 角色
//
// 把 Live2D 平台视图包进一个缓慢漂移的 Transform.translate，让竹笌在
// 整屏范围内无规则地游走：停留 3.5~8.5s → 随机选一个新位点 → 4~8s 平滑
// 漂过去（easeInOutSine 缓动，自然不机械）。底层已由同色背景 (0xFFEDF7F0)
// 铺满，人物飘过时露出/移过的背景无缝衔接。
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _WanderingLive2D extends ConsumerStatefulWidget {
  const _WanderingLive2D();

  @override
  ConsumerState<_WanderingLive2D> createState() => _WanderingLive2DState();
}

class _WanderingLive2DState extends ConsumerState<_WanderingLive2D>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(vsync: this);
  final Random _rnd = Random();

  Size? _screen;
  Offset _offset = Offset.zero;
  Timer? _timer;
  Animation<Offset>? _anim;
  Animation<Offset>? _prevAnim;
  double _bobY = 0.0; // 步态颠簸的当前 Y 位移（向上为正）

  // 步态垂直颠簸：模拟"踏步走"的上下颠，让漂移看起来像走路而不是滑过
  // 0.85 Hz 步态 × 2 = 1.7 Hz 颠簸（每步一次颠），振幅 22px（2400 高屏上明显可见）
  Timer? _bobTimer;
  double _bobT = 0.0;
  static const double _bobAmp = 36.0;
  static const double _gaitHz = 0.85;

  // 3D 模式 keep-alive：Android VirtualDisplay 平台视图下 model_viewer_plus 的
  // WebGL canvas 会在 ~1.5s 后冻结（surface 不再被 Flutter 触发重绘，rAF 也不出新帧）。
  // 用 10fps 极轻微位置振荡（±0.5px）持续触发 surface 失效，肉眼几乎不可见但可让
  // WebView 持续出帧。2D 模式不需要（HybridComposition + 30fps bob 已驱动平台视图）。
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
    // 步态颠簸：仅 2D 角色需要人工上下颠（30fps 更新 _bobY）。
    // 3D 走路动画自带上下颠，且不应以 30fps 重排 WebView（platform view），
    // 故 3D 模式跳过此定时器，_bobY 恒为 0。
    if (!kUseVrmAvatar) {
      _bobTimer = Timer.periodic(const Duration(milliseconds: 33), (timer) {
        if (!mounted) return;
        setState(() {
          _bobT += 0.033;
          // 0.5 - 0.5*cos(2*2*pi*f*t) 范围 0..1，2*gaitHz 频率
          final phase = 2 * 2 * pi * _gaitHz * _bobT;
          _bobY = _bobAmp * (0.5 - 0.5 * cos(phase));
        });
      });
    } else {
      // 3D keep-alive：10fps 极轻微位置抖动，让 platform view 持续触发 surface 重绘，
      // 避免 WebGL canvas 在 VirtualDisplay 下冻结。振幅 0.5px 肉眼几乎不可见。
      _keepAliveT = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (!mounted) return;
        setState(() => _keepAlivePhase += 0.1);
      });
    }
  }

  void _scheduleNextDrift() {
    if (!mounted) return;
    // 停留 3.5~8.5s 后，向下一个随机位点平滑漂过去
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
    // 人物中心在屏幕范围内无规则偏移：
    // 水平 ±0.42·sw，垂直 ±0.30·sh（留出顶栏/输入区缓冲，避免被 UI 完全吃掉）。
    // 幅度控制：人物在屏幕中部 50% 范围内无规则游走，
    // 留足边距避免被顶栏/输入区完全遮住，也降低 HybridComposition
    // platform view 贴边裁剪导致的渲染抖动。
    final target = Offset(
      (_rnd.nextDouble() * 2 - 1) * sw * 0.28,
      (_rnd.nextDouble() * 2 - 1) * sh * 0.22,
    );

    _prevAnim?.removeListener(_onAnimTick);
    _anim = Tween<Offset>(
      begin: _offset,
      end: target,
    ).animate(CurvedAnimation(parent: _drift, curve: Curves.easeInOutSine));
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
    _bobTimer?.cancel();
    _keepAliveT?.cancel();
    _prevAnim?.removeListener(_onAnimTick);
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 3D 人形用 model_viewer_plus 渲染 GLB（真骨骼走路）；
    // 2D 才需要 Live2D 唇形参数驱动。
    final Widget child;
    if (kUseVrmAvatar) {
      child = const VrmAvatarView();
    } else {
      final live2dCtrl = ref.watch(old_providers.live2dControllerProvider);
      final lipSync = ref.watch(new_providers.lipSyncStreamProvider);
      lipSync.whenData((mouth) {
        live2dCtrl.viewController.setParameter(
          'ParamMouthOpenY',
          mouth.clamp(0.0, 0.75),
        );
      });
      child = ZhuaLive2DWidget(
        controller: live2dCtrl.viewController,
        onTap: () {},
      );
    }
    // 用 Positioned(left,top) 替代 Transform.translate 驱动漂移：
    // Positioned 走 layout 阶段，platform view 的 surface 合成更稳；
    // 配合 RepaintBoundary 隔离重绘，避免动画中渲染抖动（蓝影/半透明）。
    return Positioned(
      left: _offset.dx,
      // 步态颠簸：仅 2D 需要人工上下颠；3D 走路动画自带上下颠，_bobY 置 0。
      // 3D 额外叠 ±0.5px@~1.9Hz keep-alive 振荡，让 platform view 持续重绘避免 WebGL 冻结。
      top:
          _offset.dy -
          (kUseVrmAvatar ? (sin(_keepAlivePhase * 12.0) * 0.5) : _bobY),
      child: SizedBox(
        width: MediaQuery.of(context).size.width,
        // 3D 区域限制为屏高 78%：Hybrid Composition 下 SurfaceView 会盖住
        // 底部的 Flutter 聊天输入栏，缩 3D 高度留出空间给输入框不被压。
        height: MediaQuery.of(context).size.height * 0.78,
        child: child,
      ),
    );
  }
}
