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

/// 程序化生成的音乐狗子 3D 宠物（圆头+垂耳+身体+四条腿+尾巴，走路+摇尾巴）。
const String kDogAvatarAsset = 'assets/vrm_test/dog_avatar.glb';

/// 占位角色（用户还没放动漫角色时用，避免灰色测试人偶太违和可换 Fox 等）。
const String kFallbackAvatarAsset = 'assets/vrm_test/CesiumMan.glb';

/// 相机框景（按角色身高/站姿微调）。
/// 竹笌少年身高约 1.6m，5m 距离 + 60° 俯角可保证全身在屏内。
const String kCameraOrbit = '0deg 60deg 5m';
const String kCameraTarget = '0m 0.85m 0m';
const String kFieldOfView = '32deg';

class VrmAvatarView extends StatefulWidget {
  const VrmAvatarView({
    super.key,
    this.asset = kUserAvatarAsset,
    this.cameraOrbit = kCameraOrbit,
    this.cameraTarget = kCameraTarget,
    this.fieldOfView = kFieldOfView,
    this.displayScale = 1.0,
  });

  /// 指定使用哪个 3D 模型资产，默认用竹笌少年人形；传 kDogAvatarAsset 用音乐狗子。
  final String asset;

  /// 相机轨道（方位角 仰角 距离），如 '0deg 60deg 5m'。
  final String cameraOrbit;

  /// 相机目标点（模型中心位置），如 '0m 0.85m 0m'。
  final String cameraTarget;

  /// 视野角度，如 '32deg'。
  final String fieldOfView;

  /// 显示缩放，直接控制模型在屏幕上的大小（1.0=原始大小，0.5=缩小一半）。
  final double displayScale;

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

  /// 优先用指定资产，找不到就回退占位。
  Future<void> _resolveAsset() async {
    try {
      await rootBundle.load(widget.asset);
      if (mounted) setState(() => _src = widget.asset);
    } catch (_) {
      // 指定资产不存在 → 保持占位 CesiumMan（不崩）
    }
  }

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: widget.displayScale,
      child: ModelViewer(
        src: _src,
        alt: '3D 角色',
        // 自动播放模型内嵌的第一个动画剪辑（走路）
        autoPlay: true,
        // 用户可拖动旋转模型 = 触摸角色有反馈（解决之前"点人物没反应"）
        cameraControls: true,
        cameraOrbit: widget.cameraOrbit,
        cameraTarget: widget.cameraTarget,
        fieldOfView: widget.fieldOfView,
        // 完全透明背景，小狗周围没有方框
        backgroundColor: Colors.transparent,
      ),
    );
  }
}
