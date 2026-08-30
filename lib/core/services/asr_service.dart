// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// ASR 语音识别服务（Automatic Speech Recognition）
//
// 底层依赖：speech_to_text，调用系统语音引擎
// - Android：Google 语音识别 / 小米语音
// - iOS：Apple Speech Framework
//
// 工作流程：
//   用户长按 → startListening() → 系统录音+识别 → onResult 回调
//   用户松开 → stopListening() → 返回最终识别文字
//
// 注意：
// - 需要麦克风权限（permission_handler）
// - 部分设备/语言需联网才能识别
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:speech_to_text/speech_to_text.dart';

class AsrService {
  final SpeechToText _stt = SpeechToText();

  bool _isInitialized = false;
  bool _isListening = false;

  bool get isListening => _isListening;

  List<LocaleName> _availableLocales = [];

  // ── 初始化 ──
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      _availableLocales = await _stt.locales();
      _isInitialized = true;
    } catch (e) {
      // 部分设备/模拟器没有语音识别引擎，locales() 会抛 PlatformException。
      // 捕获后保持未初始化状态，调用方降级为文字输入即可，不阻断 App。
      _isInitialized = false;
    }
  }

  // ── 请求麦克风权限 ──
  // 返回 true = 语音识别可用；false = 设备不支持（如模拟器、无 GMS 机型）。
  // 注意：必须吞掉底层的 PlatformException(recognizerNotAvailable)，否则会在
  // initState 阶段冒泡成 Unhandled Exception 导致红屏。
  Future<bool> requestPermission() async {
    try {
      final ok = await _stt.initialize(
        onStatus: (status) {
          _isListening = status == 'listening';
        },
        onError: (error) {
          _isListening = false;
        },
      );
      _isInitialized = ok;
      return ok;
    } catch (e) {
      _isInitialized = false;
      return false;
    }
  }

  // ── 开始监听 ──
  // onResult: 每次识别到文字时回调（中间结果 + 最终结果）
  // 返回值：是否正常启动
  Future<void> startListening({
    required void Function(String text, bool finalResult) onResult,
    String? localeId,
  }) async {
    if (!_isInitialized) await init();
    if (_isListening) await stopListening();

    _isListening = true;

    await _stt.listen(
      onResult: (result) {
        onResult(result.recognizedWords, result.finalResult);
      },
      listenOptions: SpeechListenOptions(
        localeId: localeId ?? 'zh_CN',
        listenMode: ListenMode.dictation,
        cancelOnError: true,
        partialResults: true, // 中间过程也回调（打字效果）
      ),
    );
  }

  // ── 停止监听 ──
  Future<void> stopListening() async {
    await _stt.stop();
    _isListening = false;
  }

  // ── 工具：找中文 localeId ──
  String? get zhLocaleId {
    final zhCN = _availableLocales.where(
      (l) => l.localeId == 'zh_CN' || l.localeId == 'zh_Hans_CN',
    );
    if (zhCN.isNotEmpty) return zhCN.first.localeId;
    final zh = _availableLocales.where((l) => l.localeId.startsWith('zh'));
    return zh.isNotEmpty ? zh.first.localeId : null;
  }

  void dispose() {
    _stt.cancel();
  }
}
