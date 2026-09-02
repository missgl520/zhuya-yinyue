// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 音乐搜索页（MusicSearchPage）
// 路由：/music/search
// 功能：搜索 + 列表 + 播放 + 下载
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/music_search_service.dart';
import '../providers/music_player_provider.dart';
import 'music_player_sheet.dart';

class MusicSearchPage extends ConsumerStatefulWidget {
  const MusicSearchPage({super.key});

  @override
  ConsumerState<MusicSearchPage> createState() => _MusicSearchPageState();
}

class _MusicSearchPageState extends ConsumerState<MusicSearchPage> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _search(String query) {
    if (query.trim().isEmpty) return;
    setState(() => _lastQuery = query);
    ref.read(searchResultProvider(query).future);
  }

  void _playTrack(MusicTrack track) {
    ref.read(playerStateProvider.notifier).play(track);
    _showPlayerSheet();
  }

  void _showPlayerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const MusicPlayerSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resultAsync = _lastQuery.isEmpty
        ? null
        : ref.watch(searchResultProvider(_lastQuery));

    return Scaffold(
      bgColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.fg),
          onPressed: () => context.pop(),
        ),
        title: const Text('音乐搜索', style: TextStyle(color: AppTheme.fg, fontSize: 17, fontWeight: FontWeight.w600)),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _SearchBar(controller: _controller, focusNode: _focusNode, onSearch: _search),
          ),
        ),
      ),
      body: _lastQuery.isEmpty
          ? _buildEmptyState()
          : resultAsync == null
              ? _buildEmptyState()
              : resultAsync.when(
                  data: (result) => _buildResultList(result),
                  loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
                  error: (e, _) => Center(child: Text('搜索失败: $e', style: const TextStyle(color: AppTheme.danger))),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_rounded, size: 64, color: AppTheme.muted.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text('搜索歌曲、歌手或专辑', style: TextStyle(color: AppTheme.muted, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildResultList(MusicSearchResult result) {
    if (result.tracks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_off, size: 64, color: AppTheme.muted.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text('未找到"$_lastQuery"相关音乐', style: TextStyle(color: AppTheme.muted, fontSize: 15)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: result.tracks.length,
      itemBuilder: (ctx, i) => _TrackTile(track: result.tracks[i], onTap: () => _playTrack(result.tracks[i])),
    );
  }
}

// ════════════════════════════════════════════════════════
// 搜索框
// ════════════════════════════════════════════════════════

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final void Function(String) onSearch;

  const _SearchBar({required this.controller, required this.focusNode, required this.onSearch});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border, width: 1),
      ),
      child: Row(children: [
        const SizedBox(width: 12),
        Icon(Icons.search, color: AppTheme.muted, size: 20),
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            style: const TextStyle(fontSize: 15, color: AppTheme.fg),
            decoration: const InputDecoration(
              hintText: '搜索音乐...',
              hintStyle: TextStyle(color: AppTheme.muted, fontSize: 15),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: onSearch,
          ),
        ),
        if (controller.text.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.close, color: AppTheme.muted, size: 18),
            onPressed: () { controller.clear(); },
          ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════
// 歌曲条目
// ════════════════════════════════════════════════════════

class _TrackTile extends ConsumerWidget {
  final MusicTrack track;
  final VoidCallback onTap;

  const _TrackTile({required this.track, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentTrackProvider);
    final isActive = current?.id == track.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isActive ? AppTheme.accentSoft : AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? AppTheme.accent : AppTheme.border,
          width: isActive ? 1.5 : 0.5,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            // 封面
            _CoverImage(track: track, isActive: isActive),
            const SizedBox(width: 12),
            // 歌名/歌手
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  track.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isActive ? AppTheme.accentDeep : AppTheme.fg,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  track.artist,
                  style: const TextStyle(fontSize: 12, color: AppTheme.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
            // 播放/下载按钮
            _TrackActions(track: track, isActive: isActive),
          ]),
        ),
      ),
    );
  }
}

class _CoverImage extends StatelessWidget {
  final MusicTrack track;
  final bool isActive;

  const _CoverImage({required this.track, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: AppTheme.surfaceSunken,
        borderRadius: BorderRadius.circular(8),
      ),
      child: track.coverUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(track.coverUrl!, width: 52, height: 52, fit: BoxFit.cover),
            )
          : Icon(
              isActive ? Icons.equalizer : Icons.music_note,
              color: isActive ? AppTheme.accent : AppTheme.muted,
              size: 24,
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        track.platformLabel,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _TrackActions extends ConsumerWidget {
  final MusicTrack track;
  final bool isActive;

  const _TrackActions({required this.track, required this.isActive});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerStateProvider);
    final notifier = ref.read(playerStateProvider.notifier);

    return Row(mainAxisSize: MainAxisSize.min, children: [
      // 播放按钮
      IconButton(
        icon: Icon(
          isActive && playerState.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
          color: isActive ? AppTheme.accent : AppTheme.muted,
          size: 36,
        ),
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
          color: AppTheme.muted,
          size: 22,
        ),
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
                }
              },
      ),
    ]);
  }
}
