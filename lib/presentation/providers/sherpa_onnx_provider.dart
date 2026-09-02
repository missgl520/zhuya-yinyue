// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Sherpa-ONNX 语音服务 Provider
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../core/services/sherpa_onnx_service.dart';

/// Sherpa-ONNX 服务单例
final sherpaOnnxServiceProvider = Provider<SherpaOnnxService>((ref) {
  return SherpaOnnxService();
});

/// 模型初始化状态
final modelsReadyProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(sherpaOnnxServiceProvider);
  await service.initialize();
  return service.isInitialized;
});

/// 模型大小
final modelsSizeProvider = FutureProvider<int>((ref) async {
  final service = ref.watch(sherpaOnnxServiceProvider);
  return await service.getModelsSizeMB();
});

/// ASR 状态
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

  /// 开始语音识别
  Future<void> startListening() async {
    final service = _ref.read(sherpaOnnxServiceProvider);
    if (!service.isInitialized) {
      await service.initialize();
    }

    // TODO: 替换为实际模型路径
    const config = SherpaAsrConfig(
      modelPath: '', // assets/models/asr/model.onnx
      tokensPath: '', // assets/models/asr/tokens.txt
    );

    _recognizer = service.startListening(config);
    _recognizer!.onPartialResult = (text, _) {
      state = state.copyWith(status: AsrStatus.listening, partialText: text);
    };
    _recognizer!.onResult = (text, isFinal) {
      if (isFinal) {
        state = state.copyWith(status: AsrStatus.done, text: text);
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

  /// 重置
  void reset() {
    _recognizer?.dispose();
    _recognizer = null;
    state = const AsrState();
  }
}

/// TTS 状态
enum TtsStatus { idle, synthesizing, done, error }

class TtsState {
  final TtsStatus status;
  final String? audioPath;
  final String? error;
  final double progress;  // 0.0~1.0

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

  TtsStateNotifier(this._ref) : super(const TtsState());

  AudioPlayer get player => _player;

  /// 合成文字并直接播放
  Future<void> speak(String text) async {
    final service = _ref.read(sherpaOnnxServiceProvider);
    if (!service.isInitialized) {
      await service.initialize();
    }

    state = state.copyWith(status: TtsStatus.synthesizing, progress: 0);

    try {
      // TODO: 替换为实际模型路径
      const config = SherpaTtsConfig(
        modelPath: '', // assets/models/tts/model.onnx
        tokensPath: '', // assets/models/tts/tokens.txt
        sampleRate: 24000,
        speed: 1.0,
      );

      final outputDir = await getTemporaryDirectory();
      final outputPath = p.join(outputDir.path, 'tts_output.wav');

      final resultPath = await service.synthesize(text, config, outputPath);

      if (resultPath != null) {
        state = state.copyWith(status: TtsStatus.done, audioPath: resultPath, progress: 1.0);
        await _player.setFilePath(resultPath);
        await _player.play();
      } else {
        state = state.copyWith(status: TtsStatus.error, error: '合成失败');
      }
    } catch (e) {
      state = state.copyWith(status: TtsStatus.error, error: e.toString());
    }
  }

  /// 合成并返回音频文件路径（不播放）
  Future<String?> synthesize(String text) async {
    final service = _ref.read(sherpaOnnxServiceProvider);
    if (!service.isInitialized) {
      await service.initialize();
    }

    state = state.copyWith(status: TtsStatus.synthesizing);

    try {
      const config = SherpaTtsConfig(
        modelPath: '',
        tokensPath: '',
        sampleRate: 24000,
      );

      final outputDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = p.join(outputDir.path, 'tts_$timestamp.wav');

      return await service.synthesize(text, config, outputPath);
    } catch (e) {
      state = state.copyWith(status: TtsStatus.error, error: e.toString());
      return null;
    }
  }

  /// 停止播放
  Future<void> stop() async => _player.stop();

  /// 重置
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

/// ASR + TTS 组合模式（宠物语音对话用）
class VoiceDialogState {
  final bool isListening;    // 正在录音
  final bool isThinking;     // AI 处理中
  final bool isSpeaking;     // TTS 播放中
  final String recognizedText;
  final String aiResponseText;
  final String? error;

  const VoiceDialogState({
    this.isListening = false,
    this.isThinking = false,
    this.isSpeaking = false,
    this.recognizedText = '',
    this.aiResponseText = '',
    this.error,
  });

  VoiceDialogState copyWith({
    bool? isListening,
    bool? isThinking,
    bool? isSpeaking,
    String? recognizedText,
    String? aiResponseText,
    String? error,
  }) {
    return VoiceDialogState(
      isListening: isListening ?? this.isListening,
      isThinking: isThinking ?? this.isThinking,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      recognizedText: recognizedText ?? this.recognizedText,
      aiResponseText: aiResponseText ?? this.aiResponseText,
      error: error,
    );
  }
}

final voiceDialogStateProvider = StateNotifierProvider<VoiceDialogStateNotifier, VoiceDialogState>((ref) {
  return VoiceDialogStateNotifier(ref);
});

class VoiceDialogStateNotifier extends StateNotifier<VoiceDialogState> {
  final Ref _ref;
  final AsrStateNotifier _asr;
  final TtsStateNotifier _tts;

  VoiceDialogStateNotifier(this._ref)
      : _asr = ref.read(asrStateProvider.notifier),
        _tts = ref.read(ttsStateProvider.notifier),
        super(const VoiceDialogState());

  /// 一键语音对话：录音 → ASR → AI → TTS → 播放
  Future<void> startVoiceDialog() async {
    // 1. 开始录音识别
    state = state.copyWith(isListening: true, recognizedText: '', aiResponseText: '', error: null);
    await _asr.startListening();

    // 2. 监听 ASR 结果
    _ref.listen(asrStateProvider, (prev, next) {
      if (next.status == AsrStatus.done && next.text.isNotEmpty) {
        _onRecognized(next.text);
      }
    });
  }

  void _onRecognized(String text) {
    state = state.copyWith(isListening: false, isThinking: true, recognizedText: text);

    // 3. TODO: 调用 AI 对话（ChatService）
    // ChatService().sendMessage(text, onChunk: (chunk) { ... })
    // onDone: (response) => _onAiResponse(response)
  }

  void _onAiResponse(String response) {
    state = state.copyWith(isThinking: false, aiResponseText: response);

    // 4. TTS 合成并播放
    _tts.speak(response);
    state = state.copyWith(isSpeaking: true);

    // 5. TTS 播放完毕
    _tts.player.playerStateStream.listen((ps) {
      if (ps.processingState == ProcessingState.completed) {
        state = state.copyWith(isSpeaking: false);
      }
    });
  }

  void stopAll() {
    _asr.stopListening();
    _tts.stop();
    state = const VoiceDialogState();
  }
}
