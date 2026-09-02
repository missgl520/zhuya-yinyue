// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 音乐搜索服务
// 支持：网易云音乐 + 酷狗 + Internet Archive
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:dio/dio.dart';

/// 音质档位
enum AudioQuality { unknown, standard, hq, sq, lossless }

/// 统一歌曲数据结构
class MusicTrack {
  final String id;          // 平台内唯一ID，前缀 "163_" / "kugou_" / "archive_"
  final String platform;    // '163' | 'kugou' | 'archive'
  final String title;       // 歌曲名
  final String artist;      // 歌手
  final String? album;      // 专辑
  final String? coverUrl;   // 封面图 URL
  final String audioUrl;    // 音频直链（可直接播放）
  final int? durationMs;    // 时长（毫秒）
  final int? fileSize;      // 文件大小（字节），用于估算音质
  final bool canPlay;       // 直链是否可用
  final AudioQuality quality; // 音质档位

  const MusicTrack({
    required this.id,
    required this.platform,
    required this.title,
    required this.artist,
    this.album,
    this.coverUrl,
    required this.audioUrl,
    this.durationMs,
    this.fileSize,
    this.canPlay = true,
    this.quality = AudioQuality.unknown,
  });

  String get duration {
    if (durationMs == null) return '--:--';
    final m = (durationMs! ~/ 60000).toString().padLeft(2, '0');
    final s = ((durationMs! % 60000) ~/ 1000).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get platformLabel {
    switch (platform) {
      case '163': return '网易云';
      case 'kugou': return '酷狗';
      case 'archive': return 'Archive';
      default: return platform;
    }
  }

  /// 根据文件大小估算音质
  AudioQuality get estimatedQuality {
    if (quality != AudioQuality.unknown) return quality;
    if (fileSize != null && durationMs != null && durationMs! > 0) {
      final kbps = (fileSize! * 8 / 1000 / (durationMs! / 1000)).round();
      if (kbps >= 900) return AudioQuality.lossless;
      if (kbps >= 300) return AudioQuality.sq;
      if (kbps >= 180) return AudioQuality.hq;
      return AudioQuality.standard;
    }
    return AudioQuality.unknown;
  }

  String get qualityLabel {
    switch (estimatedQuality) {
      case AudioQuality.lossless: return '🎵 无损';
      case AudioQuality.sq: return 'HQ';
      case AudioQuality.hq: return 'HQ';
      case AudioQuality.standard: return '标准';
      case AudioQuality.unknown: return '';
    }
  }
}

/// 搜索结果聚合
class MusicSearchResult {
  final List<MusicTrack> tracks;
  final String query;
  final int total;

