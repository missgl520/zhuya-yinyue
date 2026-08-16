// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// TTS 服务（Text-to-Speech / 文字转语音）
//
// 底层依赖：flutter_tts，调用系统语音引擎
// - Android：系统 TTS（MIUI 使用小米离线引擎）
// - iOS：AVSpeechSynthesizer
//
// 配置项：
//   speechRate  语速（0.0-1.0，默认 0.5）
//   pitch       音调（0.5-2.0，默认 1.0）
//   volume      音量（0.0-1.0，默认 1.0）
//   language    语言（zh-CN=中文）
//
// awaitSpeakCompletion=true：
//   speak() 在语音播完前会阻塞，确保 AI 回复完整朗读后再继续
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _tts = FlutterTts();

  bool _isInitialized = false;
  bool _isPlaying = false;

  /// 当前是否正在播放
  bool get isPlaying => _isPlaying;

  // ── 初始化 ──
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      await _tts.setLanguage('zh-CN');
      await _tts.setSpeechRate(0.5);   // 适中语速
      await _tts.setVolume(1.0);       // 全音量
      await _tts.setPitch(1.0);        // 正常音调

      // 阻塞等待播完，避免 AI 回复和语音交叉
      await _tts.awaitSpeakCompletion(true);

      // 回调：记录播放状态（供 UI 显示竹笌"在说"）
      _tts.setStartHandler(()  => _isPlaying = true);
      _tts.setCompletionHandler(() => _isPlaying = false);
      _tts.setErrorHandler((_) => _isPlaying = false);
      _tts.setCancelHandler(()  => _isPlaying = false);
    } catch (e) {
      // 部分设备/模拟器无系统 TTS 引擎（如国产无 GMS 机型），初始化会失败。
      // 捕获后保持「已初始化但不可用」状态：文字照常显示，仅跳过朗读，不崩。
      _isInitialized = true;
      _ttsAvailable = false;
    }
  }

  /// 系统 TTS 引擎是否可用（无引擎时 UI 可据此禁用「朗读」入口）
  bool get ttsAvailable => _ttsAvailable;
  bool _ttsAvailable = true;

  // ── 朗读文本 ──
  Future<void> speak(String text) async {
    if (!_isInitialized) await init();
    if (!_ttsAvailable) return; // 无引擎，静默跳过，文字仍正常显示
    try {
      await _tts.speak(text);
    } catch (_) {
      // 朗读失败不阻断对话流程
      _isPlaying = false;
    }
  }

  // ── 停止朗读 ──
  Future<void> stop() async {
    await _tts.stop();
    _isPlaying = false;
  }

  // ── 调节语速 ──
  Future<void> setRate(double rate) async {
    await _tts.setSpeechRate(rate.clamp(0.0, 1.0));
  }

  // ── 调节音调 ──
  Future<void> setPitch(double pitch) async {
    await _tts.setPitch(pitch.clamp(0.5, 2.0));
  }

  void dispose() {
    _tts.stop();
  }
}
