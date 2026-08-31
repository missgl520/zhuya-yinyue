// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 数据模型（Hive 序列化 / UI 状态用）
//
// 注意：此处的 Message 与 domain/entities/message.dart 是两个不同的类！
//   domain/entities/message.dart → 纯业务实体（无依赖）
//   本文件内的 Message       → 有 toJson/fromJson（用于 Hive 持久化）
// 2026-08-31 从 providers/app_providers_legacy.dart 迁移而来。
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// 消息数据模型（Hive 存储专用）
class Message {
  final String id;
  final String role;
  final String content;
  final DateTime timestamp;
  final bool isStreaming;

  const Message({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.isStreaming = false,
  });

  /// 从 JSON（Hive 存储的格式）恢复对象
  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String? ?? '',
      role: json['role'] as String? ?? 'user',
      content: json['content'] as String? ?? '',
      timestamp: json['timestamp'] is int
          ? DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int)
          : DateTime.now(),
      isStreaming: json['isStreaming'] as bool? ?? false,
    );
  }

  /// 序列化成 JSON（Hive 存储用）
  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'content': content,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'isStreaming': isStreaming,
      };

  /// 克隆（Immutable 模式）
  Message copyWith({String? content, bool? isStreaming}) => Message(
        id: id,
        role: role,
        content: content ?? this.content,
        timestamp: timestamp,
        isStreaming: isStreaming ?? this.isStreaming,
      );
}

/// 好感度数据（Hive 不存，由后端管理，这里是 UI 状态用）
class AffinityData {
  final double trust; // 信任值（0-100）
  final double intimacy; // 亲密度（0-100）
  final double familiarity; // 熟悉度（0-100）
  final int totalInteractions; // 累计对话轮数
  final int streakDays; // 连续签到天数
  final String level; // 关系等级文字

  const AffinityData({
    this.trust = 30,
    this.intimacy = 20,
    this.familiarity = 5,
    this.totalInteractions = 0,
    this.streakDays = 0,
    this.level = '陌生人',
  });

  /// 好感度总分（用于徽章/进度展示）
  double get total => (trust + intimacy + familiarity) / 3;

  /// 克隆（修改字段）
  AffinityData copyWith({
    double? trust,
    double? intimacy,
    double? familiarity,
    int? totalInteractions,
    int? streakDays,
    String? level,
  }) =>
      AffinityData(
        trust: trust ?? this.trust,
        intimacy: intimacy ?? this.intimacy,
        familiarity: familiarity ?? this.familiarity,
        totalInteractions: totalInteractions ?? this.totalInteractions,
        streakDays: streakDays ?? this.streakDays,
        level: level ?? this.level,
      );
}

/// 情绪识别结果（后端返回）
class EmotionResult {
  final String emotion; // 情绪标签：happy / sad / angry / neutral 等
  final double confidence; // 置信度（0.0 ~ 1.0）
  final DateTime timestamp; // 识别时间

  const EmotionResult({
    required this.emotion,
    this.confidence = 0.5,
    required this.timestamp,
  });
}

/// 竹笌对话状态
enum ZhuaStatus {
  idle, // 空闲，等待用户输入
  thinking, // 思考中（后端推理中）
  writing, // 打字中（流式输出中）
  speaking, // 播报中（TTS 播放中）
}
