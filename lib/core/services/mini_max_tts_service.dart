// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MiniMax 情感 TTS 服务
//
// 位于：core/services/mini_max_tts_service.dart
// 职责：调用 MiniMax 平台（api.minimax.io）语音合成 API，
//       把文字转成带性格/情绪的语音，替代原 Cartesia TTS。
//
// 背景：
//   通用 TTS（系统引擎）太机械，没有"灵魂"。
//   MiniMax 平台 TTS（speech-2.6-hd 等）中文韵律好、音色多，
//   让竹笌的声音有性格、有情绪。
//
// 接入说明：
//   - 端点：https://api.minimax.io/v1/t2a_v2
//   - 鉴权：Authorization: Bearer <API_KEY>（无需 GroupId，密钥自带账户归属）
//   - 返回：data.audio 为 **hex 编码** 的音频（默认 mp3）
//
// 密钥来源（两种，优先级从高到低）：
//   1. 运行时：设置页输入 → Hive('miniMaxApiKey') → configure(apiKey) 注入
//   2. 编译期：--dart-define=MINIMAX_API_KEY=xxx 注入（无 UI 时的兜底）
//   未配置任何 Key 时 speak() 返回 false，由上层降级到系统 TTS。
//
// 情绪映射（移植自 main 分支的情感 TTS）：
//   speak(text, emotion: 'happy'/'sad'/...) 会按情绪选不同 voice_id + 语速；
//   若不传 emotion 而传 persona，则走 gentle/playful/wise 角色音色。
//
// 费用注意：MiniMax 按字符计费，账户需有足够余额（status_code=1008 即余额不足）。
//   已实现本地缓存，同一段文字只请求一次。
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';

/// 情感角色类型（与竹笌的人设情绪对应）
enum PersonaVoice {
  gentle, // 温柔甜美
  playful, // 俏皮少女
  wise, // 沉稳御姐
}

/// MiniMax 情感标签 → API voice_id 映射（移植自 main 分支的 Sambert 情感音色）
/// voice_id 来源于 MiniMax 控制台音色列表
const Map<String, String> kEmotionVoiceMap = {
  'happy': 'HappyBoy', // 活泼开朗
  'sad': 'GentleGirl', // 温柔伤感
  'shy': 'CuteGirl', // 害羞可爱
  'cute': 'CuteBoy', // 活泼俏皮
  'neutral': 'StableMale', // 平稳男声（默认）
  'excited': 'CuteBoy', // 兴奋激动
};

/// MiniMax 情感标签 → 语速
const Map<String, double> kEmotionSpeedMap = {
  'happy': 1.15,
  'sad': 0.85,
  'shy': 0.90,
  'cute': 1.10,
  'neutral': 1.00,
  'excited': 1.25,
};

/// 竹笌聊天情绪标签 → main 情感分类的别名映射
/// 让后端返回的丰富情绪（joy / angry / ...）也能映射到对应音色
const Map<String, String> kEmotionAlias = {
  'joy': 'happy',
  'proud': 'excited',
  'curious': 'neutral',
  'trust': 'neutral',
  'angry': 'sad',
  'fearful': 'sad',
  'disgusted': 'sad',
  'ashamed': 'shy',
};

/// MiniMax TTS 服务
///
/// 用法示例：
/// ```dart
/// final tts = MiniMaxTTSService();
/// await tts.configure(apiKey: 'xxx');            // 运行时注入密钥
/// await tts.speak('你好呀！', emotion: 'happy');  // 带情绪朗读
/// await tts.speak('你好呀！', persona: PersonaVoice.gentle);
/// ```
class MiniMaxTTSService {
  MiniMaxTTSService();

  /// MiniMax 平台语音合成端点
  static const _apiUrl = 'https://api.minimax.io/v1/t2a_v2';

  /// 默认模型（最新 HD 模型，实时响应 + 超高音质）
  static const String _model = 'speech-2.6-hd';

  /// MiniMax API Key。
  /// 优先运行时 configure() 注入；缺省回退编译期 --dart-define。
  /// 留空表示未配置，speak() 会返回 false 让上层降级到系统 TTS。
  String? _apiKey = const String.fromEnvironment(
    'MINIMAX_API_KEY',
    defaultValue: '',
  );

  /// 是否已配置真实 API Key（运行时或编译期任一即可）。
  bool get isConfigured => _apiKey != null && _apiKey!.isNotEmpty;

  /// 运行时配置 API Key（从设置页读取后传入，覆盖编译期注入）
  void configure({required String apiKey}) {
    _apiKey = apiKey.trim();
  }

  /// 角色 → 音色 ID 映射（MiniMax 官方中文系统音色，均已验证可用）
  static const _voiceIds = {
    PersonaVoice.gentle: 'female-tianmei', // 甜美女性
    PersonaVoice.playful: 'female-shaonv', // 少女音色
    PersonaVoice.wise: 'female-yujie', // 御姐音色
  };

  final Dio _dio = Dio();
  final AudioPlayer _player = AudioPlayer();

  /// 当前角色（默认温柔甜美，贴合竹笌人设）
  PersonaVoice _currentPersona = PersonaVoice.gentle;

