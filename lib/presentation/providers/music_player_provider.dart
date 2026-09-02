// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 音乐播放器状态管理（Riverpod）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'music_search_service.dart';

/// 当前播放曲目
final currentTrackProvider = StateProvider<MusicTrack?>((ref) => null);

/// 播放状态
final playerStateProvider = StateNotifierProvider<PlayerStateNotifier, PlayerState>((ref) {
  return PlayerStateNotifier(ref);
});

class PlayerState {
  final bool isPlaying;
  final bool isBuffering;
  final Duration position;
  final Duration duration;
  final String? error;
  final bool isDownloading;
  final double downloadProgress;

  const PlayerState({
    this.isPlaying = false,
    this.isBuffering = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.error,
    this.isDownloading = false,
    this.downloadProgress = 0,
  });

  PlayerState copyWith({
    bool? isPlaying,
    bool? isBuffering,
    Duration? position,
    Duration? duration,
    String? error,
    bool? isDownloading,
    double? downloadProgress,
  }) {
    return PlayerState(
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      error: error,
      isDownloading: isDownloading ?? this.isDownloading,
      downloadProgress: downloadProgress ?? this.downloadProgress,
    );
  }
}

class PlayerStateNotifier extends StateNotifier<PlayerState> {
  final Ref _ref;
  final AudioPlayer _player = AudioPlayer();
  final Dio _dio = Dio();

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

  Future<void> play(MusicTrack track) async {
    _ref.read(currentTrackProvider.notifier).state = track;
    state = state.copyWith(error: null, isBuffering: true);
    try {
      await _player.setUrl(track.audioUrl);
      await _player.play();
    } catch (e) {
      state = state.copyWith(error: '播放失败: ${e.toString()}', isBuffering: false);
    }
  }

  Future<void> pause() async => _player.pause();
  Future<void> resume() async => _player.play();
  Future<void> stop() async => _player.stop();
  Future<void> seek(Duration pos) async => _player.seek(pos);

  Future<String?> download(MusicTrack track) async {
    state = state.copyWith(isDownloading: true, downloadProgress: 0);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final fileName = '${track.title}_${track.artist}.mp3'
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final filePath = '${dir.path}/music/$fileName';
      await Directory('${dir.path}/music').create(recursive: true);

      await _dio.download(
        track.audioUrl,
        filePath,
        options: Options(headers: {
          'Referer': 'http://music.163.com/',
          'User-Agent': 'Mozilla/5.0',
        }),
        onReceiveProgress: (received, total) {
          if (total > 0) {
            state = state.copyWith(downloadProgress: received / total);
          }
        },
      );

      state = state.copyWith(isDownloading: false, downloadProgress: 1.0);
      return filePath;
    } catch (e) {
      state = state.copyWith(isDownloading: false, error: '下载失败');
      return null;
    }
  }

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
