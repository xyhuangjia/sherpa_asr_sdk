import 'dart:math';
import 'package:flutter/material.dart';

/// 录音波形动画绘制器（赛博青蓝霓虹风格）。
///
/// 由多层正弦波纹、中心脉冲辉光与径向声波条叠加而成。
/// 径向声波条采用青→钴 SweepGradient，并叠加外发光实现霓虹效果。
class WaveformPainter extends CustomPainter {
  final double animationValue;
  final Color color;
  final int waveCount;
  final double opacity;

  /// 是否启用霓虹外发光。
  final bool glow;

  /// 第二渐变色（钴蓝），与 [color]（青）构成渐变。
  final Color? gradientColor;

  WaveformPainter({
    required this.animationValue,
    required this.color,
    this.waveCount = 3,
    this.opacity = 0.6,
    this.glow = true,
    this.gradientColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final maxRadius = min(size.width, size.height) / 2;

    // 绘制多层波纹
    for (int wave = 0; wave < waveCount; wave++) {
      final phase = wave * 0.3;
      final waveProgress = (animationValue + phase) % 1.0;
      final radius = maxRadius * waveProgress;
      final waveOpacity = opacity * (1.0 - waveProgress);

      if (waveOpacity <= 0) continue;

      final paint = Paint()
        ..color = color.withValues(alpha: waveOpacity * 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      final wobbleRadius = radius + sin(animationValue * 2 * pi * 2 + wave) * 4;

      canvas.drawCircle(Offset(centerX, centerY), wobbleRadius.abs(), paint);
    }

    // 中心脉冲辉光
    final pulseRadius = 40.0 + sin(animationValue * 2 * pi) * 6.0;
    final pulseRect = Rect.fromCircle(
      center: Offset(centerX, centerY),
      radius: pulseRadius,
    );
    final pulsePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: 0.35),
          color.withValues(alpha: 0.08),
          color.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.7, 1.0],
      ).createShader(pulseRect);
    canvas.drawCircle(Offset(centerX, centerY), pulseRadius, pulsePaint);

    // 径向声波条（霓虹辉光）
    _drawWaveBars(canvas, size);
  }

  void _drawWaveBars(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    const barCount = 24;
    const barWidth = 3.0;
    final radius = min(size.width, size.height) / 2 * 0.45;

    final second = gradientColor ?? const Color(0xFF3B82F6);
    final fullRect = Offset.zero & size;

    // 青→钴 径向扫描渐变（每个角度取对应颜色，复用单一 shader）。
    final sweepShader = SweepGradient(
      center: Alignment.center,
      startAngle: -pi / 2,
      endAngle: 3 * pi / 2,
      colors: [color, second, color],
      stops: const [0.0, 0.5, 1.0],
    ).createShader(fullRect);

    // 外发光画笔（渐变 + 模糊），循环外创建复用。
    final glowPaint = Paint()
      ..shader = sweepShader
      ..strokeWidth = barWidth + 2
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 5);

    for (int i = 0; i < barCount; i++) {
      final angle = (i / barCount) * 2 * pi - pi / 2;
      final barAnimation = sin(animationValue * 2 * pi * 2 + i * 0.5);
      final barHeight = 8.0 + barAnimation.abs() * 16.0;

      final startOffset = Offset(
        centerX + cos(angle) * radius,
        centerY + sin(angle) * radius,
      );
      final endOffset = Offset(
        centerX + cos(angle) * (radius + barHeight),
        centerY + sin(angle) * (radius + barHeight),
      );

      final intensity = 0.4 + barAnimation.abs() * 0.3;

      // 外发光层（霓虹辉光）
      if (glow) {
        canvas.drawLine(startOffset, endOffset, glowPaint);
      }

      // 清晰条（实色，亮度随动画脉动）
      final barPaint = Paint()
        ..color = color.withValues(alpha: intensity)
        ..strokeWidth = barWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(startOffset, endOffset, barPaint);
    }
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.color != color ||
        oldDelegate.glow != glow;
  }
}
