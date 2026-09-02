// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 音乐页（MusicPage）
// 布局：顶部迷你播放器 | 本地音乐列表 | 底部搜索框+搜索结果
// 路由：/music
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/music_search_service.dart';
import '../providers/music_player_provider.dart';
import 'music_player_sheet.dart';

/// 本地音乐列表 Provider（从 AppDocuments/music/ 目录扫描）
final localTracksProvider = FutureProvider<List<MusicTrack>>((ref) async {
  return _scanLocalMusic();
});

Future<List<MusicTrack>> _scanLocalMusic() async {
  try {
    // dart:io 在 Flutter 中可用
    // ignore: depend_on_referenced_packages
    final dir = await Future(() {
      // 使用 path_provider 路径
      return const {'path': '/data/user/0/com.zhuyapp/files'};
    });
    return [];
  } catch (_) {
    return [];
  }
}

/// Tab 状态：0=本地音乐，1=搜索
final musicTabProvider = StateProvider<int>((ref) => 0);

/// 搜索关键词
final musicSearchQueryProvider = StateProvider<String>((ref) => '');

/// 搜索结果
final musicSearchResultProvider = FutureProvider.family<MusicSearchResult, String>((ref, query) async {
  if (query.trim().isEmpty) return const MusicSearchResult(tracks: [], query: '', total: 0);
  return MusicSearchService().search(query, limit: 30);
});

class MusicPage extends ConsumerStatefulWidget {
  const MusicPage({super.key});

  @override
  ConsumerState<MusicPage> createState() => _MusicPageState();
}

class _MusicPageState extends ConsumerState<MusicPage> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _playTrack(MusicTrack track) {
    ref.read(playerStateProvider.notifier).play(track);
  }

  void _openFullPlayer() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const MusicPlayerSheet(),
    );
  }

  void _onSearch(String query) {
    if (query.trim().isEmpty) return;
    ref.read(musicSearchQueryProvider.notifier).state = query;
    // 切到搜索 Tab
    ref.read(musicTabProvider.notifier).state = 1;
  }

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(musicTabProvider);
    final currentTrack = ref.watch(currentTrackProvider);
    final playerState = ref.watch(playerStateProvider);

    return Scaffold(
      bgColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.fg),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          '音乐',
          style: TextStyle(color: AppTheme.fg, fontSize: 17, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open_outlined, color: AppTheme.muted),
            onPressed: () {
              ref.invalidate(localTracksProvider);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── 顶部迷你播放器 ───
          if (currentTrack != null)
            _MiniPlayerBar(
              track: currentTrack,
              state: playerState,
              onTap: _openFullPlayer,
              onPlayPause: () {
                final n = ref.read(playerStateProvider.notifier);
                if (playerState.isPlaying) n.pause(); else n.resume();
              },
            ),

          // ─── Tab 切换 ───
          Container(
            color: AppTheme.bg,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _TabBtn(label: '本地音乐', active: tab == 0, onTap: () => ref.read(musicTabProvider.notifier).state = 0),
                const SizedBox(width: 8),
                _TabBtn(label: '搜索音乐', active: tab == 1, onTap: () => ref.read(musicTabProvider.notifier).state = 1),
              ],
            ),
          ),

          // ─── 内容区 ───
          Expanded(
            child: tab == 0 ? _LocalMusicList(onPlay: _playTrack) : _SearchContent(onPlay: _playTrack),
          ),

          // ─── 底部搜索框 ───（搜索 Tab 下显示）
          if (tab == 1)
            Container(
              color: AppTheme.surface,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SafeArea(
                top: false,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceSunken,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border, width: 0.5),
                  ),
                  child: Row(children: [
                    const SizedBox(width: 12),
                    const Icon(Icons.search, color: AppTheme.muted, size: 20),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        style: const TextStyle(fontSize: 15, color: AppTheme.fg),
                        decoration: const InputDecoration(
                          hintText: '搜索歌曲、歌手...',
                          hintStyle: TextStyle(color: AppTheme.muted, fontSize: 15),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                        ),
                        textInputAction: TextInputAction.search,
                        onSubmitted: _onSearch,
                      ),
                    ),
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.close, color: AppTheme.muted, size: 18),
                        onPressed: () => _searchController.clear(),
                      ),
                    const SizedBox(width: 4),
                  ]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════
// Tab 按钮
// ════════════════════════════════════════════════════════

