import 'package:flutter/services.dart';

/// Centralized haptic feedback entry points.
class Haptics {
  Haptics._();

  /// Light, subtle feedback for UI selection changes.
  static void selection() => HapticFeedback.selectionClick();

  /// Light impact for minor interactions like tile taps.
  static void light() => HapticFeedback.lightImpact();

  /// Medium impact for prominent actions like button presses.
  static void medium() => HapticFeedback.mediumImpact();

  /// Heavy impact for strong emphasis or critical confirmations.
  static void heavy() => HapticFeedback.heavyImpact();

  /// Vibration pattern for error states or warnings.
  static void error() => HapticFeedback.vibrate();

  /// Vibration pattern for warning or cautionary states.
  static void warning() => HapticFeedback.vibrate();

  /// Strong positive feedback for successful completions.
  static void success() => HapticFeedback.mediumImpact();
}
