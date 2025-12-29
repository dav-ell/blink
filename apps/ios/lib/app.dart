/// App-wide configuration constants
class AppConfig {
  // Server connection
  static const int defaultServerPort = 8080;
  static const Duration connectionTimeout = Duration(seconds: 10);
  static const Duration reconnectDelay = Duration(seconds: 2);
  
  // Discovery
  static const Duration discoveryTimeout = Duration(seconds: 10);
  static const String mdnsServiceType = '_blink._tcp';
  
  // UI
  static const Duration uiAutoHideDelay = Duration(seconds: 3);
  static const int maxRecentServers = 10;
  
  // Performance
  static const int maxConcurrentWindows = 4;
  static const int inputEventThrottleMs = 16; // ~60fps
}

