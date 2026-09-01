// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 对话仓库实现（Chat Repository Impl）
//
// 位于：data/repositories/chat_repository_impl.dart
// 职责：实现 ChatRepository 接口，对话统一走 Agnes AI，
//       情绪/好感度由 AgnesService 本地分析，不再依赖自建后端。
//
// 架构说明（2026-09-01 重构）：
//   - 对话主后端：Agnes 2.5 Pro（AgnesService.chatStream）
//   - 情绪检测：AgnesService 本地关键词分析
//   - 好感度：AgnesService 本地积分（0~100）
//   - 离线优先：消息先写 Hive，SyncEngine 处理网络同步
//   - 自建后端（BackendService）不再参与对话流程
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../core/services/agnes_service.dart';
import '../../domain/entities/message.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/chat_local_data_source.dart';
import '../../core/sync/sync_engine.dart';

class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl() {
    // 启动时从 Hive 加载 Agnes API Key 并注入
    try {
      final box = Hive.box('settings');
      final key = box.get('agnesApiKey', defaultValue: '') as String?;
      if (key != null && key.isNotEmpty) {
        AgnesService.instance.setApiKey(key);
      }
      final useCN = box.get('agnesUseCN', defaultValue: true) as bool;
      AgnesService.instance.setUseCN(useCN);
    } catch (_) {}
  }

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

    // 2) 历史消息转成 Agnes 需要的格式 [{role, content}, ...]
    final AgnesHistory = history.map((m) => {
          'role': m.role,
          'content': m.content,
        }).toList();

    // 3) 监听 Agnes 流式输出，转为 ChatEvent
    await for (final event in AgnesService.instance.chatStream(
      message: message,
      history: AgnesHistory,
      systemPrompt: systemPrompt,
    )) {
      switch (event) {
        case AgnesTextEvent(:final text):
          yield ChatEvent.token(text);

        case AgnesEmotionEvent(:final emotion):
          yield ChatEvent.emotion(emotion);

        case AgnesAffinityEvent(:final affinity):
          yield ChatEvent(
            type: ChatEventType.affinity,
            affinity: {
              'delta': affinity.delta,
              'total': affinity.total,
            },
          );

        case AgnesDoneEvent():
          // 完整回复落本地
          _local.appendAssistantMessage(
            clientMsgId: clientMsgId,
            content: '', // 实际内容由调用方从 token 累积
          );
          _local.markUserSynced(clientMsgId);
          yield ChatEvent.done();

        case AgnesErrorEvent(:final message):
          // 网络类错误 → 进发件箱，不报硬错
          if (_isRecoverable(message)) {
            _local.enqueueOutbox(clientMsgId: clientMsgId, message: message);
            yield ChatEvent.offlineSaved(clientMsgId);
          } else {
            yield ChatEvent.error(message);
          }
      }
    }
  }

  /// 网络类 / 临时错误 → 进发件箱重试；
  /// 其他错误 → 硬报错。
  bool _isRecoverable(String err) {
    return err.contains('网络') ||
        err.contains('超时') ||
        err.contains('连接') ||
        err.contains('DNS') ||
        err.contains('connect');
  }

  @override
  Future<String> detectEmotion(String text) async {
    return AgnesService.instance.detectEmotion(text).label;
  }

  @override
  Future<dynamic> getAffinity() async {
    return {'total': AgnesService.instance.affinity};
  }

  @override
  Future<bool> isOnline() async {
    // Agnes 是云端 API，能发请求即为在线
    try {
      await AgnesService.instance.chat(message: 'ping', history: []);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<Message>> loadLocalHistory({int limit = 200}) {
    return _local.getRecentHistory(limit: limit);
  }

  @override
  Stream<void> get localSyncStream => SyncEngine.instance.syncStream;
}
