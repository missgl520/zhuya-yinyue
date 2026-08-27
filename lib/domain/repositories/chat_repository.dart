// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 对话仓库接口（Chat Repository Interface）
//
// 位于：domain/repositories/chat_repository.dart
// 职责：定义"数据要什么"，不管"怎么拿"
//
// 为什么要有这层？
//   UI 层只关心"我要一条消息"，不关心这条消息是从网络来的还是本地缓存来的。
//   Repository 接口就是这个契约。
//
// 实现关系：
//   UI/Provider
//     → ChatRepository（接口，domain 层）
//       → ChatRepositoryImpl（实现，data 层）
//         → ChatService（SSE 解析 + HTTP）
//           → 后端 /chat/v2
//
// 这就是"依赖倒置"：domain 层不依赖 data 层，而是 data 层依赖 domain 层定义的接口。
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import '../entities/message.dart';

/// 对话事件类型（枚举）
/// 流式输出时，后端会推送不同类型的事件
enum ChatEventType {
  /// token 事件：AI 正在逐字输出
  token,

  /// 完整回复结束
  done,

  /// 错误发生
  error,

  /// 情绪识别结果
  emotion,

  /// 好感度变化
  affinity,

  /// 离线已保存（消息进发件箱，等待联网后自动同步）
  offlineSaved,
}

/// 对话事件（流式事件载体）
/// 后端 SSE 流推送的每条消息，都包装成这个格式
class ChatEvent {
  final ChatEventType type;
  final String? token; // type=token 时：当前新增的文字片段
  final String? emotion; // type=emotion 时：情绪标签
  final Map<String, dynamic>? affinity; // type=affinity 时：好感度数据
  final String? error; // type=error 时：错误信息
  final String? clientMsgId; // type=offlineSaved 时：本条消息的幂等 id

  const ChatEvent({
    required this.type,
    this.token,
    this.emotion,
    this.affinity,
    this.error,
    this.clientMsgId,
  });

  /// 工厂方法：创建一个 token 事件
  factory ChatEvent.token(String text) =>
      ChatEvent(type: ChatEventType.token, token: text);

  /// 工厂方法：结束事件
  factory ChatEvent.done() => const ChatEvent(type: ChatEventType.done);

  /// 工厂方法：错误事件
  factory ChatEvent.error(String message) =>
      ChatEvent(type: ChatEventType.error, error: message);

  /// 工厂方法：情绪事件
  factory ChatEvent.emotion(String emotionLabel) =>
      ChatEvent(type: ChatEventType.emotion, emotion: emotionLabel);

  /// 工厂方法：离线已保存事件（消息进发件箱，待联网同步）
  factory ChatEvent.offlineSaved(String clientMsgId) =>
      ChatEvent(type: ChatEventType.offlineSaved, clientMsgId: clientMsgId);
}

/// 对话仓库接口
///
/// UI 层通过这个接口跟后端对话，
/// 具体怎么实现（SSE / HTTP轮询 / 缓存），由 data 层决定。
abstract class ChatRepository {
  /// 发送消息并接收流式回复
  ///
  /// 参数：
  ///   message     用户发送的消息
  ///   history     历史消息（用于上下文连贯）
  ///   systemPrompt 角色设定（可选，覆盖默认人格）
  ///
  /// 返回：Stream<ChatEvent>
  ///   异步流，后端推送 token 时立即下发，不需要等待完整回复
  Stream<ChatEvent> sendMessageStream({
    required String message,
    required List<Message> history,
    String? systemPrompt,
  });

  /// 单独检测情绪（不需要发起对话）
  Future<String> detectEmotion(String text);

  /// 获取当前好感度
  Future<dynamic> getAffinity();

  /// 检查后端是否在线
  Future<bool> isOnline();

  /// 从本地加载持久化的对话历史（离线优先：UI 先读本地立即显示）
  Future<List<Message>> loadLocalHistory({int limit = 200});

  /// 本地同步完成通知流（SyncEngine flush 成功后触发，供 UI 刷新）
  Stream<void> get localSyncStream;
}
