import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import '../repositories/chat_repository.dart';
import '../services/chat_service.dart';
import '../services/cursor_agent_service.dart';
import '../providers/chat_provider.dart';
import '../providers/chat_detail_provider.dart';
import '../providers/job_polling_provider.dart';
import '../providers/theme_provider.dart';
import '../core/constants.dart';

/// Global service locator instance
final getIt = GetIt.instance;

/// Setup dependency injection
/// 
/// Call this once at app startup before runApp()
Future<void> setupServiceLocator() async {
  // HTTP Client (singleton)
  getIt.registerLazySingleton<http.Client>(() => http.Client());
  
  // Services (singletons)
  getIt.registerLazySingleton<CursorAgentService>(
    () => CursorAgentService(
      baseUrl: AppConstants.apiBaseUrl,
      client: getIt<http.Client>(),
    ),
  );
  
  getIt.registerLazySingleton<ChatRepository>(
    () => ChatRepository(
      agentService: getIt<CursorAgentService>(),
    ),
  );
  
  getIt.registerLazySingleton<ChatService>(
    () => ChatService(
      repository: getIt<ChatRepository>(),
    ),
  );
  
  // Optional: CursorAPIService for direct API integration
  // Uncomment and configure when needed
  // getIt.registerLazySingleton<CursorAPIService>(
  //   () => CursorAPIService(
  //     authToken: 'your_token_here',
  //     userId: 'your_user_id_here',
  //   ),
  // );
  
  // Providers (factories - new instance each time)
  getIt.registerFactory<JobPollingProvider>(
    () => JobPollingProvider(
      repository: getIt<ChatRepository>(),
    ),
  );
  
  getIt.registerFactory<ChatProvider>(
    () => ChatProvider(
      chatService: getIt<ChatService>(),
    ),
  );
  
  getIt.registerFactory<ChatDetailProvider>(
    () => ChatDetailProvider(
      chatService: getIt<ChatService>(),
      repository: getIt<ChatRepository>(),
      jobPollingProvider: getIt<JobPollingProvider>(),
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

