import 'package:flutter/material.dart';

/// 动画工具类 —— 提供 iOS 风格的动效
class AppAnimations {
  AppAnimations._();

  /// iOS 风格弹簧曲线
  static const Curve springCurve = Curves.elasticOut;

  /// 快速回弹曲线
  static const Curve bouncyCurve = Curves.easeOutBack;

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
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: duration ?? _staggeredDuration(index),
      curve: curve ?? Curves.easeOutCubic,
      builder: (context, value, _) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: _getOffset(direction, 1.0 - value),
            child: child,
          ),
        );
      },
    );
  }

  /// 缩放淡入动画
  static Widget scaleFadeIn(
    Widget child, {
    int index = 0,
    Duration? duration,
    Curve? curve,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: duration ?? _staggeredDuration(index),
      curve: curve ?? Curves.easeOutCubic,
      builder: (context, value, _) {
        return Opacity(
          opacity: value,
          child: Transform.scale(
            scale: 0.92 + 0.08 * value,
            child: child,
          ),
        );
      },
    );
  }

  /// 按压缩放效果
  static Widget pressScale({
    required Widget child,
    double scale = 0.96,
    VoidCallback? onTap,
  }) {
    return _PressScaleWidget(
      scale: scale,
      onTap: onTap,
      child: child,
    );
  }

  /// 交错动画延迟
  static Duration _staggeredDuration(int index) {
    return Duration(milliseconds: 300 + index * 50);
  }

  static Offset _getOffset(AxisDirection direction, double amount) {
    const distance = 20.0;
    final offset = distance * amount;
    switch (direction) {
      case AxisDirection.up:
        return Offset(0, offset);
      case AxisDirection.down:
        return Offset(0, -offset);
      case AxisDirection.left:
        return Offset(offset, 0);
      case AxisDirection.right:
        return Offset(-offset, 0);
    }
  }
}

/// 按压缩放组件
class _PressScaleWidget extends StatefulWidget {
  final Widget child;
  final double scale;
  final VoidCallback? onTap;

  const _PressScaleWidget({
    required this.child,
    required this.scale,
    this.onTap,
  });

  @override
  State<_PressScaleWidget> createState() => _PressScaleWidgetState();
}

class _PressScaleWidgetState extends State<_PressScaleWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppAnimations.quick,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scale).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

