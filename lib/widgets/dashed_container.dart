// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 虚线边框容器（零依赖）
//
// 用于：聊天页消息半透明浮层（嫩绿虚线边框）、卡片描边等。
// Flutter 原生 BoxDecoration 不支持虚线，这里用 CustomPainter 自绘。
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/material.dart';

class DashedContainer extends StatelessWidget {
  final Widget child;
  final Color borderColor;
  final double strokeWidth;
  final double dashWidth;
  final double dashGap;
  final double borderRadius;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const DashedContainer({
    super.key,
    required this.child,
    this.borderColor = const Color(0xFF8BC34A),
    this.strokeWidth = 1.0,
    this.dashWidth = 6.0,
    this.dashGap = 4.0,
    this.borderRadius = 16.0,
    this.backgroundColor,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: CustomPaint(
        foregroundPainter: _DashedPainter(
          color: borderColor,
          strokeWidth: strokeWidth,
          dashWidth: dashWidth,
          dashGap: dashGap,
          borderRadius: borderRadius,
        ),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _DashedPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashGap;
  final double borderRadius;

  const _DashedPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashWidth,
    required this.dashGap,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(strokeWidth / 2),
      Radius.circular(borderRadius),
    );
    final path = Path()..addRRect(rrect);

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final dashedPath = _createDashedPath(path, dashWidth, dashGap);
    canvas.drawPath(dashedPath, paint);
  }

  Path _createDashedPath(Path source, double dashWidth, double dashGap) {
    final dest = Path();
    final metric = source.computeMetrics().toList();
    for (final m in metric) {
      var distance = 0.0;
      final length = m.length;
      while (distance < length) {
        final next = distance + dashWidth;
        dest.addPath(
          m.extractPath(distance, next > length ? length : next),
          Offset.zero,
        );
        distance = next + dashGap;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(covariant _DashedPainter old) =>
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.borderRadius != borderRadius;
}
