// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 对话仓库实现（Chat Repository Impl）
//
// 位于：data/repositories/chat_repository_impl.dart
// 职责：实现 ChatRepository 接口，把 SSE 流封装成 Repository 格式，
//       并落实"离线优先"——本地作为事实来源，远程失败则进发件箱。
//
// 离线优先改造点（对照文章）：
//   1) 每条消息生成 client_msg_id（幂等），贯穿整条链路；
//   2) 用户消息先乐观写本地 chat_history（pending_sync=1）；
//   3) 在线 → 流式接收，结束后把完整 AI 回复写本地；
//   4) 网络/临时错误 → 进 outbox，返回 offlineSaved 事件（不报硬错）；
//   5) SyncEngine 联网后自动 flush outbox，成功后标记已同步。
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'dart:async';
import 'package:uuid/uuid.dart';
import '../../core/services/backend_service.dart';
import '../../domain/entities/message.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/chat_local_data_source.dart';
import '../services/chat_service.dart';
import '../../core/sync/sync_engine.dart';

class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl({ChatService? service})
    : _service = service ?? ChatService();

  final ChatService _service;
  final ChatLocalDataSource _local = ChatLocalDataSource.instance;

  @override
  Stream<ChatEvent> sendMessageStream({
    required String message,
    required List<Message> history,
    String? systemPrompt,
  }) async* {
    final clientMsgId = const Uuid().v4();

    // 1) 乐观写本地：用户消息先落库（标记待同步）
    await _local.appendUserMessage(
      clientMsgId: clientMsgId,
      content: message,
      ts: DateTime.now(),
    );

    final controller = StreamController<ChatEvent>();
    final buf = StringBuffer();

    await _service.streamChat(
      message: message,
      history: history,
      systemPrompt: systemPrompt,
      clientMsgId: clientMsgId,
      onText: (token) {
        buf.write(token);
        controller.add(ChatEvent.token(token));
      },
      onEmotion: (emotion, confidence) {
        controller.add(ChatEvent.emotion(emotion));
      },
      onAffinity: (affinity) {
        controller.add(
          ChatEvent(type: ChatEventType.affinity, affinity: affinity),
        );
      },
      onDone: () {
        // 2) 完整 AI 回复落本地（与用户消息共享 client_msg_id）
        _local.appendAssistantMessage(
          clientMsgId: clientMsgId,
          content: buf.toString(),
        );
        _local.markUserSynced(clientMsgId);
        controller.add(ChatEvent.done());
        controller.close();
      },
      onError: (error) {
        if (_isRecoverable(error)) {
          // 3) 网络/临时错误：进发件箱，不报硬错
          _local.enqueueOutbox(clientMsgId: clientMsgId, message: message);
          controller.add(ChatEvent.offlineSaved(clientMsgId));
        } else {
          controller.add(ChatEvent.error(error));
        }
        controller.close();
      },
    );

    yield* controller.stream;
  }

  /// 网络类 / 临时错误 → 进发件箱重试；
  /// 认证 / 业务错误（如 401）→ 硬报错，需用户介入。
  bool _isRecoverable(String err) {
    if (err.contains('认证失败')) return false; // 401
    return err.contains('网络') ||
        err.contains('超时') ||
        err.contains('连接') ||
        err.contains('网关') ||
        err.contains('后端');
  }

  @override
  Future<String> detectEmotion(String text) {
    return _service.detectEmotion(text);
  }

  @override
  Future<dynamic> getAffinity() async {
    try {
      return await BackendService.instance.getAffinity();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> isOnline() {
    return _service.isOnline();
  }

  @override
  Future<List<Message>> loadLocalHistory({int limit = 200}) {
    return _local.getRecentHistory(limit: limit);
  }

  @override
  Stream<void> get localSyncStream => SyncEngine.instance.syncStream;
}
