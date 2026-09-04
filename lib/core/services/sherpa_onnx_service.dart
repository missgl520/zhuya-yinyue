// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Sherpa-ONNX 本地语音服务
//
// 完全离线：ASR（语音识别）+ TTS（语音合成）
// 基于 ONNX Runtime 推理，无需网络
//
// 模型下载：python3 tools/download_sherpa_models.py --out ./sherpa_models
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sherpa_onnx/sherpa_onnx.dart' as sp;

/// ASR 回调
typedef AsrResultCallback = void Function(String text, bool isFinal);

/// Sherpa-ONNX ASR 配置
class SherpaAsrConfig {
  /// 模型文件路径 (.onnx)
  final String modelPath;
  /// 词表文件路径 (tokens.txt)
  final String tokensPath;
  /// 采样率（默认16000）
  final int sampleRate;
  /// 推理线程数（默认1，移动端省电）
  final int numThreads;

  const SherpaAsrConfig({
    required this.modelPath,
    required this.tokensPath,
    this.sampleRate = 16000,
    this.numThreads = 1,
  });
}

/// Sherpa-ONNX TTS 配置
class SherpaTtsConfig {
  /// 模型文件路径 (.onnx)
  final String modelPath;
  /// 词表文件路径 (tokens.txt)
  final String tokensPath;
  /// 音素词典 (lexicon.txt)
  final String lexiconPath;
  /// 说话人ID（多音色模型时指定，默认0）
  final int speakerId;
  /// 语速（1.0=正常）
  final double speed;
  /// 音高（1.0=正常）
  final double pitch;
  /// 音量（1.0=正常）
  final double volume;

  const SherpaTtsConfig({
    required this.modelPath,
    required this.tokensPath,
    required this.lexiconPath,
    this.speakerId = 0,
    this.speed = 1.0,
    this.pitch = 1.0,
    this.volume = 1.0,
  });
}

/// Sherpa-ONNX 语音服务
///
/// 使用前必须先调用 [initialize()]。
/// 模型下载：python3 tools/download_sherpa_models.py
class SherpaOnnxService {
  static final SherpaOnnxService _instance = SherpaOnnxService._();
  factory SherpaOnnxService() => _instance;
  SherpaOnnxService._();

  bool _initialized = false;
  bool get isInitialized => _initialized;

  sp.OfflineRecognizer? _recognizer;
  SherpaAsrConfig? _lastAsrConfig;

  sp.OfflineTts? _tts;
  SherpaTtsConfig? _lastTtsConfig;

  // ════════════════════════════════════════════════════════
  // 初始化
  // ════════════════════════════════════════════════════════

  /// 初始化服务（必须先调用）
  ///
  /// [modelsDir] 模型根目录，需包含：
  ///   asr/model.onnx + asr/tokens.txt
  ///   tts/model.onnx + tts/tokens.txt + tts/lexicon.txt
  ///
  /// 示例：
  /// ```dart
  /// await SherpaOnnxService().initialize(
  ///   modelsDir: 'assets/sherpa_models',
  /// );
  /// ```
  Future<void> initialize({String? modelsDir}) async {
    if (_initialized) return;

    // 初始化 native bindings（必须在使用任何 API 前调用）
    await sp.initBindingsAsync();

    _initialized = true;

    if (modelsDir != null) {
      await _preloadAll(modelsDir);
    }
  }

  Future<void> _preloadAll(String modelsDir) async {
    final asrModel  = p.join(modelsDir, 'asr', 'model.onnx');
    final asrTokens = p.join(modelsDir, 'asr', 'tokens.txt');
    final ttsModel  = p.join(modelsDir, 'tts', 'model.onnx');
    final ttsTokens = p.join(modelsDir, 'tts', 'tokens.txt');
    final ttsLex    = p.join(modelsDir, 'tts', 'lexicon.txt');

    if (await File(asrModel).exists()) {
      await recognizeFile(asrModel, SherpaAsrConfig(
        modelPath: asrModel,
        tokensPath: asrTokens,
      ));
      _recognizer?.dispose();
      _recognizer = null;
    }

    if (await File(ttsModel).exists()) {
      await synthesize('测', SherpaTtsConfig(
        modelPath: ttsModel,
        tokensPath: ttsTokens,
        lexiconPath: ttsLex,
      ), '/dev/null');
      _tts?.free();
      _tts = null;
    }
  }

