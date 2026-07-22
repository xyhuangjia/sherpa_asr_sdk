// example/lib/theme/app_theme.dart

import 'package:flutter/material.dart';

/// 赛博青蓝（Cyber Cyan）设计系统。
///
/// 全局唯一的颜色 / 圆角 / 间距 / 渐变令牌，以及深色 `ThemeData`。
/// 所有页面与组件应优先使用这里的令牌与 `mono` 助手，避免散落的内联颜色。

// ==================== 颜色令牌 ====================

/// 应用颜色调色板（深色科技风）。
class AppColors {
  AppColors._();

  /// 画布背景（近黑藏青）。
  static const Color bg = Color(0xFF070B14);

  /// 卡片 / 面板底色（石墨灰）。
  static const Color surface = Color(0xFF0F1623);

  /// 抬升面（AppBar / 控制栏）。
  static const Color surfaceHigh = Color(0xFF16202E);

  /// 最高抬升面（输入 / 滑块轨道）。
  static const Color surfaceHighest = Color(0xFF1C2837);

  /// 主光：电光青。
  static const Color primary = Color(0xFF22D3EE);

  /// 主光弱化（描边 / 次级）。
  static const Color primaryDim = Color(0xFF0E7490);

  /// 辅光：钴蓝。
  static const Color secondary = Color(0xFF3B82F6);

  /// 成功 / 就绪。
  static const Color success = Color(0xFF34D399);

  /// 警示 / 录音停止（现代玫红）。
  static const Color error = Color(0xFFF43F5E);

  /// 主文字（冰白）。
  static const Color onBg = Color(0xFFE2E8F0);

  /// 次文字（板岩）。
  static const Color onBgDim = Color(0xFF94A3B8);

  /// 描边（板岩低透明）。
  static const Color outline = Color(0x3394A3B8);

  /// 描边弱化。
  static const Color outlineVariant = Color(0x2294A3B8);

  /// 说话人调色板（品牌色系内可区分的多色）。
  static const List<Color> speakers = [
    Color(0xFF22D3EE), // 青
    Color(0xFF3B82F6), // 钴蓝
    Color(0xFFA78BFA), // 紫罗兰
    Color(0xFF34D399), // 薄荷
    Color(0xFFFBBF24), // 琥珀
    Color(0xFFF472B6), // 粉
    Color(0xFF2DD4BF), // 蓝绿
    Color(0xFF60A5FA), // 天空蓝
  ];
}

// ==================== 尺寸令牌 ====================

/// 统一圆角阶。
class AppRadius {
  AppRadius._();

  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;
}

/// 统一间距阶（基于 4）。
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

// ==================== 渐变 ====================

/// 应用渐变定义。
class AppGradients {
  AppGradients._();

  /// 麦克风按钮径向渐变（青 → 深青 → 钴）。
  static const RadialGradient micButton = RadialGradient(
    center: Alignment(-0.35, -0.4),
    radius: 0.9,
    colors: [Color(0xFF67E8F9), Color(0xFF22D3EE), Color(0xFF1D4ED8)],
    stops: [0.0, 0.55, 1.0],
  );

  /// 停止按钮径向渐变（玫红系）。
  static const RadialGradient stopButton = RadialGradient(
    center: Alignment(-0.35, -0.4),
    radius: 0.9,
    colors: [Color(0xFFFB7185), Color(0xFFF43F5E), Color(0xFF9F1239)],
    stops: [0.0, 0.55, 1.0],
  );

  /// 画布纵向渐变背景。
  static const LinearGradient background = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF070B14), Color(0xFF0A1120), Color(0xFF0F1623)],
  );

  /// 卡片顶部强调渐变（青 → 透明）。
  static const LinearGradient cardAccent = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF22D3EE), Color(0x003B82F6)],
  );

  /// 结果卡顶部细条渐变。
  static const LinearGradient hairline = LinearGradient(
    colors: [Color(0x0022D3EE), Color(0xFF22D3EE), Color(0x0022D3EE)],
  );
}

// ==================== 发光助手 ====================

/// 生成单层发光阴影列表。
List<BoxShadow> glow(
  Color color, {
  double radius = 16,
  double alpha = 0.55,
  Offset offset = Offset.zero,
}) {
  return [
    BoxShadow(
      color: color.withValues(alpha: alpha),
      blurRadius: radius,
      spreadRadius: 0,
      offset: offset,
    ),
  ];
}

// ==================== 等宽文字助手 ====================

const _monoFamily = 'monospace';
const _monoFallback = ['RobotoMono', 'SF Mono', 'Menlo', 'Courier New'];

/// 等宽文字样式工厂（用于时长 / 计时器 / 状态遥测 / 统计数字）。
TextStyle mono({
  double size = 13,
  FontWeight weight = FontWeight.w600,
  Color? color,
  double letterSpacing = 1.2,
  double height = 1.0,
}) {
  return TextStyle(
    fontFamily: _monoFamily,
    fontFamilyFallback: _monoFallback,
    fontSize: size,
    fontWeight: weight,
    color: color ?? AppColors.onBg,
    letterSpacing: letterSpacing,
    height: height,
  );
}

// ==================== ThemeData ====================

