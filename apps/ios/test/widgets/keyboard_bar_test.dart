import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blink/widgets/input/keyboard_bar.dart';
import 'package:blink/services/input_service.dart';

// #region agent log
void _debugLog(String location, String message, Map<String, dynamic> data, String hypothesisId) {
  try {
    final logEntry = jsonEncode({
      'location': location,
      'message': message,
      'data': data,
      'hypothesisId': hypothesisId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'sessionId': 'test-session',
    });
    File('/Users/davell/Documents/github/blink/.cursor/debug.log')
        .writeAsStringSync('$logEntry\n', mode: FileMode.append, flush: true);
  } catch (_) {}
}
// #endregion

/// Mock InputService that captures all sent events for verification
class MockInputService extends ChangeNotifier implements InputService {
  final List<Map<String, dynamic>> sentEvents = [];
  bool _isConnected = true;

  @override
  bool get isConnected => _isConnected;

  void setConnected(bool value) {
    _isConnected = value;
    notifyListeners();
  }

  @override
  Future<void> connect(server) async {
    _isConnected = true;
    notifyListeners();
  }

  @override
  Future<void> disconnect() async {
    _isConnected = false;
    notifyListeners();
  }

  @override
  void sendKeyPress({required int windowId, required int keyCode, List<KeyModifier> modifiers = const []}) {
    final event = {
      'method': 'sendKeyPress',
      'windowId': windowId,
      'keyCode': keyCode,
      'modifiers': modifiers.map((m) => m.name).toList(),
    };
    sentEvents.add(event);
    // #region agent log
    _debugLog('MockInputService:sendKeyPress', 'Key press sent', event, 'test');
    // #endregion
  }

  @override
  void sendKeyDown({required int windowId, required int keyCode, List<KeyModifier> modifiers = const []}) {
    sentEvents.add({
      'method': 'sendKeyDown',
      'windowId': windowId,
      'keyCode': keyCode,
      'modifiers': modifiers.map((m) => m.name).toList(),
    });
  }

  @override
  void sendKeyUp({required int windowId, required int keyCode, List<KeyModifier> modifiers = const []}) {
    sentEvents.add({
      'method': 'sendKeyUp',
      'windowId': windowId,
      'keyCode': keyCode,
      'modifiers': modifiers.map((m) => m.name).toList(),
    });
  }

  @override
  void sendTextInput({required int windowId, required String text}) {
    final event = {
      'method': 'sendTextInput',
      'windowId': windowId,
      'text': text,
    };
    sentEvents.add(event);
    // #region agent log
    _debugLog('MockInputService:sendTextInput', 'Text input sent', event, 'test');
    // #endregion
  }

  @override
  void sendClick({required int windowId, required double x, required double y, MouseButton button = MouseButton.left}) {}
  @override
  void sendDoubleClick({required int windowId, required double x, required double y}) {}
  @override
  void sendRightClick({required int windowId, required double x, required double y}) {}
  @override
  void sendMove({required int windowId, required double x, required double y, bool isDragging = false}) {}
  @override
  void sendMouseDown({required int windowId, required double x, required double y, MouseButton button = MouseButton.left}) {}
  @override
  void sendMouseUp({required int windowId, required double x, required double y, MouseButton button = MouseButton.left}) {}
  @override
  void sendScroll({required int windowId, required double x, required double y, required double deltaX, required double deltaY}) {}

  void clear() => sentEvents.clear();
  
  List<Map<String, dynamic>> get textInputEvents => 
      sentEvents.where((e) => e['method'] == 'sendTextInput').toList();
  
  List<Map<String, dynamic>> get keyPressEvents => 
      sentEvents.where((e) => e['method'] == 'sendKeyPress').toList();
}

