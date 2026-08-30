// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 消息实体（Message Entity）
//
// 位于：domain/entities/message.dart
// 职责：描述一条对话消息的"长什么样"，与存储/传输无关
//
// 重要原则（Clean Architecture）：
// - 纯 Dart，无外部依赖（不 import flutter/http/hive）
// - 框架无关，可直接复制到任何项目使用
// - 不含序列化方法（toJson/fromJson），那是 Data 层的职责
//
// 字段说明：
//   id          消息唯一标识（UUID）
//   role        角色：'user' 用户 | 'assistant' 竹笌
//   content     消息正文
//   timestamp   时间戳（客户端本地时间）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/foundation.dart';

/// 一条对话消息的实体
///
/// 示例：
/// ```dart
/// final msg = Message(
///   id: 'msg-001',
///   role: 'user',
///   content: '你好呀竹笌',
///   timestamp: DateTime.now(),
/// );
/// ```
@immutable
class Message {
  /// 消息唯一标识
  final String id;

  /// 角色
  /// - 'user'       用户发送的消息
  /// - 'assistant'  竹笌回复的消息
  final String role;

  /// 消息正文内容
  final String content;

  /// 消息创建时间（本地时间，非 UTC）
  final DateTime timestamp;

  /// 竹笌是否正在"正在输入"中（流式输出时为 true）
  final bool isStreaming;

  /// 情绪标签（来自后端情绪识别）
  /// 例如：'happy' | 'sad' | 'angry' | 'neutral'
  final String? emotion;

  /// 好感度变化量（来自后端，本次交互对好感度的影响）
  final double affinityDelta;

  /// 是否等待后端同步（离线优先：用户消息发出但后端未收到时标记为 true）
  final bool pendingSync;

  const Message({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.isStreaming = false,
    this.emotion,
    this.affinityDelta = 0,
    this.pendingSync = false,
  });

  /// 是否为用户消息
  bool get isUser => role == 'user';

  /// 是否为竹笌消息
  bool get isAssistant => role == 'assistant';

  /// 是否正在流式输出中
  bool get isTyping => isStreaming && isAssistant;

  /// 打印用（调试）
  @override
  String toString() =>
      'Message(id=$id, role=$role, content=${content.length > 20 ? '${content.substring(0, 20)}...' : content})';

  /// 克隆并修改部分字段（Immutable 模式的惯用写法）
  Message copyWith({
    String? id,
    String? role,
    String? content,
    DateTime? timestamp,
    bool? isStreaming,
    String? emotion,
    double? affinityDelta,
    bool? pendingSync,
  }) {
    return Message(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isStreaming: isStreaming ?? this.isStreaming,
      emotion: emotion ?? this.emotion,
      affinityDelta: affinityDelta ?? this.affinityDelta,
      pendingSync: pendingSync ?? this.pendingSync,
    );
  }
}
