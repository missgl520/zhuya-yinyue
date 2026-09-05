// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 音乐狗页面（Music Dog Page）
//
// 3D 音乐狗 + 音乐播放 + 图库 合并页
//
// 布局：
//   ┌─────────────────────────────────┐
//   │                                 │
//   │         3D 音乐狗                │  ← AvatarViewer（WebView+Three.js）
//   │         （可旋转缩放）            │
//   ├─────────────────────────────────┤
//   │  ▶ 正在播放：歌名 - 歌手          │  ← 迷你播放器（无歌时隐藏）
//   ├─────────────────────────────────┤
//   │  [图库]    [播放]    [搜索]       │  ← 功能入口
//   └─────────────────────────────────┘
//
// 路由：/music-dog
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/avatar_viewer.dart';
import '../../presentation/providers/music_player_provider.dart';
import '../music/music_player_sheet.dart';
import '../music/music_search_page.dart';

class MusicDogPage extends ConsumerStatefulWidget {
  const MusicDogPage({super.key});

  @override
  ConsumerState<MusicDogPage> createState() => _MusicDogPageState();
}

class _MusicDogPageState extends ConsumerState<MusicDogPage> {
  /// 功能按钮列表
  final _functions = const [
    _FuncItem(icon: Icons.photo_library_outlined, label: '图库', route: '/pet/library'),
    _FuncItem(icon: Icons.play_circle_outline, label: '播放', route: null),  // 打开播放列表
    _FuncItem(icon: Icons.search, label: '搜索', route: null),               // 打开搜索页
  ];

  void _onFuncTap(_FuncItem func) {
    if (func.route != null) {
      context.push(func.route!);
    } else {
      // 播放/搜索：打开底部 sheet
      if (func.label == '播放') {
        _showMusicPlayer(context);
      } else if (func.label == '搜索') {
        _showMusicSearch(context);
      }
    }
  }

  void _showMusicPlayer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const MusicPlayerSheet(),
    );
  }

  void _showMusicSearch(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => const MusicSearchPage(scrollController: null),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentTrack = ref.watch(currentTrackProvider);
    final playerState = ref.watch(playerStateProvider);
    final isPlaying = playerState.isPlaying;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : const Color(0xFFEDF7F0),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : AppTheme.softText),
          onPressed: () => context.pop(),
        ),
        title: Text(
          '音乐狗',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppTheme.softText,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.tune, color: isDark ? Colors.white70 : AppTheme.subText),
            tooltip: '换装',
            onPressed: () => context.push('/avatar/customize'),
          ),
        ],
      ),
      body: Column(
        children: [
          // ━━━ 3D 音乐狗（占上半部分） ━━━
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                // 3D 角色（WebView+Three.js）
                const Positioned.fill(child: AvatarViewer()),

                // 操作提示
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 8,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '拖动旋转 · 双指缩放',
                        style: TextStyle(fontSize: 11, color: Color(0xFF888888)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ━━━ 迷你播放器条（有播放内容时显示） ━━━
          if (currentTrack != null)
            _MiniPlayerBar(
              track: currentTrack,
              isPlaying: isPlaying,
              onTap: _showMusicPlayer,
            ),

          // ━━━ 功能入口 ━━━
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCard : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              children: _functions.map((f) {
                return Expanded(
                  child: _FuncButton(
                    func: f,
                    onTap: () => _onFuncTap(f),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

/// 功能入口数据
class _FuncItem {
  final IconData icon;
  final String label;
  final String? route;

  const _FuncItem({required this.icon, required this.label, this.route});
}

/// 功能按钮
class _FuncButton extends StatelessWidget {
  final _FuncItem func;
  final VoidCallback onTap;

  const _FuncButton({required this.func, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.bamboo.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(
            color: AppTheme.bamboo.withValues(alpha: 0.2),
            width: 0.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(func.icon, color: AppTheme.bambooDeep, size: 26),
            const SizedBox(height: 6),
            Text(
              func.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : AppTheme.softText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 迷你播放器条
class _MiniPlayerBar extends StatelessWidget {
  final dynamic track;
  final bool isPlaying;
  final VoidCallback onTap;

  const _MiniPlayerBar({
    required this.track,
    required this.isPlaying,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = track.title ?? '未知歌曲';
    final artist = track.artist ?? '未知歌手';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
              color: AppTheme.bamboo,
              size: 32,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppTheme.softText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    artist,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[400] : AppTheme.subText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.keyboard_arrow_up, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}
