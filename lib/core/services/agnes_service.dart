// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 竹笌对话服务（直连 Agnes AI，统一对话后端）
//
// 位于：core/services/agnes_service.dart
// 职责：封装 Agnes 2.5 Pro API，统一对话能力，不再依赖自建后端
//
// 架构说明（2026-09-01 重构）：
//   - 对话主后端：Agnes 2.5 Pro（OpenAI 兼容格式）
//   - 情绪检测：本地关键词分析（无额外 API 调用）
//   - 好感度：本地简单积分（根据情绪正负调整）
//   - 记忆：Hive 本地持久化（由 MemoryService 处理）
//   - 语音 TTS：MiniMax / System TTS（不变）
//
// 模型选择：
//   - agnes-2.5-pro  ：质量优先（当前默认）
//   - agnes-2.5-flash：速度优先，token 消耗更低
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'dart:async';
import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

/// Agnes 情绪标签
enum AgnesEmotion {
  happy('happy'),
  sad('sad'),
  angry('angry'),
  surprised('surprised'),
  neutral('neutral');

  final String label;
  const AgnesEmotion(this.label);

  static AgnesEmotion fromKeyword(String emotion) {
    switch (emotion) {
      case 'happy':
      case 'joy':
      case 'excited':
      case '开心':
      case '高兴':
        return AgnesEmotion.happy;
      case 'sad':
      case 'sorrow':
      case '难过':
      case '伤心':
        return AgnesEmotion.sad;
      case 'angry':
      case 'mad':
      case '生气':
      case '愤怒':
        return AgnesEmotion.angry;
      case 'surprised':
      case 'shock':
      case '惊讶':
        return AgnesEmotion.surprised;
      default:
        return AgnesEmotion.neutral;
    }
  }
}

/// 好感度变化事件
class AgnesAffinityDelta {
  final double delta; // 变化量（正=好感增加，负=好感减少）
  final double total; // 累计好感度
  const AgnesAffinityDelta({required this.delta, required this.total});
}

/// Agnes 对话事件（统一事件类型，与原 ChatService 事件结构兼容）
sealed class AgnesChatEvent {
  const AgnesChatEvent();
}

/// 文字片段事件（对应 ChatEventType.token）
class AgnesTextEvent extends AgnesChatEvent {
  final String text;
  const AgnesTextEvent(this.text);
}

/// 情绪变化事件（对应 ChatEventType.emotion）
class AgnesEmotionEvent extends AgnesChatEvent {
  final String emotion;
  final double confidence;
  const AgnesEmotionEvent({required this.emotion, this.confidence = 0.8});
}

/// 好感度变化事件（对应 ChatEventType.affinity）
class AgnesAffinityEvent extends AgnesChatEvent {
  final AgnesAffinityDelta affinity;
  const AgnesAffinityEvent(this.affinity);
}

/// 对话结束事件（对应 ChatEventType.done）
class AgnesDoneEvent extends AgnesChatEvent {
  const AgnesDoneEvent();
}

/// 错误事件（对应 ChatEventType.error）
class AgnesErrorEvent extends AgnesChatEvent {
  final String message;
  const AgnesErrorEvent(this.message);
}

/// Agnes 对话服务
///
/// 用法：
/// ```dart
/// final agnes = AgnesService.instance;
/// await for (final event in agnes.chatStream(message: '你好', history: [])) {
///   if (event is AgnesTextEvent) print(event.text);
/// }
/// ```
class AgnesService {
  AgnesService._();

  static AgnesService? _instance;

  /// 全局单例
  static AgnesService get instance => _instance ??= AgnesService._();

  // ━━━━━━━━━━━━━━━ API 配置 ━━━━━━━━━━━━━━━

  /// Agnes 国内版 API（当前默认）
  static const _apiCN = 'https://apihub.agnes-ai.cn/v1/chat/completions';

  /// Agnes 国际版 API
  static const _apiIntl = 'https://apihub.agnes-ai.com/v1/chat/completions';

