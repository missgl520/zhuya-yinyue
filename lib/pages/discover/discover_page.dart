// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 发现页 · 竹林一角（Discover — Bamboo Grove）
//
// 还原图 2 设计：纯竹林背景（与首页聊天的 0xFFEDF7F0 同色），左下角小竹笌吉祥物，
// 几根装饰竹子；没有卡片、按钮、列表，干净留白。
//
// 背景叠加装饰竹子（用 CustomPaint 绘制几根绿色圆角竹柱），竹笌在左下角。
// 用户从此页可点击吉祥物 → 进全屏 3D 角色页（/avatar）。
// 底部导航已移除（首页/发现/我的不再有 tab）。
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DiscoverPage extends StatelessWidget {
  const DiscoverPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEDF7F0),
      body: Stack(
        children: [
          // 装饰竹林：几根高低不一的绿色竹柱（用 Container 模拟）
          const Positioned.fill(child: _BambooGrove()),

          // 左下角的小竹笌吉祥物 → 点击进入全屏 3D 角色页
          Positioned(
            left: 24,
            bottom: 36,
            child: GestureDetector(
              onTap: () => context.push('/avatar'),
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: 96,
                height: 96,
                child: Image.asset(
                  'assets/splash_char_transparent.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),

          // 左上角小返回箭头（让用户能回首页聊天）
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 12, top: 8),
              child: IconButton(
                tooltip: '返回',
                icon: const Icon(
                  Icons.arrow_back,
                  size: 22,
                  color: Color(0xFF3D6B1E),
                ),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/home');
                  }
                },
              ),
            ),
          ),

          // 右下角小提示「点竹笌进入全屏」
          Positioned(
            right: 20,
            bottom: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                '点竹笌进入全屏',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF3D6B1E),
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 几根装饰性的竹柱，画在浅绿背景上。
/// 高矮 / 左右各异，纯装饰，无交互。
class _BambooGrove extends StatelessWidget {
  const _BambooGrove();

  @override
  Widget build(BuildContext context) {
    // 8 根竹子：(left_ratio, top_ratio, width, height_ratio, opacity, hueShift)
    final stalks = [
      _Stalk(left: 0.04, top: -0.10, w: 22, h: 0.95, alpha: 0.55),
      _Stalk(left: 0.12, top: -0.05, w: 18, h: 0.80, alpha: 0.45),
      _Stalk(left: 0.28, top: -0.15, w: 26, h: 1.05, alpha: 0.65),
      _Stalk(left: 0.46, top: -0.08, w: 20, h: 0.90, alpha: 0.50),
      _Stalk(left: 0.60, top: -0.20, w: 28, h: 1.15, alpha: 0.70),
      _Stalk(left: 0.74, top: -0.04, w: 18, h: 0.85, alpha: 0.45),
      _Stalk(left: 0.88, top: -0.18, w: 24, h: 1.00, alpha: 0.60),
      _Stalk(left: 0.96, top: -0.10, w: 16, h: 0.80, alpha: 0.50),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        return Stack(
          children: [
            for (final s in stalks)
              Positioned(
                left: size.width * s.left,
                top: size.height * s.top,
                child: _BambooStalk(
                  width: s.w,
                  height: size.height * s.h,
                  alpha: s.alpha,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Stalk {
  final double left, top, w, h, alpha;
  const _Stalk({
    required this.left,
    required this.top,
    required this.w,
    required this.h,
    required this.alpha,
  });
}

/// 一根竹柱：渐变绿色矩形 + 几道横纹（竹节），上下端用 Container
/// 圆角处理模拟竹子段头。
class _BambooStalk extends StatelessWidget {
  final double width, height, alpha;
  const _BambooStalk({
    required this.width,
    required this.height,
    required this.alpha,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color.lerp(
      const Color(0xFF8BC891),
      const Color(0xFFB8E0A2),
      0.45,
    )!.withValues(alpha: alpha);
    final darker = const Color(0xFF6FB57A).withValues(alpha: alpha);

    return SizedBox(
      width: width,
      height: max(80.0, height),
      child: CustomPaint(
        painter: _BambooPainter(color: color, ring: darker),
      ),
    );
  }
}

/// 用 Canvas 画一个竖向渐变的竹柱 + 等距的横竹节环。
class _BambooPainter extends CustomPainter {
  final Color color;
  final Color ring;
  _BambooPainter({required this.color, required this.ring});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 主体渐变（从浅到中绿）
    final body = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          color.withValues(alpha: color.a * 1.1),
          color,
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    final rrect = RRect.fromRectAndCorners(
      Rect.fromLTWH(0, 0, w, h),
      topLeft: const Radius.circular(8),
      topRight: const Radius.circular(8),
      bottomLeft: const Radius.circular(8),
      bottomRight: const Radius.circular(8),
    );
    canvas.drawRRect(rrect, body);

    // 4 道横竹节
    final ringPaint = Paint()
      ..color = ring
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (var i = 1; i <= 4; i++) {
      final y = h * i / 5;
      canvas.drawLine(Offset(0, y), Offset(w, y), ringPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BambooPainter old) =>
      old.color != color || old.ring != ring;
}
