// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 3D 角色独立全屏页
//
// 从聊天页顶栏中间的"3D 角色"入口 push 进入，展示可旋转/缩放的 3D 竹笌角色。
// 与聊天页的拖拽 overlay 共用 AvatarViewer（WebView+Three.js），走路动画 autoplay。
// 返回：左上角返回按钮（Navigator.pop，回到 /chat）。
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/material.dart';
import '../../widgets/avatar_viewer.dart';

class AvatarFullscreenPage extends StatelessWidget {
  const AvatarFullscreenPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEDF7F0),
      body: Stack(
        children: [
          // 3D 角色占满全屏（WebView+Three.js 换装系统，支持拖动旋转+缩放）
          const Positioned.fill(child: AvatarViewer()),

          // 左上角返回按钮
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Material(
                color: Colors.white.withValues(alpha: 0.6),
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF333333)),
                  tooltip: '返回聊天',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),

          // 底部操作提示
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '拖动旋转 · 滚轮缩放',
                  style: TextStyle(fontSize: 12, color: Color(0xFF666666)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
