// example/lib/widgets/tech_controls.dart

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 渐变 + 发光圆形动作按钮（赛博青蓝风格）。
///
/// 用于录音开始 / 停止等主操作。
class GradientFab extends StatelessWidget {
  final Gradient gradient;
  final Color glowColor;
  final IconData icon;
  final VoidCallback? onPressed;

  /// 发光强度（0 关闭）。
  final double glowAlpha;

  /// 禁用态降低透明度。
  final bool dimmed;

  const GradientFab({
    super.key,
    required this.gradient,
    required this.glowColor,
    required this.icon,
    this.onPressed,
    this.glowAlpha = 0.6,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return GestureDetector(
      onTap: onPressed,
      child: Opacity(
        opacity: dimmed ? 0.4 : 1.0,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: gradient,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.onBg.withValues(alpha: 0.12)),
            boxShadow: (disabled || glowAlpha <= 0)
                ? null
                : glow(glowColor, radius: 26, alpha: glowAlpha),
          ),
          child: Icon(icon, size: 32, color: AppColors.bg),
        ),
      ),
    );
  }
}

/// 脉冲状态指示点。`active` 时呼吸闪烁，否则静态。
class LiveDot extends StatefulWidget {
  final bool active;
  final Color color;

  const LiveDot({super.key, required this.active, required this.color});

  @override
  State<LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.active) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant LiveDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _controller.repeat();
    if (!widget.active && oldWidget.active) _controller.stop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) {
      return Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: 0.85),
          shape: BoxShape.circle,
          boxShadow: glow(widget.color, radius: 5, alpha: 0.35),
        ),
      );
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Opacity(
          opacity: 0.55 + 0.45 * t,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
              boxShadow: glow(widget.color, radius: 4 + t * 6, alpha: 0.5),
            ),
          ),
        );
      },
    );
  }
}

/// 青色发光分隔发丝线（用于区块标题、控制栏顶部等）。
class GlowHairline extends StatelessWidget {
  final Color color;
  final double height;
  final double glowAlpha;

  const GlowHairline({
    super.key,
    this.color = AppColors.primary,
    this.height = 1,
    this.glowAlpha = 0.5,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: AppGradients.hairline,
        boxShadow: glow(color, radius: 4, alpha: glowAlpha),
      ),
    );
  }
}
