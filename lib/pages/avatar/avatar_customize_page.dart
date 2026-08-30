// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 角色换装定制页
//
// 路由：/avatar/customize
// 功能：
//   - 左侧/上方：3D 角色预览（WebView + Three.js）+ Idle 呼吸动画
//   - 右侧/下方：换装选择面板（性别/发型/上装/下装/鞋子/瞳色）
//   - 拖动旋转角色，滚轮缩放
//   - 预设快速搭配
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../widgets/avatar_viewer.dart';
import '../widgets/avatar_customizer_panel.dart';
import '../../presentation/providers/avatar_provider.dart';
import '../../core/theme/app_theme.dart';

class AvatarCustomizePage extends ConsumerWidget {
  const AvatarCustomizePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(avatarStateProvider);
    final isPortrait =
        MediaQuery.of(context).size.height > MediaQuery.of(context).size.width * 1.2;

    return Scaffold(
      backgroundColor: const Color(0xFFEDF7F0),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.fg),
          onPressed: () => context.go('/chat'),
        ),
        title: Text(
          state.gender == Gender.male ? '少年换装' : '少女换装',
          style: const TextStyle(
            color: AppTheme.fg, fontWeight: FontWeight.w600, fontSize: 17,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () => context.go('/chat'),
            child: const Text('完成',
              style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w600, fontSize: 15)),
          ),
        ],
      ),
      body: isPortrait
          ? Column(children: [
              Expanded(flex: 5, child: _ViewerSection(gender: state.gender)),
              const Divider(height: 1, color: AppTheme.border),
              const Expanded(flex: 4, child: AvatarCustomizerPanel()),
            ])
          : Row(children: [
              Expanded(flex: 5, child: _ViewerSection(gender: state.gender)),
              const VerticalDivider(width: 1, color: AppTheme.border),
              const Expanded(flex: 4, child: AvatarCustomizerPanel()),
            ]),
    );
  }
}

class _ViewerSection extends StatelessWidget {
  final Gender gender;
  const _ViewerSection({required this.gender});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: AvatarViewer()),

        // 左上角角色标签
        Positioned(
          top: 12, left: 16,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Container(
              key: ValueKey(gender),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    gender == Gender.male ? Icons.face : Icons.face_3,
                    size: 14,
                    color: AppTheme.accent,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    gender == Gender.male ? '少年' : '少女',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.fg2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 右下角操作提示
        Positioned(
          right: 12, bottom: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.touch_app, size: 12, color: AppTheme.fg2),
                SizedBox(width: 4),
                Text(
                  '拖动旋转 · 滚轮缩放',
                  style: TextStyle(fontSize: 11, color: AppTheme.fg2),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