  /// 音频缓存目录（避免重复生成）
  Future<Directory> get _cacheDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final cache = Directory('${appDir.path}/minimax_cache');
    if (!await cache.exists()) await cache.create(recursive: true);
    return cache;
  }

  /// 生成文字的缓存 key（避免特殊字符做文件名；key 含 voiceId 以免不同音色串味）
  String _cacheKey(String text, String voiceId) {
    final raw = '${voiceId}_$text';
    return raw.hashCode.toRadixString(16);
  }

  /// 解析最终使用的 voice_id 与语速。
  /// 规则：emotion 优先（含别名归并），其次 persona，最后默认温柔音色。
  ({String voiceId, double speed}) _resolveVoice(
    PersonaVoice? persona,
    String? emotion,
  ) {
    final e = emotion?.trim();
    if (e != null && e.isNotEmpty) {
      final key = kEmotionAlias[e] ?? e;
      final voiceId = kEmotionVoiceMap[key] ?? kEmotionVoiceMap['neutral']!;
      final speed = kEmotionSpeedMap[key] ?? 1.0;
      return (voiceId: voiceId, speed: speed);
    }
    final v = persona ?? _currentPersona;
    return (voiceId: _voiceIds[v]!, speed: 1.0);
  }

  /// 文本转语音并播放
  ///
  /// [text]     要说的话
  /// [persona]  情感角色（gentle / playful / wise）
  /// [emotion]  对话情绪标签（happy/sad/shy/cute/neutral/excited 及其别名），
  ///            优先级高于 [persona]
  /// [cache]    是否使用缓存（默认 true）
  ///
  /// 返回 true 表示已成功播音（含缓存命中），false 表示失败，
  /// 调用方应据此降级到系统 TTS。
  Future<bool> speak(
    String text, {
    PersonaVoice? persona,
    String? emotion,
    bool cache = true,
  }) async {
    final resolved = _resolveVoice(persona, emotion);
    final voiceId = resolved.voiceId;
    final speed = resolved.speed;

    // 1. 查缓存
    if (cache) {
      final cachedFile = await _getCachedFile(text, voiceId);
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
    final audioBytes = await _fetchTTS(text, voiceId, speed);
    if (audioBytes == null) return false;

    // 3. 写缓存
    if (cache) {
      final file = await _getCachedFile(text, voiceId);
      try {
        await file.writeAsBytes(audioBytes);
      } catch (_) {
        // 缓存写失败不致命，仍可播放
      }
    }

    // 4. 播放（缓存命中时直接播文件，API 返回时用 StreamAudioSource）
    try {
      if (cache) {
        await _player.setFilePath(
          (await _getCachedFile(text, voiceId)).path,
        );
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
  Future<File> _getCachedFile(String text, String voiceId) async {
    final dir = await _cacheDir;
    final key = _cacheKey(text, voiceId);
    return File('${dir.path}/$key.mp3');
  }

  /// 调用 MiniMax 语音合成 API
  ///
  /// 返回 mp3 音频字节；任何失败（未配置 Key / 网络 / 余额不足 / 音色无效）
  /// 均返回 null，由上层静默降级到系统 TTS。
  Future<Uint8List?> _fetchTTS(String text, String voiceId, double speed) async {
    // 未配置真实 Key 时直接失败，让上层降级到系统 TTS
    if (!isConfigured) return null;
    try {
      final resp = await _dio.post(
        _apiUrl,
        data: {
          'model': _model,
          'text': text,
          'stream': false,
          'output_format': 'hex',
          'voice_setting': {
            'voice_id': voiceId,
            'speed': speed,
            'vol': 1,
            'pitch': 0,
          },
          'audio_setting': {
            'sample_rate': 32000,
            'bitrate': 128000,
            'format': 'mp3',
            'channel': 1,
          },
          'subtitle_enable': false,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'application/json',
          },
          responseType: ResponseType.json,
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      final data = resp.data as Map<String, dynamic>?;
      if (data == null) return null;

      // 业务状态码：0 = 成功；1008 = 余额不足
      final baseResp = data['base_resp'] as Map<String, dynamic>?;
      final statusCode = baseResp?['status_code'] as int? ?? -1;
      if (statusCode != 0) {
        // 余额不足等错误，打印一次便于排查，但不抛异常（上层降级）
        // ignore: avoid_print
        print(
          '[MiniMaxTTS] 合成失败 status_code=$statusCode '
          'msg=${baseResp?['status_msg']}',
        );
        return null;
      }

      final audioField =
          (data['data'] as Map<String, dynamic>?)?['audio'] ??
          (data['data'] as Map<String, dynamic>?)?['audio_file'];
      if (audioField == null) return null;
      final audioStr = audioField.toString();
      if (audioStr.isEmpty) return null;

      // 新平台返回 hex；兼容可能的 base64 回退
      try {
        return _hexToBytes(audioStr);
      } on FormatException {
        try {
          return base64Decode(audioStr);
        } catch (_) {
          return null;
        }
      }
    } catch (e) {
      // 网络异常 / 超时 / 解析失败，静默降级
      // ignore: avoid_print
      print('[MiniMaxTTS] 请求异常：$e');
      return null;
    }
  }

  /// 把 hex 字符串解码为字节
  static Uint8List _hexToBytes(String hex) {
    final clean = hex.replaceAll(RegExp(r'\s+'), '');
    if (clean.length % 2 != 0) throw const FormatException('invalid hex');
    final bytes = Uint8List(clean.length ~/ 2);
    for (int i = 0; i < bytes.length; i++) {
      bytes[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
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
      contentType: 'audio/mpeg',
      stream: Stream.value(_bytes.sublist(start, end)),
    );
  }
}