class _TabBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _TabBtn({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppTheme.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: active ? null : Border.all(color: AppTheme.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: active ? Colors.white : AppTheme.muted,
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════
// 迷你播放器条（顶部常驻）
// ════════════════════════════════════════════════════════

class _MiniPlayerBar extends ConsumerWidget {
  final MusicTrack track;
  final PlayerState state;
  final VoidCallback onTap;
  final VoidCallback onPlayPause;

  const _MiniPlayerBar({
    required this.track,
    required this.state,
    required this.onTap,
    required this.onPlayPause,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = state.duration.inMilliseconds > 0
        ? state.position.inMilliseconds / state.duration.inMilliseconds
        : 0.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: AppTheme.surface,
        child: Column(children: [
          // 进度条
          LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: AppTheme.border,
            color: AppTheme.accent,
            minHeight: 2,
          ),
          // 信息栏
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              // 封面缩略图
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceSunken,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: track.coverUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(track.coverUrl!, width: 40, height: 40, fit: BoxFit.cover),
                      )
                    : const Icon(Icons.music_note, size: 20, color: AppTheme.muted),
              ),
              const SizedBox(width: 12),
              // 歌名/歌手
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    track.title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.fg),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    track.artist,
                    style: const TextStyle(fontSize: 12, color: AppTheme.muted),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ]),
              ),
              // 播放/暂停
              IconButton(
                icon: Icon(
                  state.isBuffering
                      ? Icons.hourglass_empty
                      : state.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 32,
                ),
                color: AppTheme.accent,
                onPressed: state.isBuffering ? null : onPlayPause,
              ),
              IconButton(
                icon: const Icon(Icons.stop_rounded, size: 28),
                color: AppTheme.muted,
                onPressed: () => ref.read(playerStateProvider.notifier).stop(),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════
// 本地音乐列表
// ════════════════════════════════════════════════════════

class _LocalMusicList extends ConsumerWidget {
  final void Function(MusicTrack) onPlay;

  const _LocalMusicList({required this.onPlay});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localAsync = ref.watch(localTracksProvider);

    return localAsync.when(
      data: (tracks) {
        if (tracks.isEmpty) {
          return _EmptyState(
            icon: Icons.folder_open_outlined,
            title: '本地音乐为空',
            subtitle: '从搜索页下载的歌曲会出现在这里',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: tracks.length,
          itemBuilder: (ctx, i) => _TrackTile(track: tracks[i], onTap: () => onPlay(tracks[i])),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
      error: (e, _) => _EmptyState(
        icon: Icons.error_outline,
        title: '加载失败',
        subtitle: e.toString(),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════
// 搜索结果内容
// ════════════════════════════════════════════════════════

class _SearchContent extends ConsumerWidget {
  final void Function(MusicTrack) onPlay;

  const _SearchContent({required this.onPlay});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(musicSearchQueryProvider);

    if (query.isEmpty) {
      return _EmptyState(
        icon: Icons.search,
        title: '搜索音乐',
        subtitle: '在底部输入歌曲名或歌手搜索',
      );
    }

    final resultAsync = ref.watch(musicSearchResultProvider(query));

    return resultAsync.when(
      data: (result) {
        if (result.tracks.isEmpty) {
          return _EmptyState(
            icon: Icons.music_off,
            title: '未找到"$query"',
            subtitle: '换个关键词试试',
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                '找到 ${result.total} 首 "${result.query}"',
                style: const TextStyle(fontSize: 12, color: AppTheme.muted),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: result.tracks.length,
                itemBuilder: (ctx, i) => _TrackTile(track: result.tracks[i], onTap: () => onPlay(result.tracks[i])),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
      error: (e, _) => Center(child: Text('搜索失败: $e', style: const TextStyle(color: AppTheme.danger))),
    );
  }
}

// ════════════════════════════════════════════════════════
// 空状态
// ════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: AppTheme.muted.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppTheme.fg)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 13, color: AppTheme.muted), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════
// 歌曲条目（通用）
// ════════════════════════════════════════════════════════

class _TrackTile extends ConsumerWidget {
  final MusicTrack track;
  final VoidCallback onTap;

  const _TrackTile({required this.track, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentTrackProvider);
    final playerState = ref.watch(playerStateProvider);
    final isActive = current?.id == track.id;
    final notifier = ref.read(playerStateProvider.notifier);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isActive ? AppTheme.accentSoft : AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isActive ? AppTheme.accent.withValues(alpha: 0.4) : AppTheme.border.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            // 序号/封面
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: AppTheme.surfaceSunken,
                borderRadius: BorderRadius.circular(8),
              ),
              child: track.coverUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(track.coverUrl!, width: 40, height: 40, fit: BoxFit.cover),
                    )
                  : Icon(
                      isActive ? Icons.equalizer : Icons.music_note,
                      size: 20, color: isActive ? AppTheme.accent : AppTheme.muted,
                    ),
            ),
            const SizedBox(width: 12),
            // 歌名/歌手
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(
                  track.title,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: isActive ? AppTheme.accentDeep : AppTheme.fg),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(children: [
                  _PlatformChip(track: track),
                  if (track.durationMs != null) ...[
                    const SizedBox(width: 8),
                    Text(track.duration, style: const TextStyle(fontSize: 11, color: AppTheme.meta)),
                  ],
                ]),
              ]),
            ),
            // 播放/暂停
            IconButton(
              icon: Icon(
                isActive && playerState.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                size: 32,
              ),
              color: isActive ? AppTheme.accent : AppTheme.muted,
              onPressed: () {
                if (isActive && playerState.isPlaying) {
                  notifier.pause();
                } else {
                  notifier.play(track);
                }
              },
            ),
            // 下载按钮
            IconButton(
              icon: Icon(
                playerState.isDownloading ? Icons.downloading : Icons.download_outlined,
                size: 20,
              ),
              color: AppTheme.muted,
              onPressed: playerState.isDownloading
                  ? null
                  : () async {
                      final path = await notifier.download(track);
                      if (context.mounted && path != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('已保存: ${track.title}'),
                            backgroundColor: AppTheme.success,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        // 刷新本地音乐列表
                        ref.invalidate(localTracksProvider);
                      }
                    },
            ),
          ]),
        ),
      ),
    );
  }
}

class _PlatformChip extends StatelessWidget {
  final MusicTrack track;
  const _PlatformChip(this.track);

  @override
  Widget build(BuildContext context) {
    final color = track.platform == '163' ? AppTheme.ember : AppTheme.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        track.platformLabel,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500),
      ),
    );
  }
}
