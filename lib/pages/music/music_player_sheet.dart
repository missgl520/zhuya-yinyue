// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 播放器悬浮卡片（MusicPlayerSheet）
// 路由：作为 BottomSheet 弹出
// 功能：播放控制 + 进度条 + 下载
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../providers/music_player_provider.dart';

class MusicPlayerSheet extends ConsumerWidget {
  const MusicPlayerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(currentTrackProvider);
    final state = ref.watch(playerStateProvider);
    final notifier = ref.read(playerStateProvider.notifier);

    if (track == null) return const SizedBox.shrink();

    final progress = state.duration.inMilliseconds > 0
        ? state.position.inMilliseconds / state.duration.inMilliseconds
        : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // 拖动条
            Container(width: 40, height: 4, decoration: BoxDecoration(
              color: AppTheme.border, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),

            // 封面
            Container(
              width: 180, height: 180,
              decoration: BoxDecoration(
                color: AppTheme.surfaceSunken,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: AppTheme.accent.withValues(alpha: 0.2), blurRadius: 20)],
              ),
              child: track.coverUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(track.coverUrl!, width: 180, height: 180, fit: BoxFit.cover),
                    )
                  : const Icon(Icons.music_note, size: 80, color: AppTheme.muted),
            ),
            const SizedBox(height: 20),

            // 歌曲信息
            Text(track.title, style: const TextStyle(
              fontSize: 17, fontWeight: FontWeight.w600, color: AppTheme.fg),
              maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(track.artist, style: const TextStyle(
              fontSize: 13, color: AppTheme.muted), maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),

            // 进度条
            Column(children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                  activeTrackColor: AppTheme.accent,
                  inactiveTrackColor: AppTheme.border,
                  thumbColor: AppTheme.accent,
                  overlayColor: AppTheme.accent.withValues(alpha: 0.2),
                ),
                child: Slider(
                  value: progress.clamp(0.0, 1.0),
                  onChanged: (v) {
                    final pos = Duration(milliseconds: (v * state.duration.inMilliseconds).round());
                    notifier.seek(pos);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(_fmt(state.position), style: const TextStyle(fontSize: 11, color: AppTheme.muted)),
                  Text(_fmt(state.duration), style: const TextStyle(fontSize: 11, color: AppTheme.muted)),
                ]),
              ),
            ]),
            const SizedBox(height: 16),

            // 控制按钮
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(
                icon: const Icon(Icons.download_outlined, size: 28),
                color: AppTheme.muted,
                onPressed: state.isDownloading ? null : () async {
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
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.skip_previous_rounded, size: 40),
                color: AppTheme.fg,
                onPressed: () => notifier.seek(Duration.zero),
              ),
              const SizedBox(width: 8),
              // 播放/暂停
              GestureDetector(
                onTap: () {
                  if (state.isBuffering) return;
                  if (state.isPlaying) notifier.pause();
                  else {
                    if (track != ref.read(currentTrackProvider)) {
                      notifier.play(track);
                    } else {
                      notifier.resume();
                    }
                  }
                },
                child: Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: AppTheme.accent.withValues(alpha: 0.3), blurRadius: 12)],
                  ),
                  child: state.isBuffering
                      ? const Padding(padding: EdgeInsets.all(18), child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : Icon(state.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 36, color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.stop_rounded, size: 40),
                color: AppTheme.fg,
                onPressed: () => notifier.stop(),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 28),
                color: AppTheme.muted,
                onPressed: () {
                  notifier.stop();
                  Navigator.of(context).pop();
                },
              ),
            ]),

            if (state.error != null) ...[
              const SizedBox(height: 12),
              Text(state.error!, style: const TextStyle(fontSize: 12, color: AppTheme.danger)),
            ],

            // 下载进度
            if (state.isDownloading) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: state.downloadProgress, backgroundColor: AppTheme.border, color: AppTheme.accent),
            ],
          ]),
        ),
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
