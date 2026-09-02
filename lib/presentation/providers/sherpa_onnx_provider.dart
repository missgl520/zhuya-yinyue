// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Sherpa-ONNX 语音服务 Provider
//
// 完整流程：ASR → AI对话 → TTS → 播放
// 模型：Paraformer-zh（ASR）+ Vits中文（TTS）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../core/services/sherpa_onnx_service.dart';
import '../../core/services/model_manager.dart';

/// Sherpa-ONNX 模型管理器
final modelManagerProvider = Provider<ModelManager>((ref) {
  return ModelManager();
});

/// 模型初始化状态
/// isReady = true 时表示模型已就绪，可以开始 ASR/TTS
final modelsReadyProvider = FutureProvider<bool>((ref) async {
  final mm = ref.watch(modelManagerProvider);
  // 首次初始化
  await mm.initializeModels();
  return await mm.isReady();
});

/// 模型总大小
final modelsSizeMBProvider = FutureProvider<int>((ref) async {
  final mm = ref.watch(modelManagerProvider);
  return await mm.getTotalSizeMB();
});

// ════════════════════════════════════════════════════════
// ASR 语音识别
// ════════════════════════════════════════════════════════

enum AsrStatus { idle, listening, processing, done, error }

class AsrState {
  final AsrStatus status;
  final String text;
  final String? partialText;
  final String? error;

  const AsrState({
    this.status = AsrStatus.idle,
    this.text = '',
    this.partialText,
    this.error,
  });

  AsrState copyWith({
    AsrStatus? status,
    String? text,
    String? partialText,
    String? error,
  }) {
    return AsrState(
      status: status ?? this.status,
      text: text ?? this.text,
      partialText: partialText,
      error: error,
    );
  }
}

final asrStateProvider = StateNotifierProvider<AsrStateNotifier, AsrState>((ref) {
  return AsrStateNotifier(ref);
});

class AsrStateNotifier extends StateNotifier<AsrState> {
  final Ref _ref;
  SherpaAsrRecognizer? _recognizer;

  AsrStateNotifier(this._ref) : super(const AsrState());

  SherpaOnnxService get _service => _ref.read(sherpaOnnxServiceProvider);

  /// 开始语音识别
  Future<void> startListening() async {
    final service = _service;
    if (!service.isInitialized) {
      await service.initialize();
    }

    final mm = _ref.read(modelManagerProvider);
    final modelPath = await mm.asrModelPath;
    final tokensPath = await mm.asrTokensPath;

    final config = SherpaAsrConfig(
      modelPath: modelPath,
      tokensPath: tokensPath,
      sampleRate: 16000,
    );

    _recognizer = service.startListening(config);
    _recognizer!.onPartialResult = (text, _) {
      state = state.copyWith(status: AsrStatus.listening, partialText: text);
    };
    _recognizer!.onResult = (text, isFinal) {
      if (isFinal) {
        state = state.copyWith(status: AsrStatus.done, text: text, partialText: null);
      }
    };

    _recognizer!.start();
    state = state.copyWith(status: AsrStatus.listening, text: '', partialText: '');
  }

  /// 停止识别
  void stopListening() {
    _recognizer?.stop();
    state = state.copyWith(status: AsrStatus.done);
  }

  /// 识别音频文件
  Future<String> recognizeFile(String audioPath) async {
    final mm = _ref.read(modelManagerProvider);
    final config = SherpaAsrConfig(
      modelPath: await mm.asrModelPath,
      tokensPath: await mm.asrTokensPath,
    );
    state = state.copyWith(status: AsrStatus.processing);
    try {
      final text = await _service.recognizeFile(audioPath, config);
      state = state.copyWith(status: AsrStatus.done, text: text);
      return text;
    } catch (e) {
      state = state.copyWith(status: AsrStatus.error, error: e.toString());
      return '';
    }
  }

  /// 重置
  void reset() {
    _recognizer?.dispose();
    _recognizer = null;
    state = const AsrState();
  }
}

// ════════════════════════════════════════════════════════
// TTS 语音合成
// ════════════════════════════════════════════════════════

enum TtsStatus { idle, synthesizing, playing, done, error }

class TtsState {
  final TtsStatus status;
  final String? audioPath;
  final String? error;
  final double progress;

  const TtsState({
    this.status = TtsStatus.idle,
    this.audioPath,
    this.error,
    this.progress = 0,
  });

  TtsState copyWith({
    TtsStatus? status,
    String? audioPath,
    String? error,
    double? progress,
  }) {
    return TtsState(
      status: status ?? this.status,
      audioPath: audioPath,
      error: error,
      progress: progress ?? this.progress,
    );
  }
}

final ttsStateProvider = StateNotifierProvider<TtsStateNotifier, TtsState>((ref) {
  return TtsStateNotifier(ref);
});

class TtsStateNotifier extends StateNotifier<TtsState> {
  final Ref _ref;
  final AudioPlayer _player = AudioPlayer();

  TtsStateNotifier(this._ref) : super(const TtsState()) {
    _player.playerStateStream.listen((ps) {
      if (ps.processingState == ProcessingState.completed) {
        state = state.copyWith(status: TtsStatus.done, progress: 1.0);
      } else if (ps.processingState == ProcessingState.buffering) {
        state = state.copyWith(status: TtsStatus.playing);
      }
    });
  }

  SherpaOnnxService get _service => _ref.read(sherpaOnnxServiceProvider);

