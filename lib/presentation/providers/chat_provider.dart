// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 聊天状态管理（Chat Provider）
//
// 位于：presentation/providers/chat_provider.dart
// 职责：管理对话状态机，处理流式对话、情绪、好感度
//
// 架构思路（Riverpod StateNotifier）：
//   不是用 setState 那种"命令式"写法，
//   而是把状态和操作封装成"不可变对象 + 方法"，
//   类似 Redux 的单向数据流。
//
// 状态机（ConversationStatus）：
//   idle      → 空闲，等待用户输入
//   thinking  → 思考中（还没开始输出）
//   writing   → 正在打字（流式输出中）
//   speaking  → 正在语音播放
//
// 事件驱动：
//   用户发送消息 → idle → thinking → writing → idle
//   用户按住录音 → idle → speaking → idle
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/message.dart';
import '../../domain/entities/emotion.dart';
import '../../domain/entities/affinity.dart';
import '../../data/repositories/chat_repository_impl.dart';
import '../../domain/repositories/chat_repository.dart'; // ChatEventType
import '../../core/sync/sync_engine.dart';

// ════════════════════════════════════════════════════════════
// 状态类型定义
// ════════════════════════════════════════════════════════════

/// 对话状态枚举
enum ConversationStatus {
  /// 空闲：等待用户输入
  idle,

  /// 思考中：后端正在推理（还没开始输出文字）
  thinking,

  /// 打字中：后端正在流式输出文字
  writing,

  /// 播音中：竹笌正在播放 TTS 语音
  speaking,
}

// ════════════════════════════════════════════════════════════
// 状态类（不可变）
// ════════════════════════════════════════════════════════════

/// 对话状态数据（不可变类）
class ChatState {
  final ConversationStatus status; // 当前状态
  final List<Message> messages; // 消息历史
  final String? currentText; // 当前正在输出的文字（拼接中）
  final String? error; // 错误信息（null = 无错误）

  /// 错误信息别名（兼容旧代码 chat_page.dart）
  String? get errorMessage => error;
  final Emotion? currentEmotion; // 当前情绪
  final Affinity? affinity; // 好感度
  final bool isSpeaking; // 是否正在播放 TTS

  const ChatState({
    this.status = ConversationStatus.idle,
    this.messages = const [],
    this.currentText,
    this.error,
    this.currentEmotion,
    this.affinity,
    this.isSpeaking = false,
  });

  /// 空闲状态
  factory ChatState.idle() => const ChatState(status: ConversationStatus.idle);

  /// 克隆并修改字段
  ChatState copyWith({
    ConversationStatus? status,
    List<Message>? messages,
    String? currentText,
    String? error,
    Emotion? currentEmotion,
    Affinity? affinity,
    bool? isSpeaking,
  }) {
    return ChatState(
      status: status ?? this.status,
      messages: messages ?? this.messages,
      currentText: currentText ?? this.currentText,
      error: error ?? this.error,
      currentEmotion: currentEmotion ?? this.currentEmotion,
      affinity: affinity ?? this.affinity,
      isSpeaking: isSpeaking ?? this.isSpeaking,
    );
  }
}

// ════════════════════════════════════════════════════════════
// Provider
// ════════════════════════════════════════════════════════════

/// 聊天通知器（状态管理器）
///
/// 用法：
/// ```dart
/// ref.read(chatNotifierProvider.notifier).sendMessage('你好');
/// final status = ref.watch(chatNotifierProvider);  // 监听状态变化
/// ```
class ChatNotifier extends StateNotifier<ChatState> {
  ChatNotifier() : super(ChatState.idle()) {
    _repository = ChatRepositoryImpl();
    // 离线优先：本地同步完成后刷新当前消息列表
    SyncEngine.instance.syncStream.listen((_) => loadFromLocal());
    _loadInitial();
  }

  late final ChatRepositoryImpl _repository;

  /// 启动后从本地加载历史（离线优先：先显示本地，再后台同步）
  void _loadInitial() async {
    await loadFromLocal();
  }

  /// 从本地持久化重新载入消息列表（SyncEngine 同步完成后也会调用）
  Future<void> loadFromLocal() async {
    if (state.status != ConversationStatus.idle) return; // 不打断进行中的对话
    final local = await _repository.loadLocalHistory(limit: 200);
    if (local.isNotEmpty) {
      state = state.copyWith(
        messages: local,
        status: ConversationStatus.idle,
        currentText: null,
      );
    }
  }

