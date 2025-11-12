import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class AppTheme {
  // Primary Colors
  static const Color primary = Color(0xFF2563EB); // Blue
  static const Color primaryLight = Color(0xFF60A5FA);
  static const Color primaryDark = Color(0xFF1E40AF);
  
  // Secondary Colors
  static const Color secondary = Color(0xFF8B5CF6); // Purple
  static const Color secondaryLight = Color(0xFFA78BFA);
  static const Color secondaryDark = Color(0xFF6D28D9);
  
  // Background Colors (Light)
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFF1F5F9);

  // Background Colors (Dark)
  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color surfaceLightDark = Color(0xFF334155);

  // Text Colors (Light)
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textTertiary = Color(0xFF94A3B8);

  // Text Colors (Dark)
  static const Color textPrimaryDark = Color(0xFFF1F5F9);
  static const Color textSecondaryDark = Color(0xFFCBD5E1);
  static const Color textTertiaryDark = Color(0xFF94A3B8);
  
  // Message Colors (Light)
  static const Color userMessageBg = Color(0xFF2563EB);
  static const Color assistantMessageBg = Color(0xFFF1F5F9);

  // Message Colors (Dark)
  static const Color userMessageBgDark = Color(0xFF3B82F6);
  static const Color assistantMessageBgDark = Color(0xFF334155);
  
  // Content Type Colors
  static const Color codeColor = Color(0xFF059669); // Green
  static const Color todoColor = Color(0xFFEA580C); // Orange
  static const Color toolCallColor = Color(0xFF7C3AED); // Purple
  static const Color thinkingColor = Color(0xFF0891B2); // Cyan
  
  // Status Colors
  static const Color activeStatus = Color(0xFF10B981);
  static const Color inactiveStatus = Color(0xFFF59E0B);
  static const Color completedStatus = Color(0xFF3B82F6);
  static const Color archivedStatus = Color(0xFF6B7280);
  
  // Gradients (Light)
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient assistantGradient = LinearGradient(
    colors: [Color(0xFFF1F5F9), Color(0xFFE2E8F0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Gradients (Dark)
  static const LinearGradient primaryGradientDark = LinearGradient(
    colors: [Color(0xFF3B82F6), Color(0xFF60A5FA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient assistantGradientDark = LinearGradient(
    colors: [Color(0xFF334155), Color(0xFF475569)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradientDark = LinearGradient(
    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Border Radius
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 20.0;

  // Spacing
  static const double spacingXSmall = 4.0;
  static const double spacingSmall = 8.0;
  static const double spacingMedium = 16.0;
  static const double spacingLarge = 24.0;
  static const double spacingXLarge = 32.0;

  // Shadows (Light)
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> elevatedShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.1),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  // Shadows (Dark)
  static List<BoxShadow> cardShadowDark = [
    BoxShadow(
      color: Colors.black.withOpacity(0.3),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> elevatedShadowDark = [
    BoxShadow(
      color: Colors.black.withOpacity(0.5),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  // Theme Data
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: primary,
    scaffoldBackgroundColor: background,
    colorScheme: const ColorScheme.light(
      primary: primary,
      secondary: secondary,
      surface: surface,
      background: background,
      error: Color(0xFFEF4444),
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: textPrimary,
      onBackground: textPrimary,
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      backgroundColor: surface,
      foregroundColor: textPrimary,
      titleTextStyle: TextStyle(
        color: textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
      ),
      color: surface,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: surfaceLight,
      labelStyle: const TextStyle(
        color: textPrimary,
        fontSize: 14,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: spacingSmall,
        vertical: spacingXSmall,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusSmall),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: spacingMedium,
        vertical: spacingMedium,
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 4,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: textPrimary,
      ),
      displayMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: textPrimary,
      ),
      displaySmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: textPrimary,
      ),
      headlineMedium: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      headlineSmall: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      titleLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: textPrimary,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        color: textPrimary,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        color: textPrimary,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        color: textSecondary,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: textPrimary,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        color: textTertiary,
      ),
    ),
  );

  // Dark Theme Data
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: primaryLight,
    scaffoldBackgroundColor: backgroundDark,
    colorScheme: const ColorScheme.dark(
      primary: primaryLight,
      secondary: secondaryLight,
      surface: surfaceDark,
      background: backgroundDark,
      error: Color(0xFFF87171),
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: textPrimaryDark,
      onBackground: textPrimaryDark,
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      backgroundColor: surfaceDark,
      foregroundColor: textPrimaryDark,
      titleTextStyle: TextStyle(
        color: textPrimaryDark,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
      ),
      color: surfaceDark,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: surfaceLightDark,
      labelStyle: const TextStyle(
        color: textPrimaryDark,
        fontSize: 14,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: spacingSmall,
        vertical: spacingXSmall,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusSmall),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceLightDark,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: const BorderSide(color: primaryLight, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: spacingMedium,
        vertical: spacingMedium,
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primaryLight,
      foregroundColor: Colors.white,
      elevation: 4,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: textPrimaryDark,
      ),
      displayMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: textPrimaryDark,
      ),
      displaySmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: textPrimaryDark,
      ),
      headlineMedium: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textPrimaryDark,
      ),
      headlineSmall: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textPrimaryDark,
      ),
      titleLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textPrimaryDark,
      ),
      titleMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: textPrimaryDark,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        color: textPrimaryDark,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        color: textPrimaryDark,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        color: textSecondaryDark,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: textPrimaryDark,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        color: textTertiaryDark,
      ),
    ),
  );

  // Cupertino Theme Data
  static CupertinoThemeData cupertinoLightTheme = const CupertinoThemeData(
    brightness: Brightness.light,
    primaryColor: primary,
    primaryContrastingColor: CupertinoColors.white,
    barBackgroundColor: surface,
    scaffoldBackgroundColor: background,
    textTheme: CupertinoTextThemeData(
      primaryColor: textPrimary,
      textStyle: TextStyle(
        inherit: false,
        fontSize: 17,
        color: textPrimary,
        fontFamily: '.SF Pro Text',
        decoration: TextDecoration.none,
      ),
      actionTextStyle: TextStyle(
        inherit: false,
        fontSize: 17,
        color: primary,
        fontFamily: '.SF Pro Text',
        decoration: TextDecoration.none,
      ),
      navTitleTextStyle: TextStyle(
        inherit: false,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        fontFamily: '.SF Pro Text',
        letterSpacing: -0.4,
        decoration: TextDecoration.none,
      ),
      navLargeTitleTextStyle: TextStyle(
        inherit: false,
        fontSize: 34,
        fontWeight: FontWeight.bold,
        color: textPrimary,
        fontFamily: '.SF Pro Display',
        letterSpacing: -0.4,
        decoration: TextDecoration.none,
      ),
    ),
  );

  static CupertinoThemeData cupertinoDarkTheme = const CupertinoThemeData(
    brightness: Brightness.dark,
    primaryColor: primaryLight,
    primaryContrastingColor: CupertinoColors.white,
    barBackgroundColor: surfaceDark,
    scaffoldBackgroundColor: backgroundDark,
    textTheme: CupertinoTextThemeData(
      primaryColor: textPrimaryDark,
      textStyle: TextStyle(
        inherit: false,
        fontSize: 17,
        color: textPrimaryDark,
        fontFamily: '.SF Pro Text',
        decoration: TextDecoration.none,
      ),
      actionTextStyle: TextStyle(
        inherit: false,
        fontSize: 17,
        color: primaryLight,
        fontFamily: '.SF Pro Text',
        decoration: TextDecoration.none,
      ),
      navTitleTextStyle: TextStyle(
        inherit: false,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: textPrimaryDark,
        fontFamily: '.SF Pro Text',
        letterSpacing: -0.4,
        decoration: TextDecoration.none,
      ),
      navLargeTitleTextStyle: TextStyle(
        inherit: false,
        fontSize: 34,
        fontWeight: FontWeight.bold,
        color: textPrimaryDark,
        fontFamily: '.SF Pro Display',
        letterSpacing: -0.4,
        decoration: TextDecoration.none,
      ),
    ),
  );

  // Helper methods for status colors
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return activeStatus;
      case 'inactive':
        return inactiveStatus;
      case 'completed':
        return completedStatus;
      case 'archived':
        return archivedStatus;
      default:
        return textSecondary;
    }
  }

  static Color getContentTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'code':
        return codeColor;
      case 'todo':
        return todoColor;
      case 'tool':
      case 'tool_call':
        return toolCallColor;
      case 'thinking':
        return thinkingColor;
      default:
        return textSecondary;
    }
  }
}

