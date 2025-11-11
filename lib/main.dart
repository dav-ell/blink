import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/chat_list_screen.dart';
import 'utils/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppTheme.surface,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  
  runApp(const BlinkApp());
}

class BlinkApp extends StatelessWidget {
  const BlinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Blink - Cursor Chat Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const ChatListScreen(),
    );
  }
}
