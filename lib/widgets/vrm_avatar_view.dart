// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 3D 全身人形视图（替换 Live2D 的 2D 角色）
//
// 用 model_viewer_plus 渲染 GLB，自动播放模型内嵌的走路动画剪辑。
// 真骨骼驱动 → 膝盖弯曲 + 脚离地 + 手臂摆动，是 Live2D 物理上做不到的。
//
// 加载策略（健壮，不会因缺文件崩）：
//   1. 优先用「当前角色」对应的资产（zhuyu / dog / girl / boy 四选一）
//   2. 找不到则回退到 kFallbackAvatarAsset（CesiumMan，Khronos 官方样本，
//      Apache-2.0 免费，自带 walk 动画）—— 仅作占位，避免人物"魔幻"。
//
// 角色切换（用户操作 / 调试）：
//   - VrmAvatarView 内置一排角色切换 chip（竹笌 / 狗子 / 女 / 男），
//     showRoleSwitch: true 时显示，默认 false（聊天页保持干净全屏）。
//   - 默认角色 VrmRole.zhuyu（竹笌少年），const VrmAvatarView() 行为与旧版一致。
//
// 资产清单（assets/vrm_test/，均在 pubspec.yaml 声明）：
//   - zhuyu_avatar.glb  程序化竹笌少年（分部位配色 + 走路动画）
//   - dog_avatar.glb    程序化音乐狗子（圆头+垂耳+四腿+尾巴）
//   - char_girl.glb     图生 3D 女角色（腾讯混元 3D，单视图重建，2026-08-31）
//   - char_boy.glb      图生 3D 男角色（同上）
//
// 相机参数抽到常量，方便按新角色身高/站姿微调框景。
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:zhuyapp/core/services/remote_asset_manager.dart';

/// 是否启用 3D 人形（true=用 model_viewer_plus 渲染 GLB；false=用旧 Live2D）。
const bool kUseVrmAvatar = true;

/// 角色 → manifest key 映射（详见 assets/remote_assets.json）。
/// 注意：这些常量现在存的是** manifest key**（如 'zhuyu_avatar'），不再是 asset 路径；
/// 运行时由 RemoteAssetManager 按 key 从 GitHub Release 下载 GLB 并转成本地 file:// 路径。
/// GLB 已从 git 仓库移除（约 132MB），改为运行时按需下载，避免仓库膨胀。
const String kUserAvatarAsset = 'zhuyu_avatar';
const String kDogAvatarAsset = 'dog_avatar';
const String kGirlAvatarAsset = 'char_girl';
const String kBoyAvatarAsset = 'char_boy';
const String kFallbackAvatarAsset = 'CesiumMan';

/// 相机框景（按角色身高/站姿微调）。
/// 竹笌少年身高约 1.6m，5m 距离 + 60° 俯角可保证全身在屏内。
const String kCameraOrbit = '0deg 60deg 5m';
const String kCameraTarget = '0m 0.85m 0m';
const String kFieldOfView = '32deg';

/// 各角色相机框景（按 GLB 实测包围盒反推）。
/// - zhuyu / dog：程序化人形约 1.6m，沿用原假设框景。
/// - girl / boy：腾讯混元单视图重建，实测约 0.73m / 0.61m（正面壳体，Z 全在负侧），
///   需拉近框景才能看清；后续在 Blender 里缩放到 ~1.6m 后此处要同步调。
const Map<VrmRole, (String orbit, String target)> kVrmRoleCamera = {
  VrmRole.zhuyu: (kCameraOrbit, kCameraTarget),
  VrmRole.dog: (kCameraOrbit, kCameraTarget),
  // 实测后截图发现 1.46m/70° 太贴近、只框到腰以下；继续拉远并把 target 上移，
  // 让头部也进框。女 H=0.728m、男 H=0.614m，这里按男等比缩放距离。
  // 实测：女 2.50m/0.00m 可框全身（含帽子）；男同样给 2.50m，避免头顶被切。
  VrmRole.girl: ('0deg 60deg 2.50m', '0m 0.00m 0m'),
  VrmRole.boy: ('0deg 60deg 2.50m', '0m 0.00m 0m'),
};

/// 可选 3D 角色。
enum VrmRole {
  /// 竹笌少年（默认，程序化生成）。
  zhuyu,
  /// 音乐狗子（程序化生成）。
  dog,
  /// 图生 3D 女角色。
  girl,
  /// 图生 3D 男角色。
  boy,
}

