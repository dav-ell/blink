import 'package:flutter_test/flutter_test.dart';
import 'package:blink/services/chat_service.dart';
import 'package:blink/models/chat_session.dart';
import 'package:blink/models/chat_message.dart';

void main() {
  group('ChatService Tests', () {
    late ChatService chatService;

    setUp(() {
      chatService = ChatService();
    });

    test('getSessions should return a list of chat sessions', () async {
      final sessions = await chatService.getSessions();

      expect(sessions, isA<List<ChatSession>>());
      expect(sessions.isNotEmpty, true);
      expect(sessions.length, greaterThan(0));
    });

    test('getSessions should return sessions with valid data', () async {
      final sessions = await chatService.getSessions();

      for (var session in sessions) {
        expect(session.id, isNotEmpty);
        expect(session.title, isNotEmpty);
        expect(session.messageCount, greaterThanOrEqualTo(0));
        expect(session.startTime, isNotNull);
        expect(session.lastActivityTime, isNotNull);
      }
    });

    test('getMessages should return a list of messages for a session', () async {
      const sessionId = '1';
      final messages = await chatService.getMessages(sessionId);

      expect(messages, isA<List<ChatMessage>>());
      expect(messages.isNotEmpty, true);
    });

    test('getMessages should return messages with correct sessionId', () async {
      const sessionId = '1';
      final messages = await chatService.getMessages(sessionId);

      for (var message in messages) {
        expect(message.sessionId, sessionId);
        expect(message.content, isNotEmpty);
        expect(message.timestamp, isNotNull);
      }
    });

    test('sendMessage should create and return a new message', () async {
      const sessionId = '1';
      const content = 'Test message';

      final message = await chatService.sendMessage(
        sessionId: sessionId,
        content: content,
      );

      expect(message, isA<ChatMessage>());
      expect(message.sessionId, sessionId);
      expect(message.content, content);
      expect(message.sender, MessageSender.user);
      expect(message.type, MessageType.text);
    });

    test('sendMessage should support different message types', () async {
      const sessionId = '1';
      const content = 'Test command';

      final message = await chatService.sendMessage(
        sessionId: sessionId,
        content: content,
        type: MessageType.command,
      );

      expect(message.type, MessageType.command);
    });

    test('createSession should create and return a new session', () async {
      const title = 'New Test Session';

      final session = await chatService.createSession(title);

      expect(session, isA<ChatSession>());
      expect(session.title, title);
      expect(session.status, ChatStatus.idle);
      expect(session.messageCount, 0);
    });

    test('deleteSession should complete without error', () async {
      const sessionId = '1';

      // Should not throw
      await chatService.deleteSession(sessionId);
    });

    test('updateSessionStatus should complete without error', () async {
      const sessionId = '1';

      // Should not throw
      await chatService.updateSessionStatus(sessionId, ChatStatus.completed);
    });
  });

  group('ChatService Singleton Tests', () {
    test('ChatService should be a singleton', () {
      final instance1 = ChatService();
      final instance2 = ChatService();

      expect(identical(instance1, instance2), true);
    });
  });
}
