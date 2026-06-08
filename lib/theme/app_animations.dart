import 'package:flutter/material.dart';

/// 动画工具类 —— 提供动画常量
/// （保留接口以兼容旧代码，实际不执行动画）
class AppAnimations {
  AppAnimations._();

  /// 页面切换时长
  static const Duration pageTransition = Duration(milliseconds: 400);

  /// 快速动画时长
  static const Duration quick = Duration(milliseconds: 200);

  /// 中等动画时长
  static const Duration medium = Duration(milliseconds: 350);

  /// 列表项动画时长
  static const Duration listItem = Duration(milliseconds: 300);

  /// 淡入上滑动画
  static Widget fadeSlideIn(
    Widget child, {
    int index = 0,
    Duration? duration,
    Curve? curve,
    AxisDirection direction = AxisDirection.down,
  }) {
    return child;
  }

  /// 缩放淡入动画
  static Widget scaleFadeIn(
    Widget child, {
    int index = 0,
    Duration? duration,
    Curve? curve,
  }) {
    return child;
  }

  /// 按压缩放效果
  static Widget pressScale({
    required Widget child,
    double scale = 0.96,
    VoidCallback? onTap,
  }) {
    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: child,
      );
    }
    return child;
  }
}