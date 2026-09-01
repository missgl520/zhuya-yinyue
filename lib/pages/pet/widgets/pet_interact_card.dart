// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 宠物互动按钮面板（喂食/玩耍/抚摸/对话/睡觉）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/app_icon.dart';

/// 单个互动按钮
class PetInteractButton extends StatefulWidget {
  final String label;
  final AppIconName icon;
  final Color color;
  final VoidCallback? onTap;
  final bool pressed;

  const PetInteractButton({super.key, required this.label, required this.icon, required this.color, this.onTap, this.pressed = false});

  @override
  State<PetInteractButton> createState() => _PetInteractButtonState();
}

class _PetInteractButtonState extends State<PetInteractButton> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: const Duration(milliseconds: 120), vsync: this);
    _scale = Tween<double>(begin: 1.0, end: 0.88).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _onTapDown(TapDownDetails d) { _ctrl.forward(); }
  void _onTapUp(TapUpDetails d) { _ctrl.reverse(); widget.onTap?.call(); }
  void _onTapCancel() { _ctrl.reverse(); }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onTap == null;
    return GestureDetector(
      onTapDown: isDisabled ? null : _onTapDown,
      onTapUp: isDisabled ? null : _onTapUp,
      onTapCancel: isDisabled ? null : _onTapCancel,
      child: ScaleTransition(scale: _scale,
        child: Container(
          width: 60, height: 68,
          decoration: BoxDecoration(
            color: widget.pressed ? widget.color.withValues(alpha: 0.3) : AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: widget.pressed ? widget.color : AppTheme.border.withValues(alpha: 0.4), width: 1),
            boxShadow: [BoxShadow(color: widget.pressed ? widget.color.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
            AppIcon(name: widget.icon, size: AppIconSize.sm, color: isDisabled ? AppTheme.muted : widget.color),
            const SizedBox(height: 4),
            Text(widget.label, style: TextStyle(fontSize: AppTheme.textXs, color: isDisabled ? AppTheme.muted : AppTheme.fg2)),
          ]),
        ),
      ),
    );
  }
}

/// 互动面板卡片
class PetInteractCard extends StatelessWidget {
  final void Function(String action) onAction;
  final String? pressedAction;

  const PetInteractCard({super.key, required this.onAction, this.pressedAction});

  @override
  Widget build(BuildContext context) {
    final actions = [
      ('喂食', AppIconName.disc, AppTheme.ember),
      ('玩耍', AppIconName.smile, AppTheme.sun),
      ('抚摸', AppIconName.heart, AppTheme.accent),
      ('对话', AppIconName.messageCircle, AppTheme.bambooDeep),
      ('睡觉', AppIconName.moon, AppTheme.secondary),
    ];
    return Container(
      padding: const EdgeInsets.all(AppTheme.space4),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('互动', style: TextStyle(fontSize: AppTheme.textMd, fontWeight: FontWeight.w600, color: AppTheme.fg)),
        const SizedBox(height: AppTheme.space3),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: actions.map((a) => PetInteractButton(
          label: a.$1, icon: a.$2, color: a.$3,
          pressed: pressedAction == a.$1,
          onTap: () => onAction(a.$1),
        )).toList()),
      ]),
    );
  }
}
