import 'package:flutter/services.dart';

/// Haptic feedback utilities for consistent tactile responses
class Haptics {
  /// Light tap - for selections, toggles
  static void light() {
    HapticFeedback.lightImpact();
  }

  /// Medium tap - for confirmations, successful actions
  static void medium() {
    HapticFeedback.mediumImpact();
  }

  /// Heavy tap - for errors, warnings
  static void heavy() {
    HapticFeedback.heavyImpact();
  }

  /// Selection changed - for pickers, switches
  static void selection() {
    HapticFeedback.selectionClick();
  }

  /// Success feedback - medium impact with selection
  static void success() {
    HapticFeedback.mediumImpact();
  }

  /// Error feedback - heavy impact
  static void error() {
    HapticFeedback.heavyImpact();
  }

  /// Tap feedback - for button taps
  static void tap() {
    HapticFeedback.lightImpact();
  }

  /// Long press feedback
  static void longPress() {
    HapticFeedback.mediumImpact();
  }

  /// Connection established
  static void connected() {
    HapticFeedback.mediumImpact();
  }

  /// Server discovered
  static void discovered() {
    HapticFeedback.lightImpact();
  }

  /// Tab switch
  static void tabSwitch() {
    HapticFeedback.selectionClick();
  }

  /// Window selected
  static void windowSelected() {
    HapticFeedback.lightImpact();
  }
}