  // ── 对话相关 ──────────────────────────────────────

  /// 发送消息（核心方法）
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    if (state.status != ConversationStatus.idle) return; // 防抖

    // 1. 追加用户消息
    final userMsg = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'user',
      content: text.trim(),
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      status: ConversationStatus.thinking,
      messages: [...state.messages, userMsg],
      currentText: '',
      error: null,
    );

    // 2. 流式接收竹笌回复
    String fullText = '';

    // history 不含「当前这条」用户消息：ChatService 会单独把 message 字段
    // 拼到请求体末尾，若这里再把当前消息塞进 history，后端会收到两份重复的
    // 当前用户消息，污染上下文。state.messages 末尾即刚加入的 userMsg。
    final history = state.messages.length > 1
        ? state.messages.sublist(0, state.messages.length - 1)
        : const <Message>[];

    await for (final event in _repository.sendMessageStream(
      message: text,
      history: history,
    )) {
      switch (event.type) {
        case ChatEventType.token:
          // token 事件：拼接文字，进入 writing 状态
          fullText += event.token ?? '';
          state = state.copyWith(
            status: ConversationStatus.writing,
            currentText: fullText,
          );
          break;

        case ChatEventType.emotion:
          // 情绪事件：更新情绪状态
          final emotionLabel = event.emotion ?? 'neutral';
          state = state.copyWith(
            currentEmotion: Emotion(emotion: emotionLabel),
          );
          break;

        case ChatEventType.affinity:
          // 好感度事件：更新好感度
          if (event.affinity != null) {
            state = state.copyWith(
              affinity: Affinity.fromJson(event.affinity!),
            );
          }
          break;

        case ChatEventType.done:
          // 完成：把当前文字存为正式消息，回到 idle
          final assistantMsg = Message(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            role: 'assistant',
            content: fullText,
            timestamp: DateTime.now(),
            emotion: state.currentEmotion?.emotion,
          );
          state = state.copyWith(
            status: ConversationStatus.idle,
            messages: [...state.messages, assistantMsg],
            currentText: null,
          );
          break;

        case ChatEventType.offlineSaved:
          // 已离线保存进发件箱，联网后自动同步：不报硬错，标记待同步
          state = state.copyWith(
            status: ConversationStatus.idle,
            messages: state.messages
                .map((m) => m.copyWith(pendingSync: true))
                .toList(),
          );
          break;

        case ChatEventType.error:
          // 错误：提示用户
          state = state.copyWith(
            status: ConversationStatus.idle,
            error: event.error,
          );
          break;
      }
    }
  }

  /// 取消当前对话（停止流式输出）
  void cancel() {
    state = state.copyWith(status: ConversationStatus.idle, currentText: null);
  }

  /// 清空对话历史
  void clearHistory() {
    state = ChatState.idle();
  }

  // ── 情绪相关 ──────────────────────────────────────

  /// 手动设置情绪（用于非对话场景）
  void setEmotion(String emotion) {
    state = state.copyWith(currentEmotion: Emotion(emotion: emotion));
  }

  /// 重置情绪（回到中性）
  void resetEmotion() {
    state = state.copyWith(currentEmotion: const Emotion(emotion: 'neutral'));
  }

  // ── TTS 播放状态 ──────────────────────────────────

  /// 开始 TTS 播放
  void startSpeaking() {
    state = state.copyWith(
      status: ConversationStatus.speaking,
      isSpeaking: true,
    );
  }

  /// 结束 TTS 播放
  void stopSpeaking() {
    state = state.copyWith(status: ConversationStatus.idle, isSpeaking: false);
  }
}

// ── 全局 Provider 声明 ─────────────────────────────────
// Riverpod 会自动管理生命周期，无需手动 dispose
final chatNotifierProvider = StateNotifierProvider<ChatNotifier, ChatState>((
  ref,
) {
  return ChatNotifier();
});

/// 当前情绪 Provider（方便单独监听）
final currentEmotionProvider = Provider<Emotion?>((ref) {
  return ref.watch(chatNotifierProvider).currentEmotion;
});

/// 好感度 Provider
final affinityProvider = Provider<Affinity?>((ref) {
  return ref.watch(chatNotifierProvider).affinity;
});

/// 对话状态 Provider（用于 UI 条件渲染）
final conversationStatusProvider = Provider<ConversationStatus>((ref) {
  return ref.watch(chatNotifierProvider).status;
});