  const MusicSearchResult({required this.tracks, required this.query, required this.total});
}

class MusicSearchService {
  static final MusicSearchService _instance = MusicSearchService._();
  factory MusicSearchService() => _instance;
  MusicSearchService._();

  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      'Referer': 'http://music.163.com/',
    },
  ));

  // ════════════════════════════════════════════════════════
  // 搜索入口（聚合三源）
  // ════════════════════════════════════════════════════════

  Future<MusicSearchResult> search(String query, {int limit = 20}) async {
    if (query.trim().isEmpty) {
      return const MusicSearchResult(tracks: [], query: '', total: 0);
    }

    final results = await Future.wait([
      _searchNetease(query, limit: limit),
      _searchKugou(query, limit: limit),
      _searchInternetArchive(query, limit: limit ~/ 2),
    ]);

    final all = [...results[0], ...results[1], ...results[2]];

    // 优先：SQ > HQ > 标准 > 无损(Archive) > unknown
    all.sort((a, b) {
      int score(MusicTrack t) {
        switch (t.estimatedQuality) {
          case AudioQuality.sq: return 4;
          case AudioQuality.hq: return 3;
          case AudioQuality.standard: return 2;
          case AudioQuality.lossless: return 1;
          case AudioQuality.unknown: return 0;
        }
      }
      return score(b) - score(a);
    });

    return MusicSearchResult(tracks: all, query: query, total: all.length);
  }

  // ════════════════════════════════════════════════════════
  // 网易云音乐
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ⚠️ 非官方 API，仅供学习参考
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Future<List<MusicTrack>> _searchNetease(String query, {int limit = 20}) async {
    try {
      final resp = await _dio.get(
        'http://music.163.com/api/search/get/web',
        queryParameters: {
          'csrf_token': '',
          's': query,
          'type': 1,
          'offset': 0,
          'total': true,
          'limit': limit,
        },
        options: Options(
          headers: {
            'Referer': 'http://music.163.com/',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          },
        ),
      );

      final songs = resp.data?['result']?['songs'] as List? ?? [];
      return songs.map((s) {
        final artists = (s['artists'] as List? ?? [])
            .map((a) => a['name']?.toString() ?? '')
            .where((n) => n.isNotEmpty)
            .join(' / ');
        final songId = s['id'] ?? 0;
        return MusicTrack(
          id: '163_$songId',
          platform: '163',
          title: s['name']?.toString() ?? '未知',
          artist: artists.isEmpty ? '未知歌手' : artists,
          album: s['album']?['name']?.toString(),
          coverUrl: s['album']?['picUrl']?.toString(),
          audioUrl: 'https://music.163.com/song/media/outer/url?id=$songId',
          durationMs: s['duration'] as int?,
          quality: AudioQuality.standard,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // ════════════════════════════════════════════════════════
  // 酷狗音乐（移动 API，完全免费）
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Future<List<MusicTrack>> _searchKugou(String query, {int limit = 20}) async {
    try {
      final resp = await _dio.get(
        'http://mobilecdn.kugou.com/api/v3/search/song',
        queryParameters: {
          'keyword': query,
          'page': 1,
          'pagesize': limit,
          'showtype': 1,
          'version': 8611,
          'platform': 'Android',
          'count': limit,
        },
        options: Options(headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 10)',
        }),
      );

      final infoList = resp.data?['data']?['info'] as List? ?? [];
      final tracks = <MusicTrack>[];

      for (final info in infoList) {
        final hash = info['hash']?.toString() ?? '';
        if (hash.isEmpty) continue;

        // 酷狗直链需要通过 hash 获取
        final audioUrl = await _getKugouPlayUrl(hash);
        if (audioUrl == null) continue;

        final durationS = info['duration'] as int? ?? 0;
        final fileSize = info['filesize'] as int?;

        // 估算音质：320k 约 11MB/3min, 192k 约 7MB/3min, 128k 约 4.8MB/3min
        AudioQuality quality = AudioQuality.standard;
        if (fileSize != null) {
          if (durationS > 0) {
            final kbps = fileSize * 8 ~/ durationS;
            if (kbps >= 300) quality = AudioQuality.sq;
            else if (kbps >= 180) quality = AudioQuality.hq;
          }
        }

        tracks.add(MusicTrack(
          id: 'kugou_$hash',
          platform: 'kugou',
          title: info['songname']?.toString() ?? '未知',
          artist: info['singername']?.toString() ?? '未知',
          album: info['album_name']?.toString(),
          coverUrl: info['img']?.toString(),
          audioUrl: audioUrl,
          durationMs: durationS * 1000,
          fileSize: fileSize,
          quality: quality,
        ));
      }
      return tracks;
    } catch (e) {
      return [];
    }
  }

  /// 获取酷狗直链（通过 hash）
  Future<String?> _getKugouPlayUrl(String hash) async {
    try {
      // 尝试多个端点
      for (final endpoint in [
        'http://www.kugou.com/yy/index.php?r=play/getdata&hash=$hash&mid=1',
        'https://wwwapi.kugou.com/yy/index.php?r=play/getdata&hash=$hash&mid=1',
      ]) {
        try {
          final resp = await Dio().get(
            endpoint,
            options: Options(headers: {
              'Referer': 'https://www.kugou.com/',
              'User-Agent': 'Mozilla/5.0',
            }),
          );
          final playUrl = resp.data?['data']?['play_url']?.toString();
          if (playUrl != null && playUrl.isNotEmpty && playUrl.startsWith('http')) {
            return playUrl;
          }
        } catch (_) {}
      }
    } catch (_) {}
    return null;
  }

  // ════════════════════════════════════════════════════════
  // Internet Archive（公有领域 / CC 音乐）
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 优先选 FLAC/WAV 无损，部分有 24bit 高解析度
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Future<List<MusicTrack>> _searchInternetArchive(String query, {int limit = 10}) async {
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));

      // 优先搜索古典、爵士等高质量录音
      final searchQuery = '$query music -format:mp3 OR format:flac OR format:wav';
      final resp = await dio.get(
        'https://archive.org/advancedsearch.php',
        queryParameters: {
          'q': searchQuery,
          'mediatype': 'audio',
          'output': 'json',
          'rows': limit,
          'fl': 'identifier,title,creator,downloadURL,avg_rating',
          'sort': 'avg_rating desc',
        },
      );

      final docs = resp.data?['response']?['docs'] as List? ?? [];
      final tracks = <MusicTrack>[];

      for (final doc in docs) {
        final urls = doc['downloadURL'];
        String? audioUrl;
        AudioQuality quality = AudioQuality.lossless;

        if (urls is List) {
          // 优先 FLAC > WAV > AIFF > 高码率 MP3
          audioUrl = _pickBestAudioUrl(urls.cast<String>());
        } else if (urls is String) {
          audioUrl = urls;
        }

        if (audioUrl != null) {
          // 判断是否为无损格式
          final ext = audioUrl.toLowerCase();
          if (ext.contains('.flac') || ext.contains('.wav') || ext.contains('.aiff')) {
            quality = AudioQuality.lossless;
          } else {
            quality = AudioQuality.standard;
          }

          tracks.add(MusicTrack(
            id: 'archive_${doc['identifier']}',
            platform: 'archive',
            title: doc['title']?.toString() ?? '未知',
            artist: doc['creator']?.toString() ?? 'Unknown',
            coverUrl: null,
            audioUrl: audioUrl,
            quality: quality,
            canPlay: true,
          ));
        }
      }
      return tracks;
    } catch (e) {
      return [];
    }
  }

  /// 从多个 URL 中选最佳音质
  String? _pickBestAudioUrl(List<String> urls) {
    // 优先级: flac > wav > aiff > 高码率mp3
    String? best;
    int bestScore = -1;

    for (final url in urls) {
      final u = url.toLowerCase();
      int score = 0;
      if (u.endsWith('.flac')) score = 100;
      else if (u.endsWith('.wav')) score = 90;
      else if (u.endsWith('.aiff') || u.endsWith('.aif')) score = 80;
      else if (u.endsWith('.mp3')) {
        // 尝试从文件名判断码率
        if (u.contains('v0') || u.contains('vbr')) score = 60;
        else if (u.contains('320')) score = 50;
        else if (u.contains('192')) score = 40;
        else score = 30;
      }

      if (score > bestScore) {
        bestScore = score;
        best = url;
      }
    }
    return best;
  }
}
