// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Sherpa-ONNX 本地语音服务
//
// 完全离线：ASR（语音识别）+ TTS（语音合成）
// 基于 ONNX Runtime 推理，无需网络
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// ASR 结果回调
typedef AsrResultCallback = void Function(String text, bool isFinal);

/// Sherpa-ONNX ASR 配置
class SherpaAsrConfig {
  /// 模型文件路径 (.onnx)
  final String modelPath;
  /// 词表文件路径 (tokens.txt)
  final String tokensPath;
  /// 采样率（默认16000）
  final int sampleRate;
  /// 是否debug模式
  final bool debug;

  const SherpaAsrConfig({
    required this.modelPath,
    required this.tokensPath,
    this.sampleRate = 16000,
    this.debug = false,
  });
}

/// Sherpa-ONNX TTS 配置
class SherpaTtsConfig {
  /// 模型文件路径 (.onnx)
  final String modelPath;
  /// 词表文件路径 (tokens.txt)
  final String tokensPath;
  /// 音素词典 (lexicon.txt，可选)
  final String? lexiconPath;
  /// 输出采样率（默认24000）
  final int sampleRate;
  /// 语速（1.0=正常）
  final double speed;
  /// 音高（1.0=正常）
  final double pitch;
  /// 音量（1.0=正常）
  final double volume;
  /// 说话人ID（多音色模型时指定）
  final int speakerId;

  const SherpaTtsConfig({
    required this.modelPath,
    required this.tokensPath,
    this.lexiconPath,
    this.sampleRate = 24000,
    this.speed = 1.0,
    this.pitch = 1.0,
    this.volume = 1.0,
    this.speakerId = 0,
  });
}

/// Sherpa-ONNX 语音服务
class SherpaOnnxService {
  static final SherpaOnnxService _instance = SherpaOnnxService._();
  factory SherpaOnnxService() => _instance;
  SherpaOnnxService._();

  bool _initialized = false;
  bool get isInitialized => _initialized;

  /// 模型管理器（延迟加载避免循环依赖）
  dynamic _modelManager;

  // ════════════════════════════════════════════════════════
  // 初始化
  // ════════════════════════════════════════════════════════

  /// 初始化服务
  Future<void> initialize({String? modelsDir}) async {
    if (_initialized) return;

    // 获取模型路径（从 ModelManager）
    // ignore: avoid_dynamic_calls
    _modelManager ??= _getModelManager();

    // 模型文件已在 ModelManager.initializeModels() 时准备好
    // 这里只做内存初始化
    _initialized = true;
  }

  dynamic _getModelManager() {
    // 懒加载 ModelManager（避免循环 import）
    // 实际使用时通过 sherpa_onnx_provider 注入
    return null;
  }

  // ════════════════════════════════════════════════════════
  // ASR 语音识别
  // ════════════════════════════════════════════════════════

  /// 识别音频文件 → 文字
  ///
  /// [audioPath] 音频文件路径（支持 wav/pcm/s16le）
  Future<String> recognizeFile(String audioPath, SherpaAsrConfig config) async {
    _ensureInitialized();

    try {
      // ── sherpa_onnx 离线识别 ──
      // final recognizer = OfflineRecognizer(
      //   model: config.modelPath,
      //   tokens: config.tokensPath,
      //   sampleRate: config.sampleRate,
      // );
      // final stream = recognizer.createStream();
      // await stream.decodeFile(audioPath);
      // final text = stream.result.text;
      // recognizer.free();
      // return text;

      // TODO: 集成 sherpa_onnx 实际 API
      // 占位返回，实际替换为上面代码
      return _placeholderRecognize(audioPath, config);
    } catch (e) {
      throw Exception('ASR识别失败: $e');
    }
  }

  /// 流式识别（麦克风实时输入）
  ///
  /// ```dart
  /// final recognizer = service.startListening(config);
  /// recognizer.onPartialResult = (text) => print('中间: $text');
  /// recognizer.onResult = (text) => print('最终: $text');
  /// recognizer.start();  // 开始监听麦克风
  /// // ...
  /// recognizer.stop();   // 停止
  /// ```
  SherpaAsrRecognizer startListening(SherpaAsrConfig config) {
    _ensureInitialized();
    return SherpaAsrRecognizer._(config, this);
  }

  // ════════════════════════════════════════════════════════
  // TTS 语音合成
  // ════════════════════════════════════════════════════════