  /// 当前模型
  /// - agnes-2.5-pro  ：小猫 2.5 Pro，质量优先（当前）
  /// - agnes-2.5-flash：小猫 2.5 Flash，速度优先
  static const _model = 'agnes-2.5-pro';

  /// 当前选中的 API 端点（由 App 在设置页控制）
  bool _useCN = true;

  String? _runtimeApiKey;

  /// 运行时设置 API Key
  void setApiKey(String key) => _runtimeApiKey = key;

  /// 切换 CN/国际版
  void setUseCN(bool cn) {
    _useCN = cn;
    try {
      Hive.box('settings').put('agnesUseCN', cn);
    } catch (_) {}
  }

  bool get useCN => _useCN;

  String get _baseUrl => _useCN ? _apiCN : _apiIntl;

  // ━━━━━━━━━━━━━━━ 好感度管理 ━━━━━━━━━━━━━━━

  static const _affinityKey = 'agnes_affinity';
  static const _defaultAffinity = 50.0; // 初始好感度

  /// 获取当前累计好感度（0~100）
  double get affinity {
    try {
      final box = Hive.box('settings');
      return box.get(_affinityKey, defaultValue: _defaultAffinity) as double;
    } catch (_) {
      return _defaultAffinity;
    }
  }

  /// 更新好感度并返回变化量
  double _updateAffinity(double delta) {
    final current = affinity;
    final next = (current + delta).clamp(0.0, 100.0);
    try {
      Hive.box('settings').put(_affinityKey, next);
    } catch (_) {}
    return delta;
  }

  /// 重置好感度
  void resetAffinity() {
    try {
      Hive.box('settings').put(_affinityKey, _defaultAffinity);
    } catch (_) {}
  }

  // ━━━━━━━━━━━━━━━ 情绪检测 ━━━━━━━━━━━━━━━
  // 无需外部 API，纯关键词匹配
  // 覆盖中文 + 英文情绪词

  static const _positiveWords = [
    '好', '棒', '赞', '牛', '强', '哈', '嘻', '嗨', '呀', '呢',
    '开心', '高兴', '喜欢', '爱', '哈哈', '嘿嘿', '耶', '哇',
    '厉害', '真好', '太棒', '绝', '完美', '优秀', '真好',
    'happy', 'joy', 'love', 'great', 'awesome', 'amazing',
    'good', 'nice', 'wonderful', 'excellent', ':)', ':-)',
  ];

  static const _negativeWords = [
    '不', '别', '哼', '哼', '滚', '讨厌', '烦', '糟', '完',
    '难过', '伤心', '生气', '愤怒', '讨厌', '无聊', '失望',
    'sad', 'angry', 'mad', 'hate', 'bad', 'terrible', ':(', ':-(',
  ];

  /// 根据文字内容分析情绪标签
  AgnesEmotion detectEmotion(String text) {
    if (text.isEmpty) return AgnesEmotion.neutral;

    int posScore = 0;
    int negScore = 0;

    for (final w in _positiveWords) {
      if (text.contains(w)) posScore++;
    }
    for (final w in _negativeWords) {
      if (text.contains(w)) negScore++;
    }

    if (posScore > negScore) return AgnesEmotion.happy;
    if (negScore > posScore) return AgnesEmotion.sad;
    return AgnesEmotion.neutral;
  }

  /// 情绪转好感度变化量
  double _emotionToAffinityDelta(AgnesEmotion emotion) {
    switch (emotion) {
      case AgnesEmotion.happy:
        return 1.0;    // 开心 +1
      case AgnesEmotion.sad:
        return -0.5;   // 难过 -0.5
      case AgnesEmotion.angry:
        return -1.0;    // 生气 -1
      case AgnesEmotion.surprised:
        return 0.5;    // 惊讶 +0.5
      case AgnesEmotion.neutral:
        return 0.0;
    }
  }

