// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MiniMax TTS 服务 v2（情感语音合成）
//
// 接入 MiniMax Sambert 情感语音 API，比 IndexTTS 更有感情。
// 支持多情感标签：happy / sad / shy / cute / neutral / excited
//
// 接入方式：
//   1. 在设置页填入 MiniMax API Key（存 Hive，加密）
//   2. 选择 TTS 模式为 "minimax"
//   3. 每次 speak() 自动携带当前情绪标签
//
// MiniMax Sambert API 文档：https://www.minimaxi.com/document
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

/// MiniMax Sambert 情感标签 → API voice_id 映射
/// voice_id 来源于 MiniMax 控制台音色列表
const Map<String, String> kEmotionVoiceMap = {
  'happy':    'HappyBoy',       // 活泼开朗
  'sad':      'GentleGirl',     // 温柔伤感
  'shy':      'CuteGirl',       // 害羞可爱
  'cute':     'CuteBoy',        // 活泼俏皮
  'neutral':  'StableMale',     // 平稳男声（默认）
  'excited':  'CuteBoy',        // 兴奋激动
};

/// MiniMax Sambert 情感标签 → 语速
const Map<String, double> kEmotionSpeedMap = {
  'happy':    1.15,
  'sad':      0.85,
  'shy':      0.90,
  'cute':     1.10,
  'neutral':  1.00,
  'excited':  1.25,
};

/// MiniMax TTS 服务（情感语音合成）
class MiniMaxTtsService {
  final AudioPlayer _player = AudioPlayer();
  bool _initialized = false;
  String? _apiKey;
  bool _available = true;

  bool get isAvailable => _available;
  bool get isPlaying => _player.playing;

  /// 设置 API Key（从设置页读取后传入）
  void configure({required String apiKey}) {
    _apiKey = apiKey.trim();
  }

  /// 初始化播放器
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      _player.playerStateStream.listen((s) {
        // 播放完成自动清理
      });
    } catch (_) {
      _available = false;
    }
  }

  /// 朗读文本（MiniMax Sambert 情感语音）
  /// [emotion] — 当前对话情绪，会影响音色选择
  Future<void> speak(
    String text, {
    String emotion = 'neutral',
  }) async {
    if (!_initialized) await init();
    if (!_available || _apiKey == null || _apiKey!.isEmpty) return;

    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    // 停掉之前的播放
    await _player.stop();

    try {
      // ── MiniMax Sambert TTS API ──────────────────────
      final voiceId = kEmotionVoiceMap[emotion] ?? kEmotionVoiceMap['neutral']!;
      final speed   = kEmotionSpeedMap[emotion]  ?? 1.0;

      final body = jsonEncode({
        'model':      'speech-02-hd',  // 高质量模型
        'text':       trimmed,
        'stream':     false,
        'voice_setting': {
          'voice_id': voiceId,
          'speed':    speed,
          'pitch':    0,
          'volume':   0,
        },
        'audio_setting': {
          'sample_rate': 32000,
          'bitrate':     128000,
          'format':      'mp3',
        },
      });

      final resp = await http.post(
        Uri.parse('https://api.minimax.io/v1/t2a_v2'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type':  'application/json',
        },
        body: body,
      ).timeout(const Duration(seconds: 30));

      if (resp.statusCode != 200) {
        _available = false;
        return;
      }

      // ── 保存 + 播放 ──────────────────────────────────
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/zhuyu_mm_${DateTime.now().microsecondsSinceEpoch}.mp3',
      );
      await file.writeAsBytes(resp.bodyBytes);

      try {
        await _player.setAudioSource(AudioSource.file(file.path));
        await _player.play();
        // 等待播放完成
        final done = Completer<void>();
        late final StreamSubscription<PlayerState> sub;
        sub = _player.playerStateStream.listen((s) {
          if (s.processingState == ProcessingState.completed) {
            sub.cancel();
            if (!done.isCompleted) done.complete();
          }
        });
        await done.future.timeout(const Duration(seconds: 60), onTimeout: () {
          sub.cancel();
        });
      } finally {
        try { await file.delete(); } catch (_) {}
      }
    } catch (_) {
      // 失败静默降级
      _available = false;
    }
  }

  /// 停止朗读
  Future<void> stop() async {
    try { await _player.stop(); } catch (_) {}
  }

  /// 释放资源
  Future<void> dispose() async {
    await _player.dispose();
  }
}