  // ════════════════════════════════════════════════════════
  // ASR 语音识别
  // ════════════════════════════════════════════════════════

  /// 识别音频文件 → 文字
  Future<String> recognizeFile(String audioPath, SherpaAsrConfig config) async {
    _ensureInitialized();

    final file = File(audioPath);
    if (!await file.exists()) {
      throw Exception('音频文件不存在: $audioPath');
    }

    final recognizer = _buildRecognizer(config);
    final stream = recognizer.createStream();

    try {
      final waveData = sp.readWave(audioPath);
      stream.acceptWaveform(
        samples: waveData.samples,
        sampleRate: waveData.sampleRate,
      );
      recognizer.decode(stream);
      final result = recognizer.getResult(stream);
      final text = result.text.trim();
      stream.free();
      recognizer.free();
      return text;
    } catch (e) {
      stream.free();
      recognizer.free();
      rethrow;
    }
  }

  /// 识别 WAV PCM 数据 → 文字
  ///
  /// [wavBytes] WAV 文件字节数据（header + PCM）
  Future<String> recognizeWavBytes(Uint8List wavBytes, SherpaAsrConfig config) async {
    _ensureInitialized();

    final recognizer = _buildRecognizer(config);
    final stream = recognizer.createStream();

    try {
      // 解析 WAV header 提取采样率和数据
      final sampleRate = _parseWavSampleRate(wavBytes);
      final samples = _parseWavSamples(wavBytes);

      stream.acceptWaveform(samples: samples, sampleRate: sampleRate);
      recognizer.decode(stream);
      final result = recognizer.getResult(stream);
      final text = result.text.trim();
      stream.free();
      recognizer.free();
      return text;
    } catch (e) {
      stream.free();
      recognizer.free();
      rethrow;
    }
  }

  /// 流式识别（麦克风实时输入）
  SherpaAsrRecognizer startListening(SherpaAsrConfig config) {
    _ensureInitialized();
    return SherpaAsrRecognizer._(config, this);
  }

  sp.OfflineRecognizer _buildRecognizer(SherpaAsrConfig config) {
    final paraformer = sp.OfflineParaformerModelConfig(
      model: config.modelPath,
    );

    final modelConfig = sp.OfflineModelConfig(
      paraformer: paraformer,
      tokens: config.tokensPath,
      numThreads: config.numThreads,
      debug: kDebugMode,
      modelType: 'paraformer',
    );

    final recognizerConfig = sp.OfflineRecognizerConfig(model: modelConfig);
    return sp.OfflineRecognizer(recognizerConfig);
  }

  // ════════════════════════════════════════════════════════
  // TTS 语音合成
  // ════════════════════════════════════════════════════════

  /// 合成文字 → WAV 文件
  ///
  /// [text] 要合成的文本
  /// [config] TTS 配置
  /// [outputPath] 输出路径（.wav）
  Future<String?> synthesize(
    String text,
    SherpaTtsConfig config,
    String outputPath,
  ) async {
    _ensureInitialized();

    if (text.trim().isEmpty) return null;

    final tts = _buildTts(config);
    final genConfig = sp.OfflineTtsGenerationConfig(
      sid: config.speakerId,
      speed: config.speed,
      volume: config.volume,
      pitch: config.pitch,
    );

    try {
      final audio = tts.generateWithConfig(text: text, config: genConfig);
      tts.free();

      sp.writeWave(
        filename: outputPath,
        samples: audio.samples,
        sampleRate: audio.sampleRate,
      );
      return outputPath;
    } catch (e) {
      tts.free();
      rethrow;
    }
  }

