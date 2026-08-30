// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 全局状态 Providers（Riverpod）- Legacy 兼容版
//
// 位于：providers/app_providers_legacy.dart
//
// 本文件职责：
//   集中管理所有全局状态（providers），是 Flutter 端的状态中枢。
//
// 为什么叫 Legacy？
//   这是 v1 时代的产物，2026-08-06 重构后引入了新架构：
//   - 新代码请用 presentation/providers/chat_provider.dart（新状态机）
//   - 本文件保留是为了旧代码（menu_panel / settings_sheet 等）不需要改 import
//   - 两者共存，通过 app_providers.dart 统一导出
//
// Riverpod 核心概念：
//   Provider      → 只读状态（不可变）
//   StateProvider → 可写状态（简单值）
//   StateNotifierProvider → 可写状态（复杂对象 + 业务逻辑）
//
// Hive 持久化：
//   三个盒子（类似数据库表）：
//   - 'settings' : 主题/API Key/TTS开关/唤醒词等
//   - 'messages' : 对话历史（Message 对象序列化存储）
//   - 'memory'   : AI 长期记忆（SinoMem）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

// ━━━ 后端配置导出 ━━━
export '../core/config.dart' show BackendConfig;

// ━━━ Services ━━━
import '../core/services/backend_service.dart';
import '../core/services/agnes_service.dart';
import '../core/services/tts_service.dart';
import '../core/services/cartesia_tts_service.dart';
import '../core/services/mini_max_tts_service.dart';
import '../core/services/lip_sync_service.dart';
import '../core/services/asr_service.dart';
import '../core/services/memory_service.dart';
import '../widgets/live2d_controller.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 数据模型（Hive 序列化专用）
//
// 注意：这个 Message 和 domain/entities/message.dart 是两个不同的类！
//   domain/entity/message.dart → 纯业务实体（无依赖）
//   本文件内的 Message → 有 toJson/fromJson（用于 Hive 持久化）
//
// 为什么要分开？
//   业务实体不应该知道"怎么存储"（那是基础设施的职责）。
//   但 Hive 需要对象有 toJson/fromJson，所以只能复制一份。
//   更好的做法是用 freezed/copyWith 自动生成，但目前还没引入。
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// 消息数据模型（Hive 存储专用）
///
/// 字段说明：
///   id          唯一 ID（时间戳字符串）
///   role        'user' | 'assistant'
///   content     正文
///   timestamp   时间戳
///   isStreaming 是否正在流式输出中
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
  /// Hive 存的是 Map<String, dynamic>，这里转回来
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
    'timestamp': timestamp.millisecondsSinceEpoch, // DateTime → int
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

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 好感度数据（本地 UI 状态用）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

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
  }) => AffinityData(
    trust: trust ?? this.trust,
    intimacy: intimacy ?? this.intimacy,
    familiarity: familiarity ?? this.familiarity,
    totalInteractions: totalInteractions ?? this.totalInteractions,
    streakDays: streakDays ?? this.streakDays,
    level: level ?? this.level,
  );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 情绪识别结果
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

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

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 主题状态（亮/暗模式）
//
// StateNotifier 模式：
//   StateNotifier<State> 管理一个状态对象，
//   状态变化时自动通知所有监听者（Consumer / ref.watch）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// 主题 Provider：true = 暗色模式，false = 亮色模式
final themeProvider = StateNotifierProvider<ThemeNotifier, bool>((ref) {
  final box = Hive.box('settings');
  // 首次访问时从 Hive 读取（持久化）
  return ThemeNotifier(box.get('isDarkMode', defaultValue: false) as bool);
});

class ThemeNotifier extends StateNotifier<bool> {
  ThemeNotifier(super.initialState) {
    // 确保 Hive 里也有值（防止首次启动为 null）
    final box = Hive.box('settings');
    state = box.get('isDarkMode', defaultValue: false) as bool;
  }

