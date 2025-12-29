/// Application-wide constants and configuration values
class AppConstants {
  // API Configuration
  // Use localhost for desktop, or set to your Mac's IP for mobile devices
  static const String apiBaseUrl = 'http://localhost:8067';
  static const String cursorApiBaseUrl = 'https://api2.cursor.sh';
  
  // Timeouts
  static const Duration shortTimeout = Duration(seconds: 5);
  static const Duration mediumTimeout = Duration(seconds: 10);
  static const Duration longTimeout = Duration(seconds: 15);
  static const Duration xlongTimeout = Duration(seconds: 90);
  
  // Cache Configuration
  static const Duration cacheExpiry = Duration(minutes: 5);
  
  // Polling Configuration
  static const Duration pollIntervalShort = Duration(seconds: 1);
  static const Duration pollIntervalMedium = Duration(seconds: 2);
  static const Duration pollIntervalLong = Duration(seconds: 5);
  
  // UI Configuration
  static const int maxMessagePreviewLines = 10;
  static const double maxBubbleWidthPercent = 0.80;
  static const int searchDebounceMilliseconds = 300;
  
  // Pagination
  static const int defaultPageSize = 20;
  static const int recentMessagesCount = 5;
  
  // Private constructor to prevent instantiation
  AppConstants._();
}

