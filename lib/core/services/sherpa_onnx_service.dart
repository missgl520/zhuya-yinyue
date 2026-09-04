// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Sherpa-ONNX 本地语音服务
//
// 完全离线：ASR（语音识别）+ TTS（语音合成）
// 基于 ONNX Runtime 推理，无需网络
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sherpa_onnx/sherpa_onnx.dart' as sp;

/// ASR 结果回调
typedef AsrResultCallback = void Function(String text, bool isFinal);

/// Sherpa-ONNX ASR 配置
class SherpaAsrConfig {
  final String modelPath;
  final String tokensPath;
  final int sampleRate;
  final bool debug;
  final int? numThreads;

  const SherpaAsrConfig({
    required this.modelPath,
    required this.tokensPath,
    this.sampleRate = 16000,
    this.debug = false,
    this.numThreads,
  });
}

/// Sherpa-ONNX TTS 配置
class SherpaTtsConfig {
  final String modelPath;
  final String tokensPath;
  final String? lexiconPath;
  final String? dataDir;
  final int sampleRate;
  final double speed;
  final double pitch;
  final double volume;
  final int speakerId;

  const SherpaTtsConfig({
    required this.modelPath,
    required this.tokensPath,
    this.lexiconPath,
    this.dataDir,
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

  sp.OfflineRecognizer? _offlineRecognizer;
  sp.OnlineRecognizer? _onlineRecognizer;
  sp.Synthesizer? _synthesizer;

  SherpaAsrConfig? _lastAsrConfig;
  SherpaTtsConfig? _lastTtsConfig;

  // ════════════════════════════════════════════════════════
  // 初始化
  // ════════════════════════════════════════════════════════

  /// 初始化服务
  ///
  /// [modelsDir] 模型根目录，含：
  ///   asr/model.onnx + asr/tokens.txt
  ///   tts/model.onnx + tts/tokens.txt + tts/lexicon.txt（可选）
  Future<void> initialize({String? modelsDir}) async {
    if (_initialized) return;
    _initialized = true;

    if (modelsDir != null) {
      await _preloadAll(modelsDir);
    }
  }

  /// 预加载全部模型（减少首次推理延迟）
  Future<void> _preloadAll(String modelsDir) async {
    final asrModel  = p.join(modelsDir, 'asr', 'model.onnx');
    final asrTokens = p.join(modelsDir, 'asr', 'tokens.txt');
    final ttsModel  = p.join(modelsDir, 'tts', 'model.onnx');
    final ttsTokens = p.join(modelsDir, 'tts', 'tokens.txt');
    final lexicon   = p.join(modelsDir, 'tts', 'lexicon.txt');

    if (await File(asrModel).exists()) {
      await _initOfflineAsr(SherpaAsrConfig(
        modelPath: asrModel,
        tokensPath: asrTokens,
      ));
    }

    if (await File(ttsModel).exists()) {
      await _initTts(SherpaTtsConfig(
        modelPath: ttsModel,
        tokensPath: ttsTokens,
        lexiconPath: await File(lexicon).exists() ? lexicon : null,
      ));
    }
  }

  // ════════════════════════════════════════════════════════
  // ASR 语音识别
  // ════════════════════════════════════════════════════════

  Future<void> _initOfflineAsr(SherpaAsrConfig config) async {
    try {
      final onlineModel = sp.OnlineModelConfig();
      onlineModel.paraformer.set(config.modelPath, config.tokensPath);

      final featConfig = sp.FeatureConfig()
        ..sampleRate = config.sampleRate
        ..featureDim = 80;

      final cfg = sp.RecognizerConfig()
        ..onlineModelConfig = onlineModel
        ..featConfig = featConfig
        ..enableEndpoint = true
        ..rule1MinTrailingSilence = 2.4
        ..rule2MinTrailingSilence = 1.2
        ..rule3MinUtteranceLength = 300.0;

      if (config.numThreads != null) {
        cfg.modelConfig.numThreads = config.numThreads!;
      }

      _lastAsrConfig = config;
      _offlineRecognizer = sp.OfflineRecognizer(cfg);
    } catch (e) {
      debugPrint('[SherpaOnnx] ASR init failed: $e');
    }
  }

  /// 识别音频文件 → 文字
  Future<String> recognizeFile(String audioPath, SherpaAsrConfig config) async {
    _ensureInitialized();

    final file = File(audioPath);
    if (!await file.exists()) {
      throw Exception('音频文件不存在: $audioPath');
    }

    _offlineRecognizer ?? await _initOfflineAsr(config);
    if (_offlineRecognizer == null) {
      throw Exception('ASR 模型未初始化');
    }

    final stream = _offlineRecognizer!.createStream();
    try {
      await stream.decodeFile(audioPath);
      return stream.result.text.trim();
    } finally {
      stream.dispose();
    }
  }

  /// 识别 WAV/PCM 字节数据 → 文字
  Future<String> recognizeBytes(Uint8List bytes, SherpaAsrConfig config) async {
    _ensureInitialized();

    _offlineRecognizer ?? await _initOfflineAsr(config);
    if (_offlineRecognizer == null) {
      throw Exception('ASR 模型未初始化');
    }

    final stream = _offlineRecognizer!.createStream();
    try {
      stream.acceptWaveform(bytes, config.sampleRate);
      _offlineRecognizer!.decode(stream);
      return stream.result.text.trim();
    } finally {
      stream.dispose();
    }
  }

  /// 流式识别（麦克风实时输入）
  SherpaAsrRecognizer startListening(SherpaAsrConfig config) {
    _ensureInitialized();
    return SherpaAsrRecognizer._(config, this);
  }

  // ════════════════════════════════════════════════════════
  // TTS 语音合成
  // ════════════════════════════════════════════════════════

  Future<void> _initTts(SherpaTtsConfig config) async {
    try {
      final vits = sp.VitsModelConfig()
        ..model = config.modelPath
        ..tokens = config.tokensPath
        ..lexicon = config.lexiconPath
        ..dataDir = config.dataDir;

      final ttsCfg = sp.SynthesizerConfig()
        ..modelConfig = vits
        ..sampleRate = config.sampleRate
        ..speed = config.speed
        ..pitch = config.pitch
        ..volume = config.volume;

      _lastTtsConfig = config;
      _synthesizer = sp.Synthesizer(ttsCfg);
    } catch (e) {
      debugPrint('[SherpaOnnx] TTS init failed: $e');
    }
  }

  /// 合成文字 → WAV 文件
  Future<String?> synthesize(
    String text,
    SherpaTtsConfig config,
    String outputPath,
  ) async {
    _ensureInitialized();

    if (text.trim().isEmpty) return null;

    _synthesizer ?? await _initTts(config);
    if (_synthesizer == null) {
      throw Exception('TTS 模型未初始化');
    }

    final audio = _synthesizer!.generate(
      text,
      sid: config.speakerId,
      speed: config.speed,
    );

    final outFile = File(outputPath);
    await outFile.parent.create(recursive: true);
    await outFile.writeAsBytes(audio);
    return outputPath;
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

  // ════════════════════════════════════════════════════════
  // 资源清理
  // ════════════════════════════════════════════════════════

  void dispose() {
    _offlineRecognizer?.dispose();
    _onlineRecognizer?.dispose();
    _synthesizer?.dispose();
    _offlineRecognizer = null;
    _onlineRecognizer = null;
    _synthesizer = null;
    _initialized = false;
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw Exception('SherpaOnnxService 未初始化，请先调用 initialize()');
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
/// recognizer.onPartialResult = (text) => print('中间: $text');
/// recognizer.onResult = (text) => print('最终: $text');
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
  Timer? _pollTimer;
  String _lastText = '';
  int _silenceCount = 0;
  static const int _silenceThreshold = 8; // 连续静音帧数阈值

  /// 开始监听麦克风
  ///
  /// FIXME: 当前使用占位轮询，需接入真实麦克风录音。
  /// 推荐使用 `record` 包：
  /// ```dart
  /// import 'package:record/record.dart';
  /// final recorder = AudioRecorder();
  /// await recorder.start(const RecordConfig(
  ///   encoder: AudioEncoder.pcm16bits,
  ///   sampleRate: 16000,
  ///   numChannels: 1,
  /// ));
  /// // 定时读取:
  /// final pcm = await recorder.read();
  /// if (pcm.isNotEmpty) recognizer.pushAudio(pcm);
  /// ```
  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _silenceCount = 0;
    _lastText = '';

    try {
      final onlineModel = sp.OnlineModelConfig();
      onlineModel.paraformer.set(config.modelPath, config.tokensPath);

      final featConfig = sp.FeatureConfig()
        ..sampleRate = config.sampleRate
        ..featureDim = 80;

      final cfg = sp.RecognizerConfig()
        ..onlineModelConfig = onlineModel
        ..featConfig = featConfig
        ..enableEndpoint = true
        ..rule1MinTrailingSilence = 2.4
        ..rule2MinTrailingSilence = 1.2
        ..rule3MinUtteranceLength = 300.0;

      if (config.numThreads != null) {
        cfg.modelConfig.numThreads = config.numThreads!;
      }

      _recognizer = sp.OnlineRecognizer(cfg);

      // 定时轮询麦克风（每 100ms）
      // TODO: 替换为真实麦克风录音（见上方 FIXME）
      _pollTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        // 这里调用 pushAudio(yourRealMicData) 即可
      });
    } catch (e) {
      debugPrint('[SherpaAsr] 启动失败: $e');
      stop();
    }
  }

  /// 推送原始 PCM 数据（16kHz 16bit mono）
  ///
  /// 外部录音器拿到 PCM 后调用此方法即可。
  void pushAudio(List<int> pcm16Data) {
    if (!_isRunning || _recognizer == null || pcm16Data.isEmpty) return;

    try {
      _recognizer!.acceptWaveform(pcm16Data, config.sampleRate);

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
          _recognizer!.reset();
        }
      }

      // VAD 端点检测 → 返回最终结果
      if (_recognizer!.isEndpoint) {
        final text = _recognizer!.text.trim();
        if (text.isNotEmpty) {
          onResult?.call(text, true);
        }
        _recognizer!.reset();
        _lastText = '';
        _silenceCount = 0;
      }
    } catch (e) {
      debugPrint('[SherpaAsr] 推理错误: $e');
    }
  }

  /// 推送 Float32 PCM 数据
  void pushFloat32Audio(List<double> float32Data) {
    final pcm16 = float32Data
        .map((v) => (v * 32767).clamp(-32768.0, 32767.0).toInt())
        .toList();
    final bytes = ByteData(pcm16.length * 2);
    for (int i = 0; i < pcm16.length; i++) {
      bytes.setInt16(i * 2, pcm16[i], Endian.little);
    }
    pushAudio(bytes.buffer.asUint8List().toList());
  }

  /// 停止监听
  void stop() {
    _isRunning = false;
    _pollTimer?.cancel();
    _pollTimer = null;
    _recognizer?.dispose();
    _recognizer = null;
    _lastText = '';
    _silenceCount = 0;
  }

  void dispose() => stop();
}
