// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 3D 全身人形视图（替换 Live2D 的 2D 角色）
//
// 用 model_viewer_plus 渲染 GLB，自动播放模型内嵌的走路动画剪辑。
// 真骨骼驱动 → 膝盖弯曲 + 脚离地 + 手臂摆动，是 Live2D 物理上做不到的。
//
// 加载策略（健壮，不会因缺文件崩）：
//   1. 优先用「用户提供的动漫角色」kUserAvatarAsset（zhuyu_avatar.glb）
//   2. 找不到则回退到 kFallbackAvatarAsset（CesiumMan，Khronos 官方样本，
//      Apache-2.0 免费，自带 walk 动画）—— 仅作占位，避免人物"魔幻"。
//
// 切换人物（用户操作）：
//   - 去 Sketchfab 下「anime-girl@Walking」（CC BY 4.0，VRoid+Mixamo 走路动画）
//   - 把下到的 .glb 重命名为 zhuyu_avatar.glb 放进 assets/vrm_test/
//   - 告诉我一声，我把 zhuyu_avatar.glb 加进 pubspec.yaml 的 assets 并重编即可
//
// 相机参数抽到常量，方便按新角色身高/站姿微调框景。
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:model_viewer_plus/model_viewer_plus.dart';

/// 是否启用 3D 人形（true=用 model_viewer_plus 渲染 GLB；false=用旧 Live2D）。
const bool kUseVrmAvatar = true;

/// 程序化生成的竹笌 3D 少年人形（脚本生成，分部位配色 + 走路动画）。
const String kUserAvatarAsset = 'assets/vrm_test/zhuyu_avatar.glb';

/// 占位角色（用户还没放动漫角色时用，避免灰色测试人偶太违和可换 Fox 等）。
const String kFallbackAvatarAsset = 'assets/vrm_test/CesiumMan.glb';

/// 相机框景（按角色身高/站姿微调）。
/// 竹笌少年身高约 1.6m，5m 距离 + 60° 俯角可保证全身在屏内。
const String kCameraOrbit = '0deg 60deg 5m';
const String kCameraTarget = '0m 0.85m 0m';
const String kFieldOfView = '32deg';

class VrmAvatarView extends StatefulWidget {
  const VrmAvatarView({super.key});

  @override
  State<VrmAvatarView> createState() => _VrmAvatarViewState();
}

class _VrmAvatarViewState extends State<VrmAvatarView> {
  String _src = kFallbackAvatarAsset;

  @override
  void initState() {
    super.initState();
    _resolveAsset();
  }

  /// 优先用用户动漫角色，找不到（未下载/未进 pubspec）就回退占位。
  Future<void> _resolveAsset() async {
    try {
      await rootBundle.load(kUserAvatarAsset);
      if (mounted) setState(() => _src = kUserAvatarAsset);
    } catch (_) {
      // 用户还没放动漫角色 → 保持占位 CesiumMan（不崩）
    }
  }

  @override
  Widget build(BuildContext context) {
    return ModelViewer(
      src: _src,
      alt: '竹笌 3D 角色',
      // 自动播放模型内嵌的第一个动画剪辑（走路）
      autoPlay: true,
      // 用户可拖动旋转模型 = 触摸角色有反馈（解决之前"点人物没反应"）
      cameraControls: true,
      cameraOrbit: kCameraOrbit,
      cameraTarget: kCameraTarget,
      fieldOfView: kFieldOfView,
      // 与 Live2D 默认底色一致，人物漂移时背景无缝衔接
      backgroundColor: const Color(0xFFEDF7F0),
    );
  }
}
