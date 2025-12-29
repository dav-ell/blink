import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

/// Premium dark-mode-first theme for remote desktop streaming
class RemoteTheme {
  // ============================================================================
  // BACKGROUNDS - Deep, rich blacks with subtle warmth
  // ============================================================================
  static const Color background = Color(0xFF0A0A0F);
  static const Color surface = Color(0xFF12121A);
  static const Color surfaceElevated = Color(0xFF1A1A24);
  static const Color surfaceHighlight = Color(0xFF242430);

  // ============================================================================
  // ACCENT - Electric indigo with subtle purple undertones
  // ============================================================================
  static const Color accent = Color(0xFF6366F1);       // Indigo-500
  static const Color accentLight = Color(0xFF818CF8);  // Indigo-400
  static const Color accentDark = Color(0xFF4F46E5);   // Indigo-600
  static const Color accentGlow = Color(0xFF6366F1);

  // ============================================================================
  // STATUS COLORS
  // ============================================================================
  static const Color connected = Color(0xFF22C55E);    // Green-500
  static const Color connecting = Color(0xFFF59E0B);   // Amber-500
  static const Color disconnected = Color(0xFF6B7280); // Gray-500
  static const Color error = Color(0xFFEF4444);        // Red-500

  // ============================================================================
  // TEXT COLORS
  // ============================================================================
  static const Color textPrimary = Color(0xFFF9FAFB);    // Gray-50
  static const Color textSecondary = Color(0xFF9CA3AF);  // Gray-400
  static const Color textTertiary = Color(0xFF6B7280);   // Gray-500
  static const Color textMuted = Color(0xFF4B5563);      // Gray-600

  // ============================================================================
  // GLASS EFFECTS
  // ============================================================================
  static const Color glassWhite = Color(0x1AFFFFFF);     // 10% white
  static const Color glassBorder = Color(0x33FFFFFF);    // 20% white
  static const Color glassHighlight = Color(0x0DFFFFFF); // 5% white

  // ============================================================================
  // GRADIENTS
  // ============================================================================
  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [Color(0xFF12121A), Color(0xFF0A0A0F)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient glassGradient = LinearGradient(
    colors: [Color(0x1AFFFFFF), Color(0x0DFFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ============================================================================
  // SPACING
  // ============================================================================
  static const double spacingXS = 4.0;
  static const double spacingSM = 8.0;
  static const double spacingMD = 16.0;
  static const double spacingLG = 24.0;
  static const double spacingXL = 32.0;
  static const double spacing2XL = 48.0;

  // ============================================================================
  // BORDER RADIUS
  // ============================================================================
  static const double radiusSM = 8.0;
  static const double radiusMD = 12.0;
  static const double radiusLG = 16.0;
  static const double radiusXL = 20.0;
  static const double radiusFull = 999.0;

  // ============================================================================
  // ANIMATION DURATIONS
  // ============================================================================
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationNormal = Duration(milliseconds: 250);
  static const Duration durationSlow = Duration(milliseconds: 400);
  static const Duration durationPulse = Duration(milliseconds: 1500);

  // ============================================================================
  // ANIMATION CURVES
  // ============================================================================
  static const Curve curveDefault = Curves.easeOutCubic;
  static const Curve curveSpring = Curves.elasticOut;
  static const Curve curveBounce = Curves.bounceOut;
  static const Curve curveSmooth = Curves.easeInOutCubic;

  // ============================================================================
  // SHADOWS
  // ============================================================================
  static List<BoxShadow> get shadowSM => [
    BoxShadow(
      color: Colors.black.withOpacity(0.3),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get shadowMD => [
    BoxShadow(
      color: Colors.black.withOpacity(0.4),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get shadowLG => [
    BoxShadow(
      color: Colors.black.withOpacity(0.5),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> get glowAccent => [
    BoxShadow(
      color: accent.withOpacity(0.4),
      blurRadius: 20,
      spreadRadius: 0,
    ),
  ];

  // ============================================================================
  // TEXT STYLES
  // ============================================================================
  static const String fontFamily = '.SF Pro Display';

  static const TextStyle titleLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    color: textPrimary,
  );

  static const TextStyle titleMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    color: textPrimary,
  );

  static const TextStyle titleSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w400,
    color: textPrimary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: textPrimary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: textSecondary,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: textTertiary,
  );

  static const TextStyle label = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    color: textSecondary,
  );

  // ============================================================================
  // CUPERTINO THEME
  // ============================================================================
  static CupertinoThemeData get cupertinoTheme => const CupertinoThemeData(
    brightness: Brightness.dark,
    primaryColor: accent,
    primaryContrastingColor: textPrimary,
    barBackgroundColor: surface,
    scaffoldBackgroundColor: background,
    textTheme: CupertinoTextThemeData(
      primaryColor: textPrimary,
      textStyle: TextStyle(
        fontFamily: '.SF Pro Text',
        fontSize: 17,
        color: textPrimary,
      ),
      actionTextStyle: TextStyle(
        fontFamily: '.SF Pro Text',
        fontSize: 17,
        color: accent,
      ),
      navTitleTextStyle: TextStyle(
        fontFamily: '.SF Pro Text',
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        letterSpacing: -0.4,
      ),
      navLargeTitleTextStyle: TextStyle(
        fontFamily: '.SF Pro Display',
        fontSize: 34,
        fontWeight: FontWeight.bold,
        color: textPrimary,
        letterSpacing: -0.4,
      ),
    ),
  );

  // ============================================================================
  // HELPER METHODS
  // ============================================================================
  
  /// Get color for connection status
  static Color getStatusColor(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected:
        return connected;
      case ConnectionStatus.connecting:
        return connecting;
      case ConnectionStatus.disconnected:
        return disconnected;
      case ConnectionStatus.error:
        return error;
    }
  }

  /// Create a glass morphism decoration
  static BoxDecoration glassDecoration({
    double borderRadius = radiusMD,
    bool showBorder = true,
  }) {
    return BoxDecoration(
      color: glassWhite,
      borderRadius: BorderRadius.circular(borderRadius),
      border: showBorder ? Border.all(color: glassBorder, width: 1) : null,
    );
  }

  /// Create an image filter for glass effect
  static ImageFilter get glassBlur => ImageFilter.blur(sigmaX: 20, sigmaY: 20);
}

/// Connection status enum
enum ConnectionStatus {
  connected,
  connecting,
  disconnected,
  error,
}

