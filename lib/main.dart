import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'screens/chat_list_screen.dart';
import 'utils/theme.dart';
import 'providers/theme_provider.dart';
import 'providers/chat_provider.dart';
import 'core/service_locator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Setup dependency injection
  await setupServiceLocator();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => getIt<ThemeProvider>()),
        ChangeNotifierProvider(create: (_) => getIt<ChatProvider>()),
      ],
      child: const BlinkApp(),
    ),
  );
}

class BlinkApp extends StatelessWidget {
  const BlinkApp({super.key});

  void _updateSystemUIOverlay(bool isDark) {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: isDark ? AppTheme.surfaceDark : AppTheme.surface,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        // Update system UI overlay based on theme
        _updateSystemUIOverlay(themeProvider.isDarkMode);

        final isDark = themeProvider.isDarkMode;

        return CupertinoApp(
          title: 'Blink',
          debugShowCheckedModeBanner: false,
          theme: isDark ? AppTheme.cupertinoDarkTheme : AppTheme.cupertinoLightTheme,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en', 'US'),
          ],
          home: const ChatListScreen(),
        );
      },
    );
  }
}
