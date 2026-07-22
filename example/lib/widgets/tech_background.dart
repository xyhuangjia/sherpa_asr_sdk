// example/lib/widgets/tech_background.dart

import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 深色科技风背景。
///
/// 由三部分叠加构成：
/// 1. 纵向渐变底（[AppGradients.background]）。
/// 2. 极淡青色等距网格（静态，无动画，性能友好）。
/// 3. 径向暗角，聚焦中心内容。
///
/// 用作页面 [Scaffold] body 的底层背景：
///
/// ```dart
/// body: TechBackground(child: ...)
/// ```
class TechBackground extends StatelessWidget {
  final Widget child;

  /// 网格单元尺寸（逻辑像素）。
  final double gridSize;

  /// 是否绘制径向暗角。
  final bool vignette;

  const TechBackground({
    super.key,
    required this.child,
    this.gridSize = 32,
    this.vignette = true,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppGradients.background),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _GridPainter(gridSize: gridSize)),
          if (vignette)
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.15),
                  radius: 1.1,
                  colors: [Color(0x00000000), Color(0x66000000)],
                  stops: [0.55, 1.0],
                ),
              ),
            ),
          child,
        ],
      ),
    );
  }
}

/// 静态网格绘制器：等距细线，中心更亮、边缘衰减。
class _GridPainter extends CustomPainter {
  final double gridSize;

  _GridPainter({required this.gridSize});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final majorPaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxDist = sqrt(cx * cx + cy * cy);

    // 垂直线
    for (double x = 0; x <= size.width; x += gridSize) {
      final dist = (x - cx).abs();
      final t = (1.0 - dist / maxDist).clamp(0.0, 1.0);
      final isMajor = (x ~/ gridSize) % 4 == 0;
      final p = isMajor ? majorPaint : linePaint;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        p..color = AppColors.primary.withValues(alpha: 0.018 + t * 0.05),
      );
    }

    // 水平线
    for (double y = 0; y <= size.height; y += gridSize) {
      final dist = (y - cy).abs();
      final t = (1.0 - dist / maxDist).clamp(0.0, 1.0);
      final isMajor = (y ~/ gridSize) % 4 == 0;
      final p = isMajor ? majorPaint : linePaint;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        p..color = AppColors.primary.withValues(alpha: 0.018 + t * 0.05),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) =>
      oldDelegate.gridSize != gridSize;
}
