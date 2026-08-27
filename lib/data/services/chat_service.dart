// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 对话服务（Chat Service）
//
// 位于：data/services/chat_service.dart
// 职责：封装"怎么跟后端拿数据"，包含 SSE 流解析和 HTTP 请求
//
// 关键设计：SSE（Server-Sent Events）
//   不同于传统 HTTP"请求-响应"，SSE 允许后端主动推送数据。
//   想象成微信消息推送——后端边想边说，前端边收边显示。
//
// SSE 事件格式（后端推送的每条数据）：
//   event: text
//   data: {"text": "你好"}
//
//   event: emotion
//   data: {"emotion": "happy", "confidence": 0.92}
//
//   event: done
//   data: {}
//
// 技术实现：
//   - HTTP POST 发起请求，携带 JSON body
//   - 后端返回流式响应（Content-Type: text/event-stream）
//   - 本类逐行解析 SSE 格式，分发到不同事件类型
//   - 丢掉的 token 攒成完整文字，通过 onText 回调返回
//
// 线程安全：无（Flutter 单线程，SSE 在主 isolate 运行）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import '../../core/auth/client_auth.dart';
import '../../core/config.dart';

import '../../domain/entities/message.dart';

/// 2. 解析 SSE 流事件
/// 3. 将事件转换为 ChatEvent 推送给调用方
class ChatService {
  ChatService({Dio? dio})
    : _dio =
          (dio ??
                Dio(
                  BaseOptions(
                    baseUrl: BackendConfig.instance.baseUrl,
                    connectTimeout: const Duration(seconds: 10),
                    receiveTimeout: const Duration(seconds: 30),
                  ),
                ))
            ..interceptors.add(SigningInterceptor());

  final Dio _dio;

  /// 运行时更新后端地址（设置页修改后调用，避免重建实例）
  void setBaseUrl(String url) {
    _dio.options.baseUrl = url;
  }

  /// 发送消息并获取流式响应
  ///
  /// [message]      用户输入的文字
  /// [history]      历史消息列表（传给后端做上下文）
  /// [systemPrompt] 自定义角色设定（可空）
  /// [onText]       每收到一个 token 片段就触发回调
  /// [onEmotion]    情绪识别结果回调
  /// [onAffinity]   好感度变化回调
  /// [onDone]       回复结束回调
  /// [onError]      错误回调
  ///
  /// 返回 Future<bool>：true=成功，false=失败
  Future<bool> streamChat({
    required String message,
    required List<Message> history,
    String? systemPrompt,
    String? clientMsgId,
    required void Function(String token) onText,
    void Function(String emotion, double confidence)? onEmotion,
    void Function(Map<String, dynamic> affinity)? onAffinity,
    void Function()? onDone,
    void Function(String error)? onError,
  }) async {
    try {
      // ── 第1步：构造请求体 ──────────────────────────────
      // 历史消息转成 [{role, content}, ...] 格式
      final messages = [
        ...history.map((m) => {'role': m.role, 'content': m.content}),
        {'role': 'user', 'content': message},
      ];

      final body = <String, dynamic>{
        'message': message,
        'history': messages,
        'temperature': 0.8, // 随机性参数，越高越有创意
        'max_tokens': 500, // 最大输出 token 数
      };

      if (systemPrompt != null) {
        body['system_prompt'] = systemPrompt;
      }
      // 幂等 id：断网补发时带上，供后端去重（后端忽略不影响）
      if (clientMsgId != null) {
        body['client_msg_id'] = clientMsgId;
      }

      // ── 第2步：发起 POST 请求 ─────────────────────────
      // 注意：responseType = ResponseType.stream 表示接收流式响应
      final resp = await _dio.post(
        '/chat/v2',
        data: body,
        options: Options(
          responseType: ResponseType.stream, // ← 关键：告诉 Dio 要流式接收
          headers: {'Accept': 'text/event-stream'},
        ),
      );

      // ── 第3步：逐行解析 SSE 流 ────────────────────────
      // SSE 格式说明：
      //   "event: text\ndata: {...}\n\n"
      //   我们把 event: 存到 _currentEvent，\n\n 表示一条完整消息
      String _currentEvent = 'text';
      StringBuffer _textBuffer = StringBuffer();

      final stream = resp.data.stream as Stream<List<int>>;

      await for (final chunk in stream) {
        // chunk 是网络层拿到的原始字节，转成字符串
        final lines = utf8.decode(chunk).split('\n');

        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) {
            // \n\n 分隔符，一条事件结束了
            _dispatch(
              _currentEvent,
              _textBuffer.toString(),
              onText,
              onEmotion,
              onAffinity,
              onError,
            );
            _textBuffer.clear();
            _currentEvent = 'text'; // 重置默认事件类型
            continue;
          }

          if (trimmed.startsWith('event:')) {
            // 事件类型行：event: emotion
            _currentEvent = trimmed.substring(6).trim();
          } else if (trimmed.startsWith('data:')) {
            // 数据行：data: {"text": "..."}
            _textBuffer.write(trimmed.substring(5));
          }
        }
      }