  /// 切换主题（亮 → 暗 / 暗 → 亮）
  void toggle() {
    state = !state;
    // 写入 Hive，下次启动时恢复
    Hive.box('settings').put('isDarkMode', state);
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Services（只读单例）
//
// Provider 的常见模式：单例服务注入
// 用 Provider<> 而不是 StateNotifierProvider，
// 因为服务对象本身不需要通知 UI 更新（只提供方法调用）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// 统一后端服务单例
/// 后端所有 API（对话/记忆/TTS/角色）都通过这个访问
final backendServiceProvider = Provider<BackendService>((ref) {
  return BackendService.instance;
});

/// Agnes 直连模式（已废弃，保留兼容性）
final agnesServiceProvider = Provider<AgnesService>((ref) {
  return AgnesService.instance;
});

/// 系统 TTS 服务（pyttsx3 / espeak-ng，离线方案）
final ttsServiceProvider = Provider<TtsService>((ref) {
  return TtsService();
});

/// ASR 语音识别服务（speech_to_text 插件）
final asrServiceProvider = Provider<AsrService>((ref) {
  return AsrService();
});

/// SinoMem 长期记忆服务
final memoryServiceProvider = Provider<MemoryService>((ref) {
  return MemoryService();
});

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 用户设置（API Key / 区域等）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// Agnes API Key（用户手动输入，存在 Hive）
final apiKeyProvider = StateProvider<String>((ref) {
  final box = Hive.box('settings');
  return box.get('agnesApiKey', defaultValue: '') as String;
});

/// Agnes 服务器区域：true = 国内版（apihub.agnes-ai.cn）
final agnesUseCNProvider = StateProvider<bool>((ref) {
  final box = Hive.box('settings');
  return box.get('agnesUseCN', defaultValue: true) as bool;
});

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 消息列表（StateNotifier + Hive 持久化）
//
// StateNotifierProvider 模式：
//   MessagesNotifier 管理 List<Message> 状态，
//   addMessage / updateMessage / clear 等方法修改状态，
//   自动持久化到 Hive。
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

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

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 竹笌状态机（Legacy 版，新代码请用 chat_provider.dart）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// 竹笌对话状态
enum ZhuaStatus {
  idle, // 空闲，等待用户输入
  thinking, // 思考中（后端推理中）
  writing, // 打字中（流式输出中）
  speaking, // 播报中（TTS 播放中）
}

/// 当前状态（UI 根据这个渲染不同状态：加载动画/输入框等）
final zhuaStatusProvider = StateProvider<ZhuaStatus>((ref) => ZhuaStatus.idle);

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 其他 UI 状态
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// 输入框草稿（用户打字时临时保存，防止切换页面丢失）
final draftProvider = StateProvider<String>((ref) => '');

/// Cartesia 情感 TTS 服务
final cartesiaTtsServiceProvider = Provider<CartesiaTTSService>((ref) {
  return CartesiaTTSService();
});

/// MiniMax 情感 TTS 服务（替代 Cartesia，密钥经 dart-define 注入）
final miniMaxTtsServiceProvider = Provider<MiniMaxTTSService>((ref) {
  return MiniMaxTTSService();
});

/// Lip Sync 口型值流
///
/// 原理：
///   LipSyncService 内部有一个 StreamController，
///   播放 TTS 时实时推送 0.0 ~ 1.0 的嘴型值。
///   Live2D Widget 监听这个流，驱动 ParamMouthOpenY 参数。
///
/// 使用场景：ChatPage 里 Live2D 的口型动画
final lipSyncStreamProvider = StreamProvider<double>((ref) {
  final service = ref.watch(lipSyncServiceProvider);
  return service.mouthStream;
});

/// 唇形同步服务（注入到 lipSyncStreamProvider）
final lipSyncServiceProvider = Provider<LipSyncService>((ref) {
  return LipSyncService();
});

/// TTS 开关：true = 开启语音播报
final ttsEnabledProvider = StateProvider<bool>((ref) {
  final box = Hive.box('settings');
  return box.get('ttsEnabled', defaultValue: true) as bool;
});

/// TTS 模式：'minimax'（云端情感TTS）| 'system'（本地 IndexTTS 2.5 离线合成）
final ttsModeProvider = StateProvider<String>((ref) {
  final box = Hive.box('settings');
  return box.get('ttsMode', defaultValue: 'system') as String;
});

/// ASR 监听状态：true = 正在录音识别
final asrListeningProvider = StateProvider<bool>((ref) => false);

/// ASR 识别结果：语音转文字的结果
final asrResultProvider = StateProvider<String?>((ref) => null);

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Live2D
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// Live2D 控制器单例（管理 Live2D 模型加载、表情、动作）
final live2dControllerProvider = Provider<ZhuaLive2DController>((ref) {
  return ZhuaLive2DController.instance;
});

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 情绪识别（Legacy 版，保留用于旧页面兼容）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// 当前情绪（驱动 Live2D 表情切换）
/// 新代码请用 presentation/providers/chat_provider.dart 里的 currentEmotionProvider
final currentEmotionProvider = StateProvider<EmotionResult?>((ref) => null);

/// 情绪历史（最近 50 条，用于情绪曲线展示）
final emotionHistoryProvider =
    StateNotifierProvider<EmotionHistoryNotifier, List<EmotionResult>>((ref) {
      return EmotionHistoryNotifier();
    });

class EmotionHistoryNotifier extends StateNotifier<List<EmotionResult>> {
  EmotionHistoryNotifier() : super([]);

  void add(EmotionResult emotion) {
    // 只保留最近 50 条
    state = [...state, emotion].take(50).toList();
  }

  void clear() => state = [];
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 好感度系统（Legacy 版）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// 好感度状态（由 AffinityNotifier 管理）
/// 新代码请用 presentation/providers/chat_provider.dart 里的 affinityProvider
final affinityProvider = StateNotifierProvider<AffinityNotifier, AffinityData>((
  ref,
) {
  return AffinityNotifier();
});

class AffinityNotifier extends StateNotifier<AffinityData> {
  AffinityNotifier() : super(const AffinityData());

  /// 从后端更新好感度数据
  void updateFromBackend(AffinityData data) => state = data;

  /// 重置好感度（清空记忆后调用）
  void reset() => state = const AffinityData();
}
