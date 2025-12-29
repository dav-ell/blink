import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'screens/connection_screen.dart';
import 'theme/remote_theme.dart';
import 'providers/theme_provider.dart';
import 'providers/connection_provider.dart';
import 'providers/windows_provider.dart';
import 'providers/stream_provider.dart' show VideoStreamProvider;
import 'core/service_locator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Setup dependency injection
  await setupServiceLocator();

  // Set preferred orientations for remote desktop use
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => getIt<ThemeProvider>()),
        ChangeNotifierProvider(create: (_) => getIt<ConnectionProvider>()),
        ChangeNotifierProvider(create: (_) => getIt<WindowsProvider>()),
        ChangeNotifierProvider(create: (_) => getIt<VideoStreamProvider>()),
      ],
      child: const BlinkApp(),
    ),
  );
}

class BlinkApp extends StatelessWidget {
  const BlinkApp({super.key});

  void _updateSystemUIOverlay() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: RemoteTheme.background,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Always use dark theme for remote desktop app
    _updateSystemUIOverlay();

    return CupertinoApp(
      title: 'Blink',
      debugShowCheckedModeBanner: false,
      theme: RemoteTheme.cupertinoTheme,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', 'US'),
      ],
      home: const ConnectionScreen(),
    );
  }
}