      // 流结束，最后一条事件可能没有 \n\n
      if (_textBuffer.isNotEmpty) {
        _dispatch(
          _currentEvent,
          _textBuffer.toString(),
          onText,
          onEmotion,
          onAffinity,
          onError,
        );
      }

      onDone?.call();
      return true;
    } on DioException catch (e) {
      // 网络错误（超时/断网/后端挂了）
      onError?.call(_formatDioError(e));
      return false;
    } catch (e) {
      onError?.call('未知错误: $e');
      return false;
    }
  }

  /// 根据事件类型分发到不同回调
  void _dispatch(
    String eventType,
    String rawData,
    void Function(String token) onText,
    void Function(String emotion, double confidence)? onEmotion,
    void Function(Map<String, dynamic> affinity)? onAffinity,
    void Function(String error)? onError,
  ) {
    if (rawData.isEmpty) return;

    try {
      final json = jsonDecode(rawData) as Map<String, dynamic>;

      switch (eventType) {
        case 'text':
          // AI 输出的文字片段
          final text = json['text'] as String?;
          if (text != null && text.isNotEmpty) {
            onText(text);
          }
          break;

        case 'emotion':
          // 情绪识别结果
          final emotion = json['emotion'] as String? ?? 'neutral';
          final confidence = (json['confidence'] as num?)?.toDouble() ?? 0.5;
          onEmotion?.call(emotion, confidence);
          break;

        case 'affinity':
          // 好感度变化
          onAffinity?.call(json);
          break;

        case 'meta':
          // AI 生成内容标识（后端下发，前端可按需展示）
          break;

        case 'blocked':
          // 用户输入命中违规过滤，后端拒绝生成
          final reason = json['reason'] as String? ?? '内容被拦截';
          onError?.call(reason);
          break;

        case 'done':
          // 流结束标识（无 payload）
          break;

        default:
          // 未知事件类型，忽略
          break;
      }
    } catch (_) {
      // JSON 解析失败（非 JSON 纯文本），当作 text 事件处理
      if (eventType == 'text') {
        onText(rawData);
      }
    }
  }

  /// 格式化 Dio 错误
  String _formatDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return '连接超时，请检查网络';
      case DioExceptionType.sendTimeout:
        return '发送超时';
      case DioExceptionType.receiveTimeout:
        return '后端响应超时';
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        if (statusCode == 401) return '后端认证失败，请检查 API Key';
        if (statusCode == 403) return '后端拒绝访问';
        if (statusCode == 404) return '后端接口不存在';
        if (statusCode == 502) return '后端网关错误';
        return '后端错误: $statusCode';
      case DioExceptionType.cancel:
        return '请求被取消';
      case DioExceptionType.connectionError:
        return '网络连接失败，请检查网络';
      default:
        return e.message ?? '网络错误';
    }
  }

  /// 单独检测情绪（不走流式）
  Future<String> detectEmotion(String text) async {
    try {
      final resp = await _dio.post('/emotion', data: {'text': text});
      final data = resp.data as Map<String, dynamic>;
      return data['emotion'] as String? ?? 'neutral';
    } catch (_) {
      return 'neutral';
    }
  }

  /// 检查后端是否在线
  Future<bool> isOnline() async {
    try {
      final resp = await _dio.get(
        '/health',
        options: Options(receiveTimeout: const Duration(seconds: 5)),
      );
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
