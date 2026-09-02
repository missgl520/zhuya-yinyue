// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 音乐播放器状态管理（Riverpod）
//
// 播放流程：下载 → Loudnorm响度标准化+动态压缩 → 播放
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'music_search_service.dart';
import '../services/audio_process_service.dart';

/// 当前播放曲目
final currentTrackProvider = StateProvider<MusicTrack?>((ref) => null);

/// 播放器处理配置
final audioProcessConfigProvider = StateProvider<AudioProcessConfig>((ref) {
  return const AudioProcessConfig();
});

/// 播放状态
final playerStateProvider = StateNotifierProvider<PlayerStateNotifier, PlayerState>((ref) {
  return PlayerStateNotifier(ref);
});

class PlayerState {
  final bool isPlaying;
  final bool isBuffering;
  final ProcessState processState;   // 处理/下载状态
  final double processProgress;       // 0.0~1.0
  final String? processMessage;       // 状态文字
  final Duration position;
  final Duration duration;
  final String? error;

  const PlayerState({
    this.isPlaying = false,
    this.isBuffering = false,
    this.processState = ProcessState.idle,
    this.processProgress = 0,
    this.processMessage,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.error,
  });

  bool get isProcessing => processState == ProcessState.processing || processState == ProcessState.downloading;

  PlayerState copyWith({
    bool? isPlaying,
    bool? isBuffering,
    ProcessState? processState,
    double? processProgress,
    String? processMessage,
    Duration? position,
    Duration? duration,
    String? error,
  }) {
    return PlayerState(
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      processState: processState ?? this.processState,
      processProgress: processProgress ?? this.processProgress,
      processMessage: processMessage,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      error: error,
    );
  }
}

class PlayerStateNotifier extends StateNotifier<PlayerState> {
  final Ref _ref;
  final AudioPlayer _player = AudioPlayer();
  final AudioProcessService _processor = AudioProcessService();

  PlayerStateNotifier(this._ref) : super(const PlayerState()) {
    _player.playerStateStream.listen((ps) {
      state = state.copyWith(
        isPlaying: ps.playing,
        isBuffering: ps.processingState == ProcessingState.buffering,
      );
    });
    _player.positionStream.listen((pos) {
      state = state.copyWith(position: pos);
    });
    _player.durationStream.listen((dur) {
      if (dur != null) state = state.copyWith(duration: dur);
    });
  }

  AudioPlayer get player => _player;

  /// 播放：下载直链 → FFmpeg处理 → just_audio播放
  Future<void> play(MusicTrack track) async {
    _ref.read(currentTrackProvider.notifier).state = track;
    state = state.copyWith(
      error: null,
      isBuffering: false,
      processState: ProcessState.downloading,
      processProgress: 0,
      processMessage: '准备下载…',
    );

    try {
      // 获取处理配置
      final config = _ref.read(audioProcessConfigProvider);

      // 下载 + FFmpeg处理（响度标准化 + 动态压缩）
      final processedPath = await _processor.processAudio(
        url: track.audioUrl,
        trackId: track.id,
        config: config,
        onProgress: (ps, progress, message) {
          state = state.copyWith(
            processState: ps,
            processProgress: progress,
            processMessage: message,
          );
        },
      );

      if (processedPath == null) {
        state = state.copyWith(
          error: '处理失败，无法播放',
          processState: ProcessState.error,
        );
        return;
      }

      // 用处理后的本地文件播放
      state = state.copyWith(
        processState: ProcessState.done,
        processMessage: '播放中',
        isBuffering: true,
      );

      await _player.setFilePath(processedPath);
      await _player.play();
    } catch (e) {
      state = state.copyWith(
        error: '播放失败: ${e.toString()}',
        processState: ProcessState.error,
        isBuffering: false,
      );
    }
  }

  Future<void> pause() async => _player.pause();
  Future<void> resume() async => _player.play();
  Future<void> stop() async => _player.stop();
  Future<void> seek(Duration pos) async => _player.seek(pos);

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}

/// 搜索关键词
final searchQueryProvider = StateProvider<String>((ref) => '');

/// 搜索结果
final searchResultProvider = FutureProvider.family<MusicSearchResult, String>((ref, query) async {
  if (query.trim().isEmpty) {
    return const MusicSearchResult(tracks: [], query: '', total: 0);
  }
  return MusicSearchService().search(query, limit: 30);
});
