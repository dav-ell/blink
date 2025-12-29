import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:blink/screens/connection_screen.dart';
import 'package:blink/screens/window_picker_screen.dart';
import 'package:blink/screens/remote_desktop_screen.dart';
import 'package:blink/providers/connection_provider.dart';
import 'package:blink/providers/windows_provider.dart';
import 'package:blink/providers/stream_provider.dart' show VideoStreamProvider;
import 'package:blink/providers/theme_provider.dart';
import 'package:blink/theme/remote_theme.dart';
import 'package:blink/core/service_locator.dart';

import 'test_service_locator.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Streaming Flow Integration Tests', () {
    setUp(() async {
      // Setup mock services before each test
      await setupTestServiceLocator(
        withRecentServer: true,
        withWindows: true,
      );
    });

    tearDown(() async {
      // Clean up after each test
      await resetTestServiceLocator();
    });

    testWidgets('complete streaming flow: connect -> select window -> stream',
        (WidgetTester tester) async {
      // Build the app with providers
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => getIt<ThemeProvider>()),
            ChangeNotifierProvider(create: (_) => getIt<ConnectionProvider>()),
            ChangeNotifierProvider(create: (_) => getIt<WindowsProvider>()),
            ChangeNotifierProvider(create: (_) => getIt<VideoStreamProvider>()),
          ],
          child: const TestApp(),
        ),
      );

      // Wait for the app to settle
      await tester.pumpAndSettle();

      // Verify we're on the ConnectionScreen
      expect(find.byType(ConnectionScreen), findsOneWidget);
      expect(find.text('Blink'), findsOneWidget);

      // Step 1: Find and tap the first recent server
      final recentServerFinder = find.byKey(const Key('recent_server_0'));
      
      // The recent server should be visible
      expect(recentServerFinder, findsOneWidget);

      // Tap on the recent server
      await tester.tap(recentServerFinder);
      await tester.pump();

      // Simulate successful connection (mock the server response)
      simulateSuccessfulConnection();
      await tester.pumpAndSettle();

      // Step 2: Verify we navigated to WindowPickerScreen
      expect(find.byType(WindowPickerScreen), findsOneWidget);
      expect(find.text('Select Windows'), findsOneWidget);

      // Verify windows are displayed
      final windowTileFinder = find.byKey(const Key('window_tile_0'));
      expect(windowTileFinder, findsOneWidget);

      // Step 3: Select the first window
      await tester.tap(windowTileFinder);
      await tester.pumpAndSettle();

      // Verify selection count updated
      expect(find.text('1 window selected'), findsOneWidget);

      // Step 4: Tap "Done" to start streaming
      final doneButtonFinder = find.byKey(const Key('window_picker_done_button'));
      expect(doneButtonFinder, findsOneWidget);

      await tester.tap(doneButtonFinder);
      await tester.pumpAndSettle();

      // Step 5: Verify we're on RemoteDesktopScreen with video container
      expect(find.byType(RemoteDesktopScreen), findsOneWidget);
      expect(find.byKey(const Key('video_container')), findsOneWidget);
    });

    testWidgets('shows empty state when no recent servers',
        (WidgetTester tester) async {
      // Reset and setup without recent servers
      await resetTestServiceLocator();
      await setupTestServiceLocator(
        withRecentServer: false,
        withWindows: false,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => getIt<ThemeProvider>()),
            ChangeNotifierProvider(create: (_) => getIt<ConnectionProvider>()),
            ChangeNotifierProvider(create: (_) => getIt<WindowsProvider>()),
            ChangeNotifierProvider(create: (_) => getIt<VideoStreamProvider>()),
          ],
          child: const TestApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Should show connection screen
      expect(find.byType(ConnectionScreen), findsOneWidget);

      // Recent server should not be visible
      expect(find.byKey(const Key('recent_server_0')), findsNothing);
    });

    testWidgets('can select multiple windows',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => getIt<ThemeProvider>()),
            ChangeNotifierProvider(create: (_) => getIt<ConnectionProvider>()),
            ChangeNotifierProvider(create: (_) => getIt<WindowsProvider>()),
            ChangeNotifierProvider(create: (_) => getIt<VideoStreamProvider>()),
          ],
          child: const TestApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Connect to server
      final recentServerFinder = find.byKey(const Key('recent_server_0'));
      await tester.tap(recentServerFinder);
      await tester.pump();

      simulateSuccessfulConnection();
      await tester.pumpAndSettle();

      // Verify on window picker
      expect(find.byType(WindowPickerScreen), findsOneWidget);

      // Select first window
      await tester.tap(find.byKey(const Key('window_tile_0')));
      await tester.pumpAndSettle();
      expect(find.text('1 window selected'), findsOneWidget);

      // Select second window if available
      final secondWindow = find.byKey(const Key('window_tile_1'));
      if (secondWindow.evaluate().isNotEmpty) {
        await tester.tap(secondWindow);
        await tester.pumpAndSettle();
        expect(find.text('2 windows selected'), findsOneWidget);
      }
    });

    testWidgets('Done button is disabled when no windows selected',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => getIt<ThemeProvider>()),
            ChangeNotifierProvider(create: (_) => getIt<ConnectionProvider>()),
            ChangeNotifierProvider(create: (_) => getIt<WindowsProvider>()),
            ChangeNotifierProvider(create: (_) => getIt<VideoStreamProvider>()),
          ],
          child: const TestApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Connect to server
      await tester.tap(find.byKey(const Key('recent_server_0')));
      await tester.pump();

      simulateSuccessfulConnection();
      await tester.pumpAndSettle();

      // Verify 0 windows selected
      expect(find.text('0 windows selected'), findsOneWidget);

      // Done button should be present but tapping it shouldn't navigate
      final doneButton = find.byKey(const Key('window_picker_done_button'));
      expect(doneButton, findsOneWidget);

      // Tap Done - should not navigate since no windows selected
      await tester.tap(doneButton);
      await tester.pumpAndSettle();

      // Should still be on WindowPickerScreen
      expect(find.byType(WindowPickerScreen), findsOneWidget);
    });
  });
}

/// Minimal test app wrapper
class TestApp extends StatelessWidget {
  const TestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'Blink Test',
      debugShowCheckedModeBanner: false,
      theme: RemoteTheme.cupertinoTheme,
      home: const ConnectionScreen(),
    );
  }
}

