// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 后端服务（Backend Service）
//
// 位于：core/services/backend_service.dart
// 职责：封装所有后端 API 调用，是 Flutter 端访问后端的唯一入口
//
// 设计背景：
//   后端有多个独立接口（/health /chat /memory /tts /persona），
//   分散调用很乱。本类统一封装，提供类型安全的调用方法。
//
// 与 ChatService 的区别：
//   ChatService    → 专门处理流式对话（SSE 解析）
//   BackendService → 处理其他所有接口（健康检查/记忆/TTS等）
//
// 依赖关系：
//   本类依赖 ChatService（复用其 SSE 解析能力）
//   本类被 providers 层调用，UI 不直接访问本类
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'dart:typed_data';

import 'package:dio/dio.dart';
import '../../core/auth/client_auth.dart';
import '../../core/config.dart';
import '../../data/services/chat_service.dart';
import '../../domain/entities/message.dart' as domain;

/// 后端服务单例
///
/// 用法示例：
/// ```dart
/// final ok = await BackendService.instance.healthCheck();
/// await BackendService.instance.syncWakeWord('竹笌');
/// ```
class BackendService {
  BackendService._();
  static final BackendService instance = BackendService._();

  /// HTTP 客户端（复用 Dio 实例，不要每次请求都 new）
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: BackendConfig.instance.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ),
  )..interceptors.add(SigningInterceptor());

  /// 底层 SSE 对话服务（复用 ChatService）
  final ChatService _chatService = ChatService();

  // ════════════════════════════════════════════════════════
  // 对话接口（委托给 ChatService）
  // ════════════════════════════════════════════════════════

  /// 流式对话（转发给 ChatService）
  Future<bool> streamChat({
    required String message,
    required List<Map<String, String>> history,
    String? systemPrompt,
    required void Function(String token) onText,
    void Function(String emotion, double confidence)? onEmotion,
    void Function(Map<String, dynamic> affinity)? onAffinity,
    void Function()? onDone,
    void Function(String error)? onError,
  }) {
    return _chatService.streamChat(
      message: message,
      history: history
          .map(
            (m) => domain.Message(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              role: m['role'] ?? 'user',
              content: m['content'] ?? '',
              timestamp: DateTime.now(),
            ),
          )
          .toList(),
      systemPrompt: systemPrompt,
      onText: onText,
      onEmotion: onEmotion,
      onAffinity: onAffinity,
      onDone: onDone,
      onError: onError,
    );
  }

  // ════════════════════════════════════════════════════════
  // 健康检查 & 配置同步
  // ════════════════════════════════════════════════════════

  /// 健康检查（后端是否在线）
  Future<bool> healthCheck() async {
    try {
      final resp = await _dio.get('/health');
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// 修改后端地址并立即对已在用的 Dio 客户端生效
  ///
  /// 设置页「后端地址」保存时调用。仅写 Hive/内存不足以生效，
  /// 因为 [BackendService] 与 [ChatService] 的 Dio 在构造时已固化 baseUrl。
  void setBackendUrl(String url) {
    BackendConfig.instance.setBaseUrl(url); // 校验格式 + 写入 Hive + 更新 _baseUrl
    _dio.options.baseUrl = url;
    _chatService.setBaseUrl(url);
  }

  /// 同步唤醒词到后端
  /// 本地改了唤醒词后，调用此方法让后端也生效
  Future<bool> syncWakeWord(String word) async {
    try {
      final resp = await _dio.post('/wake-word', data: {'word': word});
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ════════════════════════════════════════════════════════
  // 记忆接口
  // ════════════════════════════════════════════════════════

  /// 获取今日对话记忆
  Future<List<Map<String, dynamic>>> getTodayMemories() async {
    try {
      final resp = await _dio.get('/memory/today');
      final data = resp.data as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(data['memories'] ?? []);
    } catch (_) {
      return [];
    }
  }

  /// 搜索记忆
  Future<List<Map<String, dynamic>>> searchMemories(String query) async {
    try {
      final resp = await _dio.get(
        '/memory/search',
        queryParameters: {'q': query, 'limit': 20},
      );
      final data = resp.data as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(data['memories'] ?? []);
    } catch (_) {
      return [];
    }
  }

  /// 获取对话摘要列表
  Future<List<Map<String, dynamic>>> getSummaries() async {
    try {
      final resp = await _dio.get('/memory/summaries');
      final data = resp.data as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(data['summaries'] ?? []);
    } catch (_) {
      return [];
    }
  }

  /// 清空对话记忆（危险操作）
  Future<bool> clearMemory() async {
    try {
      final resp = await _dio.post('/memory/clear');
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// 获取好感度数据
  Future<BackendAffinityData> getAffinity() async {
    try {
      final resp = await _dio.get('/affinity');
      return BackendAffinityData.fromJson(resp.data as Map<String, dynamic>);
    } catch (_) {
      return BackendAffinityData.initial();
    }
  }

  // ════════════════════════════════════════════════════════
  // TTS 角色切换
  // ════════════════════════════════════════════════════════

  /// 切换情感角色（gentle / playful / wise）
  Future<bool> setPersona(String persona) async {
    try {
      final resp = await _dio.post('/persona', data: {'persona': persona});
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ════════════════════════════════════════════════════════
  // TTS（本地 IndexTTS 2.5 语音合成）
  // ════════════════════════════════════════════════════════

  /// 调用本地 IndexTTS 微服务合成语音，返回 WAV 字节。
  /// 失败（服务未起 / 网络断开）时返回 null，由 TtsService 静默降级。
  Future<Uint8List?> tts({
    required String text,
    String? emotion,
    String lang = 'ZH',
    double speed = 1.0,
  }) async {
    try {
      final resp = await _dio.post(
        '/tts',
        data: {'text': text, 'lang': lang, 'emotion': emotion, 'speed': speed},
        options: Options(
          responseType: ResponseType.bytes,
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 120),
        ),
      );
      if (resp.statusCode == 200 && resp.data != null) {
        return Uint8List.fromList(resp.data as List<int>);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ════════════════════════════════════════════════════════
  // Phase 1：音乐狗子状态与交互
  // ════════════════════════════════════════════════════════

  /// 获取音乐狗子当前状态
  Future<Map<String, dynamic>> getPetState() async {
    try {
      final resp = await _dio.get('/pet/state');
      return resp.data as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  /// 与音乐狗子交互（feed/play/pet/talk/sleep）
  Future<Map<String, dynamic>> petInteract(String action) async {
    try {
      final resp = await _dio.post('/pet/interact', data: {'action': action});
      final data = resp.data as Map<String, dynamic>;
      return data['state'] as Map<String, dynamic>? ?? {};
    } catch (_) {
      return {};
    }
  }

  // ════════════════════════════════════════════════════════
  // Phase 1：歌词库 CRUD
  // ════════════════════════════════════════════════════════

  /// 获取歌词列表
  Future<List<Map<String, dynamic>>> listLyrics({int limit = 50, int offset = 0}) async {
    try {
      final resp = await _dio.get('/lyrics', queryParameters: {'limit': limit, 'offset': offset});
      final data = resp.data as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(data['items'] ?? []);
    } catch (_) {
      return [];
    }
  }

  /// 获取单条歌词
  Future<Map<String, dynamic>?> getLyrics(int id) async {
    try {
      final resp = await _dio.get('/lyrics/$id');
      return resp.data as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// 创建歌词
  Future<int?> createLyrics({required String title, required String content, List<String>? tags, String? mood}) async {
    try {
      final resp = await _dio.post('/lyrics', data: {
        'title': title,
        'content': content,
        'tags': tags ?? [],
        'mood': mood ?? '',
      });
      final data = resp.data as Map<String, dynamic>;
      return data['id'] as int?;
    } catch (_) {
      return null;
    }
  }

  /// 更新歌词
  Future<bool> updateLyrics(int id, {String? title, String? content, List<String>? tags, String? mood}) async {
    try {
      final resp = await _dio.put('/lyrics/$id', data: {
        if (title != null) 'title': title,
        if (content != null) 'content': content,
        if (tags != null) 'tags': tags,
        if (mood != null) 'mood': mood,
      });
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// 删除歌词
  Future<bool> deleteLyrics(int id) async {
    try {
      final resp = await _dio.delete('/lyrics/$id');
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ════════════════════════════════════════════════════════
  // Phase 1：音乐生成
  // ════════════════════════════════════════════════════════

  /// 发起音乐生成（异步任务）
  Future<String?> generateMusic({String prompt = '', int? lyricsId, String style = '', String title = ''}) async {
    try {
      final resp = await _dio.post('/music/generate', data: {
        'prompt': prompt,
        if (lyricsId != null) 'lyrics_id': lyricsId,
        'style': style,
        'title': title,
      });
      final data = resp.data as Map<String, dynamic>;
      return data['job_id'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// 查询音乐生成任务状态
  Future<Map<String, dynamic>?> getMusicJob(String jobId) async {
    try {
      final resp = await _dio.get('/music/jobs/$jobId');
      return resp.data as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ════════════════════════════════════════════════════════
  // Phase 1：歌曲库
  // ════════════════════════════════════════════════════════

  /// 获取歌曲列表
  Future<List<Map<String, dynamic>>> listSongs({int limit = 50, int offset = 0, bool favoriteOnly = false}) async {
    try {
      final resp = await _dio.get('/songs', queryParameters: {
        'limit': limit,
        'offset': offset,
        if (favoriteOnly) 'favorite': true,
      });
      final data = resp.data as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(data['items'] ?? []);
    } catch (_) {
      return [];
    }
  }

  /// 切换歌曲收藏状态
  Future<bool> toggleSongFavorite(int songId) async {
    try {
      final resp = await _dio.post('/songs/$songId/favorite');
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// 记录歌曲播放
  Future<bool> recordSongPlay(int songId) async {
    try {
      final resp = await _dio.post('/songs/$songId/play');
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// 删除歌曲
  Future<bool> deleteSong(int songId) async {
    try {
      final resp = await _dio.delete('/songs/$songId');
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

/// 好感度数据（BackendService 内部用）
/// 命名为 BackendAffinityData 避免与 providers/app_providers_legacy.dart 的 AffinityData 冲突
class BackendAffinityData {
  final double trust;
  final double intimacy;
  final double familiarity;
  final int totalInteractions;

  BackendAffinityData({
    this.trust = 30,
    this.intimacy = 20,
    this.familiarity = 5,
    this.totalInteractions = 0,
  });

  factory BackendAffinityData.fromJson(Map<String, dynamic> json) {
    return BackendAffinityData(
      trust: (json['trust'] as num?)?.toDouble() ?? 30,
      intimacy: (json['intimacy'] as num?)?.toDouble() ?? 20,
      familiarity: (json['familiarity'] as num?)?.toDouble() ?? 5,
      totalInteractions: (json['total_interactions'] as num?)?.toInt() ?? 0,
    );
  }

  factory BackendAffinityData.initial() => BackendAffinityData();

  String get level {
    if (totalInteractions >= 100) return '灵魂伴侣';
    if (totalInteractions >= 61) return '亲密';
    if (totalInteractions >= 31) return '朋友';
    if (totalInteractions >= 11) return '熟人';
    return '陌生人';
  }

  double get total => (trust + intimacy + familiarity) / 3;
}