  /// 合成文字 → WAV 字节数据
  Future<Uint8List?> synthesizeToBytes(
    String text,
    SherpaTtsConfig config,
  ) async {
    final tempDir = await getTemporaryDirectory();
    final path = p.join(
      tempDir.path,
      'tts_${DateTime.now().millisecondsSinceEpoch}.wav',
    );

    final result = await synthesize(text, config, path);
    if (result != null && await File(result).exists()) {
      final bytes = await File(result).readAsBytes();
      await File(result).delete();
      return bytes;
    }
    return null;
  }

  sp.OfflineTts _buildTts(SherpaTtsConfig config) {
    final vits = sp.OfflineTtsVitsModelConfig(
      model: config.modelPath,
      lexicon: config.lexiconPath,
      tokens: config.tokensPath,
    );

    final modelConfig = sp.OfflineTtsModelConfig(
      vits: vits,
      numThreads: 1,
      debug: kDebugMode,
    );

    final ttsConfig = sp.OfflineTtsConfig(
      model: modelConfig,
      maxNumSenetences: 1,
    );

    return sp.OfflineTts(ttsConfig);
  }

  // ════════════════════════════════════════════════════════
  // WAV 工具
  // ════════════════════════════════════════════════════════

  int _parseWavSampleRate(Uint8List bytes) {
    if (bytes.length < 44) return 16000;
    // RIFF header offset 24: 4字节采样率 (little-endian)
    return bytes[24] | (bytes[25] << 8) | (bytes[26] << 16) | (bytes[27] << 24);
  }

  Float32List _parseWavSamples(Uint8List bytes) {
    // 跳过 44 字节 WAV header
    final dataStart = 44;
    if (bytes.length <= dataStart) return Float32List(0);

    final pcm16 = bytes.sublist(dataStart);
    final samples = Float32List(pcm16.length ~/ 2);

    for (int i = 0; i < samples.length; i++) {
      final pcm = pcm16[i * 2] | (pcm16[i * 2 + 1] << 8);
      samples[i] = pcm > 32767 ? (pcm - 65536) / 32768.0 : pcm / 32768.0;
    }
    return samples;
  }

  // ════════════════════════════════════════════════════════
  // 资源清理
  // ════════════════════════════════════════════════════════

  void dispose() {
    _recognizer?.free();
    _tts?.free();
    _recognizer = null;
    _tts = null;
    _initialized = false;
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw Exception(
        'SherpaOnnxService 未初始化。\n'
        '请先调用: await SherpaOnnxService().initialize();\n'
        '模型下载: python3 tools/download_sherpa_models.py',
      );
    }
  }
}

// ════════════════════════════════════════════════════════════════════════
// ASR 流式识别器（麦克风实时输入）
// ════════════════════════════════════════════════════════════════════════

/// Sherpa-ONNX 流式识别器
///
/// 使用流程：
/// ```dart
/// final recognizer = service.startListening(config);
/// recognizer.onPartialResult = (text) => print('中间: \$text');
/// recognizer.onResult = (text) => print('最终: \$text');
/// recognizer.start();   // 开始监听麦克风
/// // ...
/// recognizer.stop();    // 停止
/// ```
class SherpaAsrRecognizer {
  final SherpaAsrConfig config;
  final SherpaOnnxService _service;

  SherpaAsrRecognizer._(this.config, this._service);

  bool _isRunning = false;
  bool get isRunning => _isRunning;

  /// 最终结果回调
  AsrResultCallback? onResult;

  /// 中间结果回调（实时识别文字）
  AsrResultCallback? onPartialResult;

  sp.OnlineRecognizer? _recognizer;
  sp.OnlineStream? _stream;
  Timer? _pollTimer;
  String _lastText = '';
  int _silenceCount = 0;
  static const int _silenceThreshold = 8;

  /// 开始监听麦克风
  ///
  /// FIXME: 当前为占位实现，需接入真实麦克风录音。
  /// 推荐使用 `record` 包：
  /// ```dart
  /// import 'package:record/record.dart';
  /// final recorder = AudioRecorder();
  /// await recorder.start(const RecordConfig(
  ///   encoder: AudioEncoder.pcm16bits,
  ///   sampleRate: 16000,
  ///   numChannels: 1,
  /// ));
  /// // 每 100ms 读取一次:
  /// final pcm = await recorder.read();
  /// if (pcm.isNotEmpty) recognizer.pushAudio(Uint8List.fromList(pcm));
  /// ```
  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _silenceCount = 0;
    _lastText = '';

