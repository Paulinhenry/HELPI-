import 'package:flutter/material.dart';

/// Helpi Design System — Animation Tokens
/// All animations should feel natural, snappy and purposeful.
class AppAnimations {
  AppAnimations._();

  // ─── Durations ─────────────────────────────────────────────────────────────
  static const Duration instant = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration normal = Duration(milliseconds: 280);
  static const Duration slow = Duration(milliseconds: 420);
  static const Duration xSlow = Duration(milliseconds: 600);
  static const Duration pulse = Duration(milliseconds: 1500);
  static const Duration radar = Duration(seconds: 2);

  // ─── Curves ───────────────────────────────────────────────────────────────
  /// For elements entering the screen (ease out = fast start, slow end)
  static const Curve enter = Curves.easeOutCubic;

  /// For elements leaving the screen (ease in = slow start, fast end)
  static const Curve exit = Curves.easeInCubic;

  /// For elements that bounce lightly (spring-like)
  static const Curve springy = Curves.elasticOut;

  /// For smooth value transitions
  static const Curve smooth = Curves.easeInOutCubic;

  /// For scale/pop effects
  static const Curve pop = Curves.easeOutBack;

  /// Decelerate — good for bottom sheets entering
  static const Curve decelerate = Curves.decelerate;

  // ─── Slide Transitions ────────────────────────────────────────────────────
  static SlideTransition slideUp(
    Widget child,
    Animation<double> animation,
  ) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: enter)),
      child: child,
    );
  }

  static SlideTransition slideDown(
    Widget child,
    Animation<double> animation,
  ) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, -1),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: enter)),
      child: child,
    );
  }

  // ─── Fade + Scale ─────────────────────────────────────────────────────────
  static Widget fadeScale(Widget child, Animation<double> animation) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: enter),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.92, end: 1.0)
            .animate(CurvedAnimation(parent: animation, curve: enter)),
        child: child,
      ),
    );
  }

  // ─── Page Transitions ─────────────────────────────────────────────────────
  static Route<T> fadeRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: normal,
      reverseTransitionDuration: fast,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: enter),
          child: child,
        );
      },
    );
  }

  static Route<T> slideUpRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: slow,
      reverseTransitionDuration: normal,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: decelerate)),
          child: FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: enter),
            child: child,
          ),
        );
      },
    );
  }
}