void main() {
  // #region agent log
  _debugLog('keyboard_bar_test.dart:main', 'Starting keyboard bar tests', {}, 'test');
  // #endregion

  group('KeyboardBar Input Handling', () {
    late MockInputService mockInputService;

    setUp(() {
      mockInputService = MockInputService();
    });

    testWidgets('Hypothesis A: Backspace detection when typing then deleting', (tester) async {
      // #region agent log
      _debugLog('test:hypothesis_a', 'Starting backspace detection test', {}, 'A');
      // #endregion

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: SizedBox(
              width: 400,
              height: 100,
              child: KeyboardBar(
                inputService: mockInputService,
                windowId: 1,
              ),
            ),
          ),
        ),
      );

      // Tap to expand the keyboard bar
      await tester.tap(find.byIcon(CupertinoIcons.keyboard));
      await tester.pumpAndSettle();

      // Find the text field
      final textField = find.byType(CupertinoTextField);
      expect(textField, findsOneWidget);

      // Type a character
      await tester.enterText(textField, 'a');
      await tester.pump();

      // #region agent log
      _debugLog('test:hypothesis_a', 'After typing "a"', {
        'sentEvents': mockInputService.sentEvents.length,
        'textInputEvents': mockInputService.textInputEvents.length,
      }, 'A');
      // #endregion

      // The character should have been sent
      final textEventsAfterTyping = mockInputService.textInputEvents.length;
      
      // Now simulate backspace by entering empty text (simulating deletion)
      mockInputService.clear();
      await tester.enterText(textField, '');
      await tester.pump();

      // #region agent log
      _debugLog('test:hypothesis_a', 'After backspace (empty text)', {
        'sentEvents': mockInputService.sentEvents.length,
        'textInputEvents': mockInputService.textInputEvents.length,
        'keyPressEvents': mockInputService.keyPressEvents.length,
      }, 'A');
      // #endregion

      // Check if backspace was sent (either as key press with code 51 or text input)
      final backspaceKeySent = mockInputService.keyPressEvents.any((e) => e['keyCode'] == 51);
      final anyEventSent = mockInputService.sentEvents.isNotEmpty;

      // #region agent log
      _debugLog('test:hypothesis_a', 'Backspace test result', {
        'backspaceKeySent': backspaceKeySent,
        'anyEventSent': anyEventSent,
        'allEvents': mockInputService.sentEvents,
      }, 'A');
      // #endregion

      // POST-FIX: Backspace should now be detected and sent
      print('Backspace test: anyEventSent=$anyEventSent, backspaceKeySent=$backspaceKeySent');
      print('Events after backspace: ${mockInputService.sentEvents}');
      
      // Verify the fix: backspace key should have been sent
      expect(backspaceKeySent, isTrue, reason: 'Backspace key (code 51) should be sent');
    });

    testWidgets('Hypothesis B: Enter/Done button submission', (tester) async {
      // #region agent log
      _debugLog('test:hypothesis_b', 'Starting enter/done test', {}, 'B');
      // #endregion

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: SizedBox(
              width: 400,
              height: 100,
              child: KeyboardBar(
                inputService: mockInputService,
                windowId: 1,
              ),
            ),
          ),
        ),
      );

      // Tap to expand
      await tester.tap(find.byIcon(CupertinoIcons.keyboard));
      await tester.pumpAndSettle();

      mockInputService.clear();

      // Find text field and submit it (simulates Done button)
      final textField = find.byType(CupertinoTextField);
      await tester.enterText(textField, 'test');
      await tester.pump();

      // #region agent log
      _debugLog('test:hypothesis_b', 'After typing "test"', {
        'eventsBeforeSubmit': mockInputService.sentEvents.length,
      }, 'B');
      // #endregion

      mockInputService.clear();

      // Simulate pressing Done/Enter on the keyboard
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      // #region agent log
      _debugLog('test:hypothesis_b', 'After Done action', {
        'sentEvents': mockInputService.sentEvents.length,
        'keyPressEvents': mockInputService.keyPressEvents.length,
        'allEvents': mockInputService.sentEvents,
      }, 'B');
      // #endregion

      // Check if enter key (code 36) was sent
      final enterKeySent = mockInputService.keyPressEvents.any((e) => e['keyCode'] == 36);
      final anyEventSent = mockInputService.sentEvents.isNotEmpty;

      print('Enter/Done test: anyEventSent=$anyEventSent, enterKeySent=$enterKeySent');
      print('Events after Done: ${mockInputService.sentEvents}');
      
      // Verify the fix: Enter key should have been sent
      expect(enterKeySent, isTrue, reason: 'Enter key (code 36) should be sent on Done');
    });

    testWidgets('Control: Normal text input works', (tester) async {
      // #region agent log
      _debugLog('test:control', 'Starting normal text input test', {}, 'control');
      // #endregion

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: SizedBox(
              width: 400,
              height: 100,
              child: KeyboardBar(
                inputService: mockInputService,
                windowId: 1,
              ),
            ),
          ),
        ),
      );

      // Tap to expand
      await tester.tap(find.byIcon(CupertinoIcons.keyboard));
      await tester.pumpAndSettle();

      mockInputService.clear();

      // Type a character
      final textField = find.byType(CupertinoTextField);
      await tester.enterText(textField, 'x');
      await tester.pump();

      // #region agent log
      _debugLog('test:control', 'After typing "x"', {
        'textInputEvents': mockInputService.textInputEvents.length,
        'events': mockInputService.textInputEvents,
      }, 'control');
      // #endregion

      // Normal text should work
      expect(mockInputService.textInputEvents.length, greaterThan(0));
      expect(mockInputService.textInputEvents.first['text'], 'x');
      print('Control test: Text input works correctly');
    });

    testWidgets('Hypothesis D: TextEditingController clear behavior', (tester) async {
      // #region agent log
      _debugLog('test:hypothesis_d', 'Starting controller clear test', {}, 'D');
      // #endregion

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: SizedBox(
              width: 400,
              height: 100,
              child: KeyboardBar(
                inputService: mockInputService,
                windowId: 1,
              ),
            ),
          ),
        ),
      );

      // Tap to expand
      await tester.tap(find.byIcon(CupertinoIcons.keyboard));
      await tester.pumpAndSettle();

      mockInputService.clear();

      final textField = find.byType(CupertinoTextField);
      
      // Type first character
      await tester.enterText(textField, 'a');
      await tester.pump();
      
      final eventsAfterA = mockInputService.sentEvents.length;
      
      // Type second character (field should have been cleared, so this should work)
      await tester.enterText(textField, 'b');
      await tester.pump();
      
      final eventsAfterB = mockInputService.sentEvents.length;

      // #region agent log
      _debugLog('test:hypothesis_d', 'Controller clear test result', {
        'eventsAfterA': eventsAfterA,
        'eventsAfterB': eventsAfterB,
        'allEvents': mockInputService.sentEvents,
      }, 'D');
      // #endregion

      print('Controller clear test: eventsAfterA=$eventsAfterA, eventsAfterB=$eventsAfterB');
      print('All events: ${mockInputService.sentEvents}');
    });
  });
}

