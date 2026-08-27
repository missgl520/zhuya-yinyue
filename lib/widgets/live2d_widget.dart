// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Live2D 虚拟角色 Widget
//
// 集成 flutter_live2d，接 Live2D 官方免费示例模型 Ren（Cubism 3，合规可分发）
//
// 关键约束（务必保持）：Live2DView 必须「始终挂载」在 widget 树上。
//   flutter_live2d 的原生平台视图（Android GL / iOS GL）只有在 Live2DView
//   被真正放进树里时才会创建，controller.whenAttached 才会完成。
//   旧实现在「模型未加载」时用占位符替换掉 Live2DView、且传 controller:null：
//   平台视图永远不挂载 → whenAttached 死锁 → 模型永远加载不出来。
//   因此这里改为：Live2DView 常驻，加载 / 错误状态用 Stack 叠加层显示。
//
// 触摸交互（v2.0 优化）：
//   单击上半区（头/脸） → 随机表情变化
//   单击下半区（身体） → 摇晃动画
//   双击任意位置       → 害羞脸红彩蛋
//   长按头/脸区域      → 持续害羞表情（松开恢复）
//   长按身体区域       → 持续摇晃动画（松开恢复）
//
// 竹笌状态 → 动画映射：
//   idle        → Idle 待机动画（循环）+ exp_01 表情
//   thinking    → exp_02 表情（等 AI 回复）
//   speaking    → TapBody 动画 + exp_03 表情（竹笌在说话）
//   listening   → exp_04 表情（用户在说话，竹笌专注）
//
// 模型：assets/live2d/ren/
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/material.dart';
import 'package:flutter_live2d/flutter_live2d.dart';
import 'live2d_controller.dart';

/// 竹笌 Live2D 虚拟角色 Widget
///
/// 必须配合 ZhuaLive2DController 使用：
///   final controller = ref.read(live2dControllerProvider);
///   ZhuaLive2DWidget(controller: controller.viewController)
class ZhuaLive2DWidget extends StatefulWidget {
  final Live2DViewController controller;
  final VoidCallback? onTap;

  const ZhuaLive2DWidget({super.key, required this.controller, this.onTap});

  @override
  State<ZhuaLive2DWidget> createState() => _ZhuaLive2DWidgetState();
}

class _ZhuaLive2DWidgetState extends State<ZhuaLive2DWidget> {
  /// 触摸区域
  TouchZone? _currentZone;

  /// 处理单击：按位置分区触发反应
  void _handleSingleTap(TapUpDetails details) {
    final size = context.size ?? const Size(120, 200);
    ZhuaLive2DController.instance.handleTouch(details.localPosition, size);
    widget.onTap?.call();
  }

  /// 处理双击：害羞彩蛋
  void _handleDoubleTap() {
    ZhuaLive2DController.instance.playDoubleTap();
    widget.onTap?.call();
  }

  /// 长按开始：记录区域并通知 Controller
  void _handleLongPressStart(LongPressStartDetails details) {
    final size = context.size ?? const Size(120, 200);
    _currentZone = ZhuaLive2DController.instance.getZone(
      details.localPosition,
      size,
    );
    if (_currentZone != null) {
      ZhuaLive2DController.instance.startLongPress(_currentZone!);
    }
  }

  /// 长按结束：通知 Controller 停止
  void _handleLongPressEnd(LongPressEndDetails details) {
    if (_currentZone != null) {
      ZhuaLive2DController.instance.endLongPress();
      _currentZone = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          fit: StackFit.expand,
          children: [
            // ① 始终挂载 Live2DView —— 平台视图不挂载则 whenAttached 死锁，
            //    且必须绑定「真正的单例控制器」(widget.controller)，否则加载的是
            //    另一个从未被原生视图绑定的空控制器实例。
            GestureDetector(
              // 单击（Flutter 原生双击拦截，不用手写延迟）
              onTapUp: _handleSingleTap,
              // 双击（Flutter 原生，比手写更准确更快）
              onDoubleTap: _handleDoubleTap,
              // 长按开始
              onLongPressStart: _handleLongPressStart,
              // 长按结束
              onLongPressEnd: _handleLongPressEnd,
              child: Live2DView(controller: widget.controller),
            ),

            // ② 错误叠加层：仅在有加载错误时显示；正常加载/未就绪时保持透明，
            //    让「竹笌在这里」提示和后面的模型/背景可见。
            ValueListenableBuilder<Live2DViewState>(
              valueListenable: widget.controller,
              builder: (context, state, _) {
                if (state.lastError == null) return const SizedBox.shrink();
                return IgnorePointer(
                  ignoring: false, // 错误状态拦截触摸，避免误触
                  child: _StatusOverlay(state: state),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

/// 模型加载失败时的兜底 UI（叠加在 Live2DView 之上）。
/// 正常加载中不再显示全屏遮罩，由 chat_page 的「竹笌在这里」轻提示替代。
class _StatusOverlay extends StatelessWidget {
  final Live2DViewState state;

  const _StatusOverlay({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6B9E78).withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFC0392B), size: 32),
            const SizedBox(height: 8),
            Text(
              '竹笌模型加载失败',
              style: TextStyle(
                color: const Color(0xFF2E4A35),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                state.lastError?.message ?? '未知错误',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF6B9E78), fontSize: 11),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
