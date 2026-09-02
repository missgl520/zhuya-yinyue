// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Sherpa-ONNX 本地语音服务
//
// 完全离线：ASR（语音识别）+ TTS（语音合成）
// 基于 ONNX 推理，无需网络
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'dart:io';
import 'dart:async';
import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// ASR 结果回调
typedef AsrResultCallback = void Function(String text, bool isFinal);

/// Sherpa-ONNX ASR 配置
class SherpaAsrConfig {
  final String modelPath;     // .onnx 模型文件路径
  final String tokensPath;    // tokens.txt 路径
  final int sampleRate;       // 采样率（16000）
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
  final String modelPath;     // .onnx 模型文件路径
  final String tokensPath;    // tokens.txt 路径
  final String? speakerPath;  // 多音色模型时需要
  final int sampleRate;       // 输出采样率（24000）
  final double speed;         // 语速（1.0=正常）

  const SherpaTtsConfig({
    required this.modelPath,
    required this.tokensPath,
    this.speakerPath,
    this.sampleRate = 24000,
    this.speed = 1.0,
  });
}

/// 模型下载状态
class ModelDownloadState {
  final String modelName;
  final double progress;  // 0.0~1.0
  final String status;    // 'downloading' | 'done' | 'error'
  final String? error;

  const ModelDownloadState({
    required this.modelName,
    this.progress = 0,
    this.status = 'idle',
    this.error,
  });
}

/// Sherpa-ONNX 语音服务
///
/// 职责：
/// - ASR：实时语音转文字（本地推理）
/// - TTS：文字转语音（本地推理，生成 wav/pcm）
///
/// 模型下载策略：
/// - 模型打包进 assets/（约 50MB，可接受）
/// - 或首次启动从 CDN 下载到 AppDocuments
class SherpaOnnxService {
  static final SherpaOnnxService _instance = SherpaOnnxService._();
  factory SherpaOnnxService() => _instance;
  SherpaOnnxService._();

  bool _initialized = false;

  /// 是否已初始化
  bool get isInitialized => _initialized;

  // ════════════════════════════════════════════════════════
  // 初始化
  // ════════════════════════════════════════════════════════

  /// 初始化服务（加载模型）
  ///
  /// [modelsDir] 模型所在目录，默认从 assets/models/ 复制到 AppDocuments
  Future<void> initialize({String? modelsDir}) async {
    if (_initialized) return;

    final dir = modelsDir ?? await _getDefaultModelsDir();
    await Directory(dir).create(recursive: true);

    // 初始化 ASR 和 TTS（加载到内存）
    _initialized = true;
  }

  Future<String> _getDefaultModelsDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    return p.join(appDir.path, 'sherpa_models');
  }

  // ════════════════════════════════════════════════════════
  // ASR 语音识别
  // ════════════════════════════════════════════════════════

  /// ASR 识别音频文件 → 文字
  ///
  /// [audioPath] 音频文件路径（支持 wav/pcm/s16le）
  /// [config] ASR 配置
  Future<String> recognizeFile(String audioPath, SherpaAsrConfig config) async {
    // TODO: 调用 sherpa_onnx 识别
    // 目前占位，返回空，集成时实现
    return '';
  }

  /// ASR 流式识别（麦克风实时输入）
  ///
  /// 使用方式：
  /// ```dart
  /// final recognizer = service.startListening(config);
  /// recognizer.onResult = (text, final) {
  ///   print('识别: $text');
  ///   if (final) recognizer.stop();
  /// };
  /// recognizer.start();
  /// ```
  SherpaAsrRecognizer startListening(SherpaAsrConfig config) {
    return SherpaAsrRecognizer(config);
  }

  // ════════════════════════════════════════════════════════
  // TTS 语音合成
  // ════════════════════════════════════════════════════════

  /// TTS 合成文字 → 音频文件
  ///
  /// [text] 要合成的文本（中文）
  /// [config] TTS 配置
  /// [outputPath] 输出路径（.wav）
  Future<String?> synthesize(String text, SherpaTtsConfig config, String outputPath) async {
    // TODO: 调用 sherpa_onnx TTS 合成
    // 目前占位
    return null;
  }

  /// TTS 合成文字 → WAV 字节数据（直接播放）
  Future<List<int>?> synthesizeToBytes(String text, SherpaTtsConfig config) async {
    // TODO: 调用 sherpa_onnx TTS 合成到内存
    return null;
  }

  // ════════════════════════════════════════════════════════
  // 模型管理
  // ════════════════════════════════════════════════════════

  /// 检查模型是否已下载
  Future<bool> hasModels() async {
    final dir = await _getDefaultModelsDir();
    final asrModel = File(p.join(dir, 'asr', 'model.onnx'));
    final ttsModel = File(p.join(dir, 'tts', 'model.onnx'));
    return await asrModel.exists() && await ttsModel.exists();
  }

  /// 获取模型大小
  Future<int> getModelsSizeMB() async {
    try {
      final dir = await _getDefaultModelsDir();
      int total = 0;
      await for (final entity in Directory(dir).list(recursive: true)) {
        if (entity is File) total += await entity.length();
      }
      return total ~/ 1024 ~/ 1024;
    } catch (_) {
      return 0;
    }
  }

  /// 清除模型（释放空间）
  Future<void> clearModels() async {
    final dir = await _getDefaultModelsDir();
    await Directory(dir).delete(recursive: true);
  }
}

/// ASR 流式识别器
class SherpaAsrRecognizer {
  final SherpaAsrConfig config;
  bool _isRunning = false;

  SherpaAsrRecognizer(this.config);

  /// 识别结果回调
  AsrResultCallback? onResult;

  /// 识别过程中的中间结果（实时文字）
  AsrResultCallback? onPartialResult;

  bool get isRunning => _isRunning;

  /// 开始监听麦克风
  void start() {
    _isRunning = true;
    // TODO: 启动麦克风录音 + 流式 ASR 推理
    // 1. 启动 AudioRecorder（16kHz mono pcm）
    // 2. 每 0.5s 发送一段音频给 sherpa-onnx
    // 3. onPartialResult 返回中间识别结果
    // 4. VAD 检测到静音 → onResult 返回最终结果
  }

  /// 停止监听
  void stop() {
    _isRunning = false;
    // TODO: 停止录音和推理
  }

  /// 推送音频数据（外部录音时用）
  void pushAudio(List<int> pcm16Data) {
    // TODO: 将 PCM 数据送给 ASR 推理
  }

  void dispose() {
    stop();
  }
}
