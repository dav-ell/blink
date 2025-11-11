import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blink/main.dart';

void main() {
  testWidgets('BlinkApp should build without errors', (WidgetTester tester) async {
    // Build the app
    await tester.pumpWidget(const BlinkApp());

    // Verify that the app title is displayed
    expect(find.text('Cursor Chat Sessions'), findsOneWidget);
  });

  testWidgets('BlinkApp should use Material 3', (WidgetTester tester) async {
    // Build the app
    await tester.pumpWidget(const BlinkApp());

    // Get the MaterialApp
    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));

    // Verify Material 3 is enabled
    expect(materialApp.theme?.useMaterial3, true);
    expect(materialApp.darkTheme?.useMaterial3, true);
  });

  testWidgets('BlinkApp should have dark theme support', (WidgetTester tester) async {
    // Build the app
    await tester.pumpWidget(const BlinkApp());

    // Get the MaterialApp
    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));

    // Verify dark theme is configured
    expect(materialApp.darkTheme, isNotNull);
    expect(materialApp.themeMode, ThemeMode.system);
  });
}