/// 角色 → 资产路径映射。
const Map<VrmRole, String> kVrmRoleAssets = {
  VrmRole.zhuyu: kUserAvatarAsset,
  VrmRole.dog: kDogAvatarAsset,
  VrmRole.girl: kGirlAvatarAsset,
  VrmRole.boy: kBoyAvatarAsset,
};

/// 角色切换 chip 的展示顺序与中文标签。
const List<(VrmRole, String)> kVrmRoleChips = [
  (VrmRole.zhuyu, '竹笌'),
  (VrmRole.dog, '狗子'),
  (VrmRole.girl, '女'),
  (VrmRole.boy, '男'),
];

class VrmAvatarView extends StatefulWidget {
  const VrmAvatarView({
    super.key,
    /// 显式指定资产路径（覆盖 role 解析）。一般不用，直接用 [role] 即可。
    this.asset,
    /// 默认展示的角色，向后兼容：不传 = 竹笌少年。
    this.role = VrmRole.zhuyu,
    /// 是否显示角色切换 chip 条（聊天页默认 false，调试页设 true）。
    this.showRoleSwitch = false,
    this.cameraOrbit = kCameraOrbit,
    this.cameraTarget = kCameraTarget,
    this.fieldOfView = kFieldOfView,
    this.displayScale = 1.0,
  });

  /// 显式资产路径覆盖（优先级高于 role）。
  final String? asset;

  /// 默认角色。
  final VrmRole role;

  /// 是否显示角色切换条。
  final bool showRoleSwitch;

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
  late VrmRole _currentRole;
  // 解析完成前为空，build 时显示空白（加载中），避免用无效 src 渲染。
  String _src = '';

  @override
  void initState() {
    super.initState();
    _currentRole = widget.role;
    _resolveAsset();
  }

  /// 优先用当前角色（或显式 asset = manifest key）对应的资产，按需从 release 下载，
  /// 失败则回退占位 CesiumMan；都失败保持空白，不崩。
  Future<void> _resolveAsset() async {
    final key = widget.asset ?? kVrmRoleAssets[_currentRole]!;
    try {
      final localPath = await RemoteAssetManager.instance.resolveLocalPath(key);
      if (mounted) setState(() => _src = localPath);
      return;
    } catch (_) {
      // 目标角色下载/加载失败 → 回退占位 CesiumMan
    }
    try {
      final fb = await RemoteAssetManager.instance
          .resolveLocalPath(kFallbackAvatarAsset);
      if (mounted) setState(() => _src = fb);
    } catch (_) {
      // 占位也失败（极端断网）→ 保持空白，不崩
      if (mounted) setState(() => _src = '');
    }
  }

  /// 用户点击角色切换 chip。
  void _onRoleSelected(VrmRole role) {
    debugPrint('[VrmAvatarView] chip tapped: $role, current: $_currentRole, src: $_src');
    if (role == _currentRole) return;
    if (mounted) setState(() => _currentRole = role);
    _resolveAsset();
  }

  /// 相机参数：用户显式传入（≠共享默认）时优先，否则按当前角色取实测框景。
  String get _effectiveOrbit =>
      widget.cameraOrbit == kCameraOrbit
          ? kVrmRoleCamera[_currentRole]!.$1
          : widget.cameraOrbit;
  String get _effectiveTarget =>
      widget.cameraTarget == kCameraTarget
          ? kVrmRoleCamera[_currentRole]!.$2
          : widget.cameraTarget;

  Widget _buildRoleSwitch() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final (role, label) in kVrmRoleChips)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                key: ValueKey('role_chip_${role.name}'),
                label: Text(label),
                selected: role == _currentRole,
                onSelected: (_) => _onRoleSelected(role),
                selectedColor: Colors.teal.withValues(alpha: 0.85),
                labelStyle: TextStyle(
                  color: role == _currentRole ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
                backgroundColor: Colors.white.withValues(alpha: 0.9),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (_src.isNotEmpty)
          Positioned.fill(
            child: Transform.scale(
              scale: widget.displayScale,
            child: ModelViewer(
              src: _src,
              alt: '3D 角色',
              // 自动播放模型内嵌的第一个动画剪辑（走路）
              autoPlay: true,
              // 用户可拖动旋转模型 = 触摸角色有反馈（解决之前"点人物没反应"）
              cameraControls: true,
              cameraOrbit: _effectiveOrbit,
              cameraTarget: _effectiveTarget,
              fieldOfView: widget.fieldOfView,
              // 完全透明背景，小狗周围没有方框
              backgroundColor: Colors.transparent,
            ),
          ),
        ),
        if (widget.showRoleSwitch)
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: _buildRoleSwitch(),
          ),
      ],
    );
  }
}
