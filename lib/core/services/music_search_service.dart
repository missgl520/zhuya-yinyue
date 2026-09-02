// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 音乐搜索服务
// 支持：网易云音乐（非官方API）+ Internet Archive
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:dio/dio.dart';

/// 统一歌曲数据结构
class MusicTrack {
  final String id;          // 平台内唯一ID
  final String platform;    // '163' | 'archive'
  final String title;       // 歌曲名
  final String artist;      // 歌手
  final String? album;      // 专辑
  final String? coverUrl;   // 封面图 URL
  final String audioUrl;    // 音频直链（可直接播放）
  final int? durationMs;    // 时长（毫秒）
  final bool canPlay;       // 直链是否可用

  const MusicTrack({
    required this.id,
    required this.platform,
    required this.title,
    required this.artist,
    this.album,
    this.coverUrl,
    required this.audioUrl,
    this.durationMs,
    this.canPlay = true,
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
      case 'archive': return 'Archive.org';
      default: return platform;
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
      'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15',
      'Referer': 'http://music.163.com/',
    },
  ));

  // ════════════════════════════════════════════════════════
  // 搜索入口（聚合多源）
  // ════════════════════════════════════════════════════════

  Future<MusicSearchResult> search(String query, {int limit = 20}) async {
    if (query.trim().isEmpty) {
      return const MusicSearchResult(tracks: [], query: '', total: 0);
    }

    // 并发搜索两个源
    final results = await Future.wait([
      _searchNetease(query, limit: limit),
      _searchInternetArchive(query, limit: limit ~/ 2),
    ]);

    final all = [...results[0], ...results[1]];
    // 网易云优先
    all.sort((a, b) {
      if (a.platform == '163' && b.platform != '163') return -1;
      if (a.platform != '163' && b.platform == '163') return 1;
      return 0;
    });

    return MusicSearchResult(tracks: all, query: query, total: all.length);
  }

  // ════════════════════════════════════════════════════════
  // 网易云音乐搜索
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ⚠️ 非官方 API，仅供学习参考
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Future<List<MusicTrack>> _searchNetease(String query, {int limit = 20}) async {
    try {
      final resp = await _dio.get(
        'http://music.163.com/api/search/get/web',
        queryParameters: {
          'csrf_token': '',
          'hlpretag': '<span class="s-fc7">',
          'hlposttag': '</span>',
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
        return MusicTrack(
          id: '163_${s['id']}',
          platform: '163',
          title: s['name']?.toString() ?? '未知',
          artist: artists.isEmpty ? '未知歌手' : artists,
          album: s['album']?['name']?.toString(),
          coverUrl: s['album']?['picUrl']?.toString(),
          audioUrl: 'https://music.163.com/song/media/outer/url?id=${s['id']}',
          durationMs: s['duration'] as int?,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // ════════════════════════════════════════════════════════
  // Internet Archive 搜索（公有领域 / CC 音乐）
  // 完全免费，无版权问题
  // ════════════════════════════════════════════════════════

  Future<List<MusicTrack>> _searchInternetArchive(String query, {int limit = 10}) async {
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
      ));
      final resp = await dio.get(
        'https://archive.org/advancedsearch.php',
        queryParameters: {
          'q': '$query music',
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
        String? mp3Url;

        if (urls is List) {
          mp3Url = urls.firstWhere(
            (u) => u.toString().endsWith('.mp3'),
            orElse: () => null,
          )?.toString();
        } else if (urls is String && urls.endsWith('.mp3')) {
          mp3Url = urls;
        }

        if (mp3Url != null) {
          tracks.add(MusicTrack(
            id: 'archive_${doc['identifier']}',
            platform: 'archive',
            title: doc['title']?.toString() ?? '未知',
            artist: doc['creator']?.toString() ?? 'Unknown',
            coverUrl: null,
            audioUrl: mp3Url,
            canPlay: true,
          ));
        }
      }
      return tracks;
    } catch (e) {
      return [];
    }
  }

  // ════════════════════════════════════════════════════════
  // 获取单曲详情（含高清封面）
  // ════════════════════════════════════════════════════════

  Future<String?> getNeteaseCoverUrl(int songId) async {
    try {
      final resp = await _dio.get(
        'http://music.163.com/api/song/detail/?ids=[$songId]',
        options: Options(headers: {
          'Referer': 'http://music.163.com/',
          'User-Agent': 'Mozilla/5.0',
        }),
      );
      final songs = resp.data?['songs'] as List? ?? [];
      if (songs.isNotEmpty) {
        return songs[0]['album']?['picUrl']?.toString();
      }
    } catch (_) {}
    return null;
  }
}
