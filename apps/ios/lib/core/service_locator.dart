import 'package:get_it/get_it.dart';
import '../services/discovery_service.dart';
import '../services/stream_service.dart';
import '../services/input_service.dart';
import '../services/preferences_service.dart';
import '../providers/connection_provider.dart';
import '../providers/windows_provider.dart';
import '../providers/stream_provider.dart' show VideoStreamProvider;
import '../providers/theme_provider.dart';

/// Global service locator instance
final getIt = GetIt.instance;

/// Setup dependency injection
/// 
/// Call this once at app startup before runApp()
Future<void> setupServiceLocator() async {
  // Services (singletons)
  
  // Preferences Service - load first
  final preferencesService = PreferencesService();
  await preferencesService.init();
  getIt.registerSingleton<PreferencesService>(preferencesService);
  
  // Discovery Service
  getIt.registerLazySingleton<DiscoveryService>(
    () => DiscoveryService(),
  );
  
  // Stream Service
  getIt.registerLazySingleton<StreamService>(
    () => StreamService(),
  );
  
  // Input Service
  getIt.registerLazySingleton<InputService>(
    () => InputService(),
  );
  
  // Providers (singletons for state management)
  getIt.registerLazySingleton<ConnectionProvider>(
    () => ConnectionProvider(
      streamService: getIt<StreamService>(),
      inputService: getIt<InputService>(),
      discoveryService: getIt<DiscoveryService>(),
      preferencesService: getIt<PreferencesService>(),
    ),
  );
  
  getIt.registerLazySingleton<WindowsProvider>(
    () => WindowsProvider(
      streamService: getIt<StreamService>(),
    ),
  );
  
  getIt.registerLazySingleton<VideoStreamProvider>(
    () => VideoStreamProvider(
      streamService: getIt<StreamService>(),
    ),
  );
  
  getIt.registerFactory<ThemeProvider>(
    () => ThemeProvider(),
  );
}

/// Reset service locator (useful for testing)
Future<void> resetServiceLocator() async {
  await getIt.reset();
}

