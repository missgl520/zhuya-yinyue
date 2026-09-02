// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 播放器悬浮卡片（MusicPlayerSheet）
// 路由：作为 BottomSheet 弹出
// 功能：播放控制 + 进度条 + 下载
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/audio_process_service.dart' show ProcessState;
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

            const SizedBox(height: 8),

            // 处理进度（下载 → FFmpeg处理）
            if (state.isProcessing) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(children: [
                  Row(children: [
                    if (state.processState == ProcessState.downloading)
                      const Icon(Icons.downloading_rounded, size: 16, color: AppTheme.accent)
                    else
                      const Icon(Icons.tune_rounded, size: 16, color: AppTheme.accent),
                    const SizedBox(width: 8),
                    Text(
                      state.processMessage ?? '处理中…',
                      style: const TextStyle(fontSize: 12, color: AppTheme.accent),
                    ),
                    const Spacer(),
                    Text(
                      '${(state.processProgress * 100).toInt()}%',
                      style: const TextStyle(fontSize: 11, color: AppTheme.muted),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: state.processProgress,
                      backgroundColor: AppTheme.border,
                      color: AppTheme.accent,
                      minHeight: 3,
                    ),
                  ),
                ]),
              ),
            ] else if (state.processState == ProcessState.done && state.processMessage == '播放中') ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.auto_awesome, size: 13, color: AppTheme.success),
                  SizedBox(width: 4),
                  Text('响度增强 · 动态优化', style: TextStyle(fontSize: 11, color: AppTheme.success)),
                ]),
              ),
            ],

            if (state.error != null) ...[
              const SizedBox(height: 8),
              Text(state.error!, style: const TextStyle(fontSize: 12, color: AppTheme.danger)),
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