  /// 合成文字 → WAV 文件
  ///
  /// [text] 要合成的文本（中文）
  /// [config] TTS 配置
  /// [outputPath] 输出路径（.wav）
  Future<String?> synthesize(String text, SherpaTtsConfig config, String outputPath) async {
    _ensureInitialized();

    if (text.trim().isEmpty) return null;

    try {
      // ── sherpa_onnx TTS ──
      // final tts = Synthesizer(
      //   model: config.modelPath,
      //   tokens: config.tokensPath,
      //   lexicon: config.lexiconPath,
      //   sampleRate: config.sampleRate,
      // );
      // final audio = tts.generate(
      //   text,
      //   speed: config.speed,
      //   pitch: config.pitch,
      //   volume: config.volume,
      //   sid: config.speakerId,
      // );
      // await File(outputPath).writeAsBytes(audio);
      // tts.free();
      // return outputPath;

      // TODO: 集成 sherpa_onnx 实际 API
      // 占位返回，实际替换为上面代码
      return _placeholderSynthesize(text, config, outputPath);
    } catch (e) {
      throw Exception('TTS合成失败: $e');
    }
  }

  /// 合成文字 → WAV 字节数据（不写文件）
  Future<Uint8List?> synthesizeToBytes(String text, SherpaTtsConfig config) async {
    final tempDir = await getTemporaryDirectory();
    final tempPath = p.join(tempDir.path, 'tts_temp_${DateTime.now().millisecondsSinceEpoch}.wav');

    final result = await synthesize(text, config, tempPath);
    if (result != null) {
      final file = File(result);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        await file.delete(); // 清理临时文件
        return bytes;
      }
    }
    return null;
  }

  // ════════════════════════════════════════════════════════
  // 内部方法
  // ════════════════════════════════════════════════════════

  void _ensureInitialized() {
    if (!_initialized) {
      throw Exception('SherpaOnnxService 未初始化，请先调用 initialize()');
    }
  }

  // ── TODO 占位实现（集成时替换为真实 sherpa_onnx API）───

  Future<String> _placeholderRecognize(String audioPath, SherpaAsrConfig config) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return '（ASR 识别结果）';
  }

  Future<String?> _placeholderSynthesize(String text, SherpaTtsConfig config, String outputPath) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return null;
  }
}

/// ASR 流式识别器
class SherpaAsrRecognizer {
  final SherpaAsrConfig config;
  final SherpaOnnxService _service;
  bool _isRunning = false;

  SherpaAsrRecognizer._(this.config, this._service);

  /// 最终结果回调
  AsrResultCallback? onResult;

  /// 中间结果回调（实时识别文字）
  AsrResultCallback? onPartialResult;

  bool get isRunning => _isRunning;

  /// 开始监听麦克风
  ///
  /// 流程：
  /// 1. 启动 AudioRecorder（16kHz mono s16le PCM）
  /// 2. 每 0.5s 将 PCM 数据推送给 ASR 推理
  /// 3. VAD 检测到静音（N 个连续短音频帧）→ 返回最终结果
  void start() {
    if (_isRunning) return;
    _isRunning = true;

    // TODO: 集成实际麦克风录音 + ASR 流式推理
    //
    // 实现思路（参考 sherpa-onnx 官方示例）：
    // ```dart
    // final recorder = AudioRecorder();
    // await recorder.start(RecorderConfig(
    //   encoder: AudioEncoder.pcm16bits,
    //   sampleRate: 16000,
    //   numChannels: 1,
    // ));
    //
    // // 创建在线识别器
    // final recognizer = OnlineRecognizer(
    //   model: config.modelPath,
    //   tokens: config.tokensPath,
    //   sampleRate: 16000,
    // );
    //
    // // 定时读取 PCM 数据
    // Timer.periodic(Duration(milliseconds: 100), (timer) async {
    //   if (!_isRunning) { timer.cancel(); return; }
    //   final samples = await recorder.read();
    //   if (samples.isEmpty) return;
    //
    //   // 推送给 ASR
    //   recognizer.acceptWaveform(samples);
    //
    //   // 获取中间结果
    //   final partial = recognizer.text;
    //   if (partial.isNotEmpty) onPartialResult?.call(partial, false);
    //
    //   // 检查是否结束（VAD）
    //   if (recognizer.isEndpoint) {
    //     final text = recognizer.text;
    //     onResult?.call(text, true);
    //     recognizer.reset(); // 重置继续听
    //   }
    // });
    // ```
  }

  /// 停止监听
  void stop() {
    _isRunning = false;
    // TODO: 停止录音，释放资源
  }

  /// 推送原始 PCM 数据（外部录音时用）
  void pushAudio(List<int> pcm16Data) {
    if (!_isRunning) return;
    // TODO: 将 PCM 16bit 音频数据送给 ASR 流式推理
  }

  void dispose() {
    stop();
  }
}