  /// 合成文字并直接播放
  Future<void> speak(String text) async {
    final service = _service;
    if (!service.isInitialized) {
      await service.initialize();
    }

    final mm = _ref.read(modelManagerProvider);
    final config = SherpaTtsConfig(
      modelPath: await mm.ttsModelPath,
      tokensPath: await mm.ttsTokensPath,
      lexiconPath: await mm.ttsLexiconPath,
      sampleRate: 24000,
      speed: 1.0,
      pitch: 1.0,
      volume: 1.0,
    );

    state = state.copyWith(status: TtsStatus.synthesizing, progress: 0);

    try {
      final outputDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = p.join(outputDir.path, 'tts_$timestamp.wav');

      final resultPath = await service.synthesize(text, config, outputPath);

      if (resultPath != null) {
        state = state.copyWith(status: TtsStatus.synthesizing, progress: 0.8, audioPath: resultPath);
        await _player.setFilePath(resultPath);
        await _player.play();
        state = state.copyWith(status: TtsStatus.playing, progress: 1.0);
      } else {
        state = state.copyWith(status: TtsStatus.error, error: '合成失败');
      }
    } catch (e) {
      state = state.copyWith(status: TtsStatus.error, error: e.toString());
    }
  }

  /// 合成并返回文件路径（不播放）
  Future<String?> synthesize(String text) async {
    final service = _service;
    if (!service.isInitialized) await service.initialize();

    final mm = _ref.read(modelManagerProvider);
    final config = SherpaTtsConfig(
      modelPath: await mm.ttsModelPath,
      tokensPath: await mm.ttsTokensPath,
    );

    state = state.copyWith(status: TtsStatus.synthesizing);
    try {
      final outputDir = await getTemporaryDirectory();
      final outputPath = p.join(outputDir.path, 'tts_${DateTime.now().millisecondsSinceEpoch}.wav');
      return await service.synthesize(text, config, outputPath);
    } catch (e) {
      state = state.copyWith(status: TtsStatus.error, error: e.toString());
      return null;
    }
  }

  Future<void> stop() async => _player.stop();

  void reset() {
    _player.stop();
    state = const TtsState();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}

// ════════════════════════════════════════════════════════
// Sherpa-ONNX 服务单例
// ════════════════════════════════════════════════════════

final sherpaOnnxServiceProvider = Provider<SherpaOnnxService>((ref) {
  final service = SherpaOnnxService();
  return service;
});

// ════════════════════════════════════════════════════════
// 语音对话（ASR → AI → TTS 一键完成）
// ════════════════════════════════════════════════════════

enum VoiceDialogPhase { idle, listening, thinking, speaking, done }

class VoiceDialogState {
  final VoiceDialogPhase phase;
  final String recognizedText;
  final String aiResponseText;
  final String? error;

  const VoiceDialogState({
    this.phase = VoiceDialogPhase.idle,
    this.recognizedText = '',
    this.aiResponseText = '',
    this.error,
  });

  VoiceDialogState copyWith({
    VoiceDialogPhase? phase,
    String? recognizedText,
    String? aiResponseText,
    String? error,
  }) {
    return VoiceDialogState(
      phase: phase ?? this.phase,
      recognizedText: recognizedText ?? this.recognizedText,
      aiResponseText: aiResponseText ?? this.aiResponseText,
      error: error,
    );
  }
}

final voiceDialogStateProvider =
    StateNotifierProvider<VoiceDialogStateNotifier, VoiceDialogState>((ref) {
  return VoiceDialogStateNotifier(ref);
});

class VoiceDialogStateNotifier extends StateNotifier<VoiceDialogState> {
  final Ref _ref;
  StreamSubscription? _asrSub;
  StreamSubscription? _playerSub;

  VoiceDialogStateNotifier(this._ref) : super(const VoiceDialogState());

  AsrStateNotifier get _asr => _ref.read(asrStateProvider.notifier);
  TtsStateNotifier get _tts => _ref.read(ttsStateProvider.notifier);

  /// 一键语音对话
  ///
  /// 流程：用户说话 → ASR识别 → AI回复 → TTS播放
  Future<void> startDialog() async {
    state = const VoiceDialogState(phase: VoiceDialogPhase.listening);
    await _asr.startListening();

    // 监听 ASR 结果
    _asrSub?.cancel();
    _asrSub = _ref.listen(asrStateProvider, (prev, next) {
      if (next.status == AsrStatus.done && next.text.isNotEmpty) {
        _onRecognized(next.text);
      }
    }).read().void;
  }

  void _onRecognized(String text) {
    state = state.copyWith(phase: VoiceDialogPhase.thinking, recognizedText: text);

    // TODO: 调用 AI 对话服务（ChatService）
    // 实际集成时替换为真实 AI 调用：
    // final response = await ChatService().sendMessage(text);
    // _onAiResponse(response);
    _onAiResponse('（这是 AI 响应，集成 ChatService 后替换）');
  }

  void _onAiResponse(String response) {
    state = state.copyWith(phase: VoiceDialogPhase.speaking, aiResponseText: response);
    _tts.speak(response);

    // 监听播放完毕
    _playerSub?.cancel();
    _playerSub = _ref.listen(ttsStateProvider, (prev, next) {
      if (next.status == TtsStatus.done && state.phase == VoiceDialogPhase.speaking) {
        state = state.copyWith(phase: VoiceDialogPhase.done);
      }
    });
  }

  /// 停止所有
  void stop() {
    _asr.stopListening();
    _tts.stop();
    _asrSub?.cancel();
    _playerSub?.cancel();
    state = const VoiceDialogState();
  }

  @override
  void dispose() {
    _asrSub?.cancel();
    _playerSub?.cancel();
    super.dispose();
  }
}
