// 对话消息列表（StateNotifier + Hive 持久化）—— 从 legacy providers 迁移而来。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'models.dart';

/// 对话消息列表
/// 启动时从 Hive 恢复历史，运行时追加新消息
final messagesProvider = StateNotifierProvider<MessagesNotifier, List<Message>>(
  (ref) {
    final box = Hive.box('messages');
    final messages = <Message>[];

    // 启动时：从 Hive 逐条读取并按时间排序
    for (final key in box.keys) {
      try {
        final data = Map<String, dynamic>.from(box.get(key));
        messages.add(Message.fromJson(data));
      } catch (_) {
        // 损坏的数据跳过
      }
    }

    messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return MessagesNotifier(messages);
  },
);

class MessagesNotifier extends StateNotifier<List<Message>> {
  final Box _box;

  MessagesNotifier(super.initialState) : _box = Hive.box('messages');

  /// 追加消息（同时写入 Hive）
  void addMessage(Message msg) {
    state = [...state, msg];
    _box.put(msg.id, msg.toJson());
  }

  /// 更新消息内容（用于流式输出时逐字追加）
  void updateMessage(String id, String content, {bool? isStreaming}) {
    state = state.map((m) {
      if (m.id == id)
        return m.copyWith(content: content, isStreaming: isStreaming);
      return m;
    }).toList();
    // Hive 里也更新
    final idx = state.indexWhere((m) => m.id == id);
    if (idx >= 0) _box.put(id, state[idx].toJson());
  }

  /// 删除消息
  void removeMessage(String id) {
    state = state.where((m) => m.id != id).toList();
    _box.delete(id);
  }

  /// 清空所有消息
  void clear() {
    state = [];
    _box.clear();
  }
}