    try {
      final onlineModel = sp.OnlineParaformerModelConfig(
        model: config.modelPath,
      );

      final modelConfig = sp.OnlineModelConfig(
        paraformer: onlineModel,
        tokens: config.tokensPath,
        numThreads: config.numThreads,
      );

      final recognizerConfig = sp.OnlineRecognizerConfig(
        model: modelConfig,
        sampleRate: config.sampleRate,
        featureDim: 80,
        enableEndpoint: true,
        rule1MinTrailingSilence: 2.4,
        rule2MinTrailingSilence: 1.2,
        rule3MinUtteranceLength: 300.0,
      );

      _recognizer = sp.OnlineRecognizer(recognizerConfig);
      _stream = _recognizer!.createStream();

      // 定时轮询麦克风（每 100ms）
      // TODO: 替换为真实麦克风录音（见上方 FIXME）
      _pollTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {});
    } catch (e) {
      debugPrint('[SherpaAsr] 启动失败: $e');
      stop();
    }
  }

  /// 推送原始 PCM 数据（16kHz 16bit mono）
  ///
  /// 外部录音器拿到 PCM 后调用此方法即可。
  void pushAudio(List<int> pcm16Data) {
    if (!_isRunning || _recognizer == null || _stream == null || pcm16Data.isEmpty) {
      return;
    }

    try {
      // 转换为 Float32List（Sherpa-ONNX 需要 float 输入）
      final samples = Float32List(pcm16Data.length ~/ 2);
      for (int i = 0; i < samples.length; i++) {
        final pcm = pcm16Data[i * 2] | (pcm16Data[i * 2 + 1] << 8);
        samples[i] = pcm > 32767 ? (pcm - 65536) / 32768.0 : pcm / 32768.0;
      }

      _stream!.acceptWaveform(samples: samples, sampleRate: config.sampleRate);
      _recognizer!.decode(_stream!);

      // 中间结果
      final partial = _recognizer!.text;
      if (partial.isNotEmpty && partial != _lastText) {
        _lastText = partial;
        _silenceCount = 0;
        onPartialResult?.call(partial, false);
      } else if (partial.isEmpty) {
        _silenceCount++;
        if (_silenceCount >= _silenceThreshold && _lastText.isNotEmpty) {
          onResult?.call(_lastText, true);
          _lastText = '';
          _silenceCount = 0;
          // 重置识别器继续听
          _stream!.free();
          _stream = _recognizer!.createStream();
        }
      }

      // VAD 端点检测
      if (_recognizer!.isEndpoint) {
        final text = _recognizer!.text.trim();
        if (text.isNotEmpty) {
          onResult?.call(text, true);
        }
        _stream!.free();
        _stream = _recognizer!.createStream();
        _lastText = '';
        _silenceCount = 0;
      }
    } catch (e) {
      debugPrint('[SherpaAsr] 推理错误: $e');
    }
  }

  /// 推送 Float32 PCM 数据
  void pushFloat32Audio(List<double> float32Data) {
    if (!_isRunning || _stream == null) return;
    try {
      _stream!.acceptWaveform(
        samples: Float32List.fromList(float32Data),
        sampleRate: config.sampleRate,
      );
      _recognizer!.decode(_stream!);

      final partial = _recognizer!.text;
      if (partial.isNotEmpty && partial != _lastText) {
        _lastText = partial;
        _silenceCount = 0;
        onPartialResult?.call(partial, false);
      }
    } catch (e) {
      debugPrint('[SherpaAsr] push error: $e');
    }
  }

  /// 停止监听
  void stop() {
    _isRunning = false;
    _pollTimer?.cancel();
    _pollTimer = null;
    _stream?.free();
    _recognizer?.free();
    _stream = null;
    _recognizer = null;
    _lastText = '';
    _silenceCount = 0;
  }

  void dispose() => stop();
}
