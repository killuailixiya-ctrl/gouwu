import 'package:flutter/material.dart';

/// iOS 风格页面路由 —— 从右滑入，可边缘滑动返回
class IosPageRoute<T> extends PageRouteBuilder<T> {
  final WidgetBuilder builder;

  IosPageRoute({required this.builder})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // 背景遮罩
            return Stack(
              children: [
                // 下层页面缩放 + 暗化
                SlideTransition(
                  position: Tween<Offset>(
                    begin: Offset.zero,
                    end: const Offset(-0.05, 0),
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: const Interval(0, 1, curve: Curves.easeOutCubic),
                    ),
                  ),
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 1, end: 0.95).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: const Interval(0, 1, curve: Curves.easeOutCubic),
                      ),
                    ),
                    child: secondaryAnimation.value == 0.0
                        ? null
                        : const SizedBox.expand(),
                  ),
                ),
                // 上层页面从右滑入
                SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(1.0, 0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
                  child: child,
                ),
              ],
            );
          },
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 350),
          opaque: false,
          barrierColor: Colors.black26,
        );

  @override
  Duration get transitionDuration => const Duration(milliseconds: 400);
}

/// 从底部弹出的 iOS 风格路由
class IosBottomSheetRoute<T> extends PageRouteBuilder<T> {
  final WidgetBuilder builder;

  IosBottomSheetRoute({required this.builder})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1.0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                ),
              ),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 350),
          opaque: false,
          barrierColor: Colors.black45,
        );
}

/// 路由辅助方法 —— 简化导航调用
class AppNavigator {
  /// iOS 风格 push
  static Future<T?> push<T>(BuildContext context, Widget page) {
    return Navigator.push<T>(
      context,
      IosPageRoute(builder: (_) => page),
    );
  }

  /// 标准 MaterialPageRoute push
  static Future<T?> pushMaterial<T>(BuildContext context, Widget page) {
    return Navigator.push<T>(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }
}