import 'dart:math';
import 'package:flutter/material.dart';

/// 录音波形动画绘制器
///
/// 使用多层正弦波叠加和径向声波条，模拟录音中的声波效果。
class WaveformPainter extends CustomPainter {
  final double animationValue;
  final Color color;
  final int waveCount;
  final double opacity;

  WaveformPainter({
    required this.animationValue,
    required this.color,
    this.waveCount = 3,
    this.opacity = 0.6,
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

      final wobbleRadius =
          radius + sin(animationValue * 2 * pi * 2 + wave) * 4;

      canvas.drawCircle(
        Offset(centerX, centerY),
        wobbleRadius.abs(),
        paint,
      );
    }

    // 绘制中心脉冲圆
    final pulseRadius = 40.0 + sin(animationValue * 2 * pi) * 6.0;
    final pulsePaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(centerX, centerY), pulseRadius, pulsePaint);

    // 绘制径向声波条
    _drawWaveBars(canvas, size);
  }

  void _drawWaveBars(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    const barCount = 24;
    const barWidth = 3.0;
    final radius = min(size.width, size.height) / 2 * 0.45;

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

      final barPaint = Paint()
        ..color = color.withValues(alpha: 0.4 + barAnimation.abs() * 0.3)
        ..strokeWidth = barWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(startOffset, endOffset, barPaint);
    }
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