ColorScheme get _colorScheme => const ColorScheme.dark(
  brightness: Brightness.dark,
  primary: AppColors.primary,
  onPrimary: Color(0xFF04141A),
  primaryContainer: Color(0xFF0E3A44),
  onPrimaryContainer: AppColors.primary,
  secondary: AppColors.secondary,
  onSecondary: Colors.white,
  secondaryContainer: Color(0xFF1E2A52),
  onSecondaryContainer: AppColors.secondary,
  tertiary: AppColors.success,
  onTertiary: Color(0xFF04231A),
  error: AppColors.error,
  onError: Colors.white,
  errorContainer: Color(0xFF4A1224),
  onErrorContainer: Color(0xFFFECDD3),
  surface: AppColors.surface,
  onSurface: AppColors.onBg,
  surfaceContainerLowest: AppColors.bg,
  surfaceContainerLow: Color(0xFF0B1320),
  surfaceContainer: AppColors.surface,
  surfaceContainerHigh: AppColors.surfaceHigh,
  surfaceContainerHighest: AppColors.surfaceHighest,
  onSurfaceVariant: AppColors.onBgDim,
  outline: AppColors.outline,
  outlineVariant: AppColors.outlineVariant,
  shadow: Color(0xFF000000),
  scrim: Color(0xFF000000),
  inverseSurface: AppColors.onBg,
  onInverseSurface: AppColors.bg,
  inversePrimary: AppColors.primary,
);

/// 全局深色主题（赛博青蓝，仅深色）。
final ThemeData appTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: _colorScheme,
  scaffoldBackgroundColor: AppColors.bg,
  canvasColor: AppColors.bg,
  splashFactory: InkSparkle.splashFactory,
  visualDensity: VisualDensity.standard,
  textTheme: const TextTheme(
    displayLarge: TextStyle(
      fontSize: 48,
      fontWeight: FontWeight.w700,
      color: AppColors.onBg,
      height: 1.1,
    ),
    headlineSmall: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: AppColors.onBg,
      height: 1.2,
    ),
    titleLarge: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: AppColors.onBg,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: AppColors.onBg,
    ),
    titleSmall: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: AppColors.onBg,
    ),
    bodyLarge: TextStyle(fontSize: 16, height: 1.6, color: AppColors.onBg),
    bodyMedium: TextStyle(fontSize: 14, height: 1.55, color: AppColors.onBgDim),
    bodySmall: TextStyle(fontSize: 12, color: AppColors.onBgDim),
    labelLarge: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: AppColors.onBg,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: AppColors.onBgDim,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: AppColors.onBgDim,
      letterSpacing: 0.6,
    ),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    foregroundColor: AppColors.onBg,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
    titleTextStyle: TextStyle(
      color: AppColors.onBg,
      fontSize: 20,
      fontWeight: FontWeight.w700,
    ),
    iconTheme: IconThemeData(color: AppColors.onBg, size: 22),
  ),
  cardTheme: CardThemeData(
    color: AppColors.surface,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      side: BorderSide(color: AppColors.outlineVariant),
    ),
  ),
  dividerTheme: const DividerThemeData(
    color: AppColors.outlineVariant,
    thickness: 1,
    space: 1,
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: const Color(0xFF04141A),
      disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.25),
      disabledForegroundColor: AppColors.onBgDim,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColors.primary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.primary,
      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.6)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
    ),
  ),
  iconButtonTheme: IconButtonThemeData(
    style: IconButton.styleFrom(
      foregroundColor: AppColors.onBg,
      highlightColor: AppColors.primary.withValues(alpha: 0.12),
      padding: const EdgeInsets.all(8),
      minimumSize: const Size(40, 40),
    ),
  ),
  chipTheme: ChipThemeData(
    backgroundColor: AppColors.surfaceHigh,
    selectedColor: AppColors.primary.withValues(alpha: 0.2),
    labelStyle: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: AppColors.onBg,
    ),
    side: BorderSide(color: AppColors.outlineVariant),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.sm),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
  ),
  bottomSheetTheme: BottomSheetThemeData(
    backgroundColor: AppColors.surfaceHigh.withValues(alpha: 0.96),
    surfaceTintColor: Colors.transparent,
    modalBackgroundColor: AppColors.surfaceHigh.withValues(alpha: 0.96),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    modalBarrierColor: AppColors.bg.withValues(alpha: 0.7),
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: AppColors.surfaceHigh,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
    ),
    titleTextStyle: const TextStyle(
      color: AppColors.onBg,
      fontSize: 18,
      fontWeight: FontWeight.w700,
    ),
    contentTextStyle: const TextStyle(
      color: AppColors.onBgDim,
      fontSize: 14,
      height: 1.5,
    ),
  ),
  sliderTheme: SliderThemeData(
    activeTrackColor: AppColors.primary,
    inactiveTrackColor: AppColors.primary.withValues(alpha: 0.18),
    thumbColor: AppColors.primary,
    overlayColor: AppColors.primary.withValues(alpha: 0.18),
    valueIndicatorColor: AppColors.primary,
    trackHeight: 4,
    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
    overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
  ),
  progressIndicatorTheme: ProgressIndicatorThemeData(
    color: AppColors.primary,
    linearTrackColor: AppColors.primary.withValues(alpha: 0.15),
    circularTrackColor: AppColors.primary.withValues(alpha: 0.15),
    linearMinHeight: 4,
  ),
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    backgroundColor: AppColors.surfaceHigh,
    contentTextStyle: const TextStyle(color: AppColors.onBg, fontSize: 13),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
    ),
    elevation: 0,
  ),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: AppColors.primary,
    foregroundColor: const Color(0xFF04141A),
    elevation: 0,
    highlightElevation: 0,
    shape: const CircleBorder(),
  ),
);
