import 'package:flutter/services.dart';

/// Centralized haptic feedback entry points.
class Haptics {
  Haptics._();

  static void selection() => HapticFeedback.selectionClick();

  static void light() => HapticFeedback.lightImpact();

  static void medium() => HapticFeedback.mediumImpact();

  static void error() => HapticFeedback.vibrate();
}
