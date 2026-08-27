// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Cartesia 情感 TTS 服务
//
// 位于：core/services/cartesia_tts_service.dart
// 职责：调用 Cartesia API，把文字转成带情感的语音
//
// 背景：
//   通用 TTS（pyttsx3 / espeak）太机械，没有"灵魂"。
//   Cartesia 是情感 TTS API，可以控制语气（gentle / playful / wise），
//   让竹笌的声音有性格。
//
// 三种角色风格（Cartesia voice IDs）：
//   gentle   → 温柔细腻，适合日常聊天
//   playful  → 活泼俏皮，适合撒娇/开心场景
//   wise     → 沉稳智慧，适合讲故事/正经话题
//
// 技术实现：
//   1. 构造 HTTP POST 请求到 Cartesia API
//   2. 发送 JSON：text + voice_id + emotion
//   3. 接收 WAV/MP3 音频二进制
//   4. 缓存到本地文件（避免重复请求）
//   5. 交给 just_audio 播放
//
// 费用注意：Cartesia 按 token 计费，免费额度有限。
//   已实现本地缓存，同一段文字只请求一次。
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';

/// 情感角色类型
enum PersonaVoice {
  gentle, // 温柔
  playful, // 俏皮
  wise, // 智慧
}

/// Cartesia TTS 服务
///
/// 用法示例：
/// ```dart
/// final tts = CartesiaTTSService();
/// await tts.speak('你好呀！', persona: PersonaVoice.gentle);
/// ```
class CartesiaTTSService {
  CartesiaTTSService();

  /// Cartesia API 地址
  static const _apiUrl = 'https://api.cartesia.ai/tts/stream';

  /// Cartesia API Key（生产用 --dart-define=CARTESIA_API_KEY=xxx 注入）。
  /// 留空表示未配置，speak() 会返回 false 让上层降级到系统 TTS。
  static const String _apiKey = String.fromEnvironment(
    'CARTESIA_API_KEY',
    defaultValue: '',
  );

  /// 是否已配置真实 API Key（未配置时上层应降级到系统 TTS）。
  bool get isConfigured => _apiKey.isNotEmpty;

  /// 角色 → Voice ID 映射（Cartesia 官方音色）
  /// 这些 voice_id 是 Cartesia 平台注册过的音色
  static const _voiceIds = {
    PersonaVoice.gentle:
        's3://voice-cloning-zero-shot/dad11b85-b737-410a-bd16-95e3a6c3f3b4/gentle.wav',
    PersonaVoice.playful:
        's3://voice-cloning-zero-shot/dad11b85-b737-410a-bd16-95e3a6c3f3b4/playful.wav',
    PersonaVoice.wise:
        's3://voice-cloning-zero-shot/dad11b85-b737-410a-bd16-95e3a6c3f3b4/wise.wav',
  };

  /// 角色 → 情感标签映射（Cartesia 支持的情感参数）
  /// 影响语音的语气、语速、音调
  static const _emotionLabels = {
    PersonaVoice.gentle: 'calm,warm',
    PersonaVoice.playful: 'cheerful,light',
    PersonaVoice.wise: 'serene,composed',
  };

  final Dio _dio = Dio();
  final AudioPlayer _player = AudioPlayer();

  /// 当前角色
  PersonaVoice _currentPersona = PersonaVoice.gentle;

  /// 音频缓存目录（避免重复生成）
  Future<Directory> get _cacheDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final cache = Directory('${appDir.path}/cartesia_cache');
    if (!await cache.exists()) await cache.create(recursive: true);
    return cache;
  }

  /// 生成文字的缓存 key（MD5，避免特殊字符做文件名）
  String _cacheKey(String text, PersonaVoice persona) {
    final raw = '${persona.name}_$text';
    return raw.hashCode.toRadixString(16); // 简单哈希
  }

  /// 文本转语音并播放
  ///
  /// [text]     要说的话
  /// [persona]  情感角色（gentle / playful / wise）
  /// [cache]    是否使用缓存（默认 true）
  ///
  /// 返回 true 表示已成功播音（含缓存命中），false 表示失败，
  /// 调用方应据此降级到系统 TTS。
  Future<bool> speak(
    String text, {
    PersonaVoice? persona,
    bool cache = true,
  }) async {
    final voice = persona ?? _currentPersona;

    // 1. 查缓存
    if (cache) {
      final cachedFile = await _getCachedFile(text, voice);
      if (await cachedFile.exists()) {
        try {
          await _player.setFilePath(cachedFile.path);
          await _player.play();
          return true;
        } catch (_) {
          return false;
        }
      }
    }

    // 2. 调用 API（未配置 Key 时直接失败，触发上层降级）
    final audioBytes = await _fetchTTS(text, voice);
    if (audioBytes == null) return false;

    // 3. 写缓存
    if (cache) {
      final file = await _getCachedFile(text, voice);
      try {
        await file.writeAsBytes(audioBytes);
      } catch (_) {
        // 缓存写失败不致命，仍可播放
      }
    }

    // 4. 播放（缓存命中时直接播文件，API 返回时用 StreamAudioSource）
    try {
      if (cache) {
        await _player.setFilePath((await _getCachedFile(text, voice)).path);
      } else {
        await _player.setAudioSource(_BytesAudioSource(audioBytes));
      }
      await _player.play();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 获取缓存文件路径
  Future<File> _getCachedFile(String text, PersonaVoice persona) async {
    final dir = await _cacheDir;
    final key = _cacheKey(text, persona);
    return File('${dir.path}/$key.wav');
  }

  /// 调用 Cartesia API
  Future<List<int>?> _fetchTTS(String text, PersonaVoice persona) async {
    // 未配置真实 Key 时直接失败，让上层降级到系统 TTS
    if (!isConfigured) return null;
    try {
      final resp = await _dio.post(
        _apiUrl,
        data: {
          'text': text,
          'voice': {'mode': 's3', 's3_url': _voiceIds[persona]},
          'emotion': _emotionLabels[persona],
          'output_format': {
            'container': 'wav',
            'encoding': 'pcm_s16le',
            'sample_rate': 24000,
          },
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'application/json',
          },
          responseType: ResponseType.bytes,
        ),
      );
      return resp.data;
    } catch (e) {
      return null; // API 调用失败，静默降级
    }
  }

  /// 切换情感角色
  void setPersona(PersonaVoice persona) {
    _currentPersona = persona;
  }

  /// 停止播放
  Future<void> stop() async {
    await _player.stop();
  }

  /// 释放资源
  void dispose() {
    _player.dispose();
  }
}

/// just_audio 的 StreamAudioSource 实现（把字节数组转成音频流）
/// 用于播放 API 直接返回的音频字节（不走缓存时）
class _BytesAudioSource extends StreamAudioSource {
  final List<int> _bytes;
  _BytesAudioSource(this._bytes);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _bytes.length;
    return StreamAudioResponse(
      sourceLength: _bytes.length,
      contentLength: end - start,
      offset: start,
      contentType: 'audio/wav',
      stream: Stream.value(_bytes.sublist(start, end)),
    );
  }
}
