import 'package:flutter/animation.dart';

/// Motion timings and curves shared across the application.
abstract final class AppMotion {
  static const Duration instant = Duration(milliseconds: 90);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration standard = Duration(milliseconds: 220);
  static const Duration emphasized = Duration(milliseconds: 320);
  static const Duration data = Duration(milliseconds: 420);

  /// Used specifically for appearance changes defined by the design system.
  static const Duration themeChange = Duration(milliseconds: 180);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve shared = Curves.easeInOutCubic;
}