  // ━━━━━━━━━━━━━━━ 流式对话 ━━━━━━━━━━━━━━━

  /// 流式对话，返回统一事件流
  ///
  /// 每次调用生成独立的 SSE 连接，内部做情绪检测和好感度更新。
  Stream<AgnesChatEvent> chatStream({
    required String message,
    required List<Map<String, String>> history,
    String? systemPrompt,
    double temperature = 0.8,
    int maxTokens = 500,
  }) async* {
    // 1) 构建消息列表
    final messages = _buildMessages(message, history, systemPrompt);

    // 2) 构造请求
    final body = <String, dynamic>{
      'model': _model,
      'messages': messages,
      'max_tokens': maxTokens,
      'temperature': temperature,
      'stream': true,
    };

    final request = http.Request('POST', Uri.parse(_baseUrl));
    request.headers['Content-Type'] = 'application/json';
    request.headers['Authorization'] = 'Bearer ${_runtimeApiKey ?? ''}';
    request.body = jsonEncode(body);

    // 3) 发送请求
    http.StreamedResponse streamedResponse;
    try {
      streamedResponse = await http.Client().send(request);
    } catch (e) {
      yield AgnesErrorEvent('网络连接失败：$e');
      return;
    }

    if (streamedResponse.statusCode != 200) {
      final body = await streamedResponse.stream.bytesToString();
      yield AgnesErrorEvent('Agnes API 错误 ${streamedResponse.statusCode}：$body');
      return;
    }

    // 4) 解析 SSE 流
    String buffer = '';
    StringBuffer fullText = StringBuffer();

    await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
      buffer += chunk;

      while (buffer.contains('\n')) {
        final lineEnd = buffer.indexOf('\n');
        String line = buffer.substring(0, lineEnd).trim();
        buffer = buffer.substring(lineEnd + 1);

        if (!line.startsWith('data: ')) continue;
        final data = line.substring(6).trim();
        if (data == '[DONE]') break;

        try {
          final json = jsonDecode(data);
          final content = json['choices']?[0]?['delta']?['content'] as String?;
          if (content != null && content.isNotEmpty) {
            fullText.write(content);
            yield AgnesTextEvent(content);
          }
        } catch (_) {
          // 非 JSON 行跳过
        }
      }
    }

    // 5) 流结束后分析情绪，更新好感度
    final fullResponseText = fullText.toString();
    final emotion = detectEmotion(fullResponseText);
    yield AgnesEmotionEvent(emotion: emotion.label, confidence: 0.8);

    final delta = _emotionToAffinityDelta(emotion);
    if (delta != 0.0) {
      _updateAffinity(delta);
      yield AgnesAffinityEvent(AgnesAffinityDelta(delta: delta, total: affinity));
    }

    yield const AgnesDoneEvent();
  }

  /// 同步对话（一次返回完整回复，无流式）
  Future<String> chat({
    required String message,
    List<Map<String, String>> history = const [],
    String? systemPrompt,
    double temperature = 0.8,
  }) async {
    final body = <String, dynamic>{
      'model': _model,
      'messages': _buildMessages(message, history, systemPrompt),
      'max_tokens': 500,
      'temperature': temperature,
      'stream': false,
    };

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${_runtimeApiKey ?? ''}',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception('Agnes API 错误 ${response.statusCode}：${response.body}');
    }

    final data = jsonDecode(response.body);
    return data['choices'][0]['message']['content'] as String;
  }

  // ━━━━━━━━━━━━━━━ 工具方法 ━━━━━━━━━━━━━━━

  List<Map<String, String>> _buildMessages(
    String message,
    List<Map<String, String>> history,
    String? systemPrompt,
  ) {
    final messages = <Map<String, String>>[];
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      messages.add({'role': 'system', 'content': systemPrompt});
    }
    for (final h in history) {
      messages.add({'role': h['role'] ?? 'user', 'content': h['content'] ?? ''});
    }
    messages.add({'role': 'user', 'content': message});
    return messages;
  }
}
