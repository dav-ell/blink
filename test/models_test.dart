import 'package:flutter_test/flutter_test.dart';
import 'package:blink/models/chat_session.dart';
import 'package:blink/models/chat_message.dart';

void main() {
  group('ChatSession Model Tests', () {
    test('ChatSession should be created with all properties', () {
      final session = ChatSession(
        id: '1',
        title: 'Test Session',
        startTime: DateTime(2024, 1, 1),
        lastActivityTime: DateTime(2024, 1, 2),
        status: ChatStatus.active,
        messageCount: 5,
      );

      expect(session.id, '1');
      expect(session.title, 'Test Session');
      expect(session.status, ChatStatus.active);
      expect(session.messageCount, 5);
    });

    test('ChatSession copyWith should update specified fields', () {
      final session = ChatSession(
        id: '1',
        title: 'Test Session',
        startTime: DateTime(2024, 1, 1),
        lastActivityTime: DateTime(2024, 1, 2),
        status: ChatStatus.active,
        messageCount: 5,
      );

      final updatedSession = session.copyWith(
        title: 'Updated Session',
        status: ChatStatus.completed,
      );

      expect(updatedSession.id, '1');
      expect(updatedSession.title, 'Updated Session');
      expect(updatedSession.status, ChatStatus.completed);
      expect(updatedSession.messageCount, 5);
    });
  });

  group('ChatMessage Model Tests', () {
    test('ChatMessage should be created with all properties', () {
      final message = ChatMessage(
        id: '1',
        sessionId: 'session1',
        content: 'Hello, world!',
        timestamp: DateTime(2024, 1, 1),
        sender: MessageSender.user,
        type: MessageType.text,
      );

      expect(message.id, '1');
      expect(message.sessionId, 'session1');
      expect(message.content, 'Hello, world!');
      expect(message.sender, MessageSender.user);
      expect(message.type, MessageType.text);
    });

    test('ChatMessage copyWith should update specified fields', () {
      final message = ChatMessage(
        id: '1',
        sessionId: 'session1',
        content: 'Hello, world!',
        timestamp: DateTime(2024, 1, 1),
        sender: MessageSender.user,
        type: MessageType.text,
      );

      final updatedMessage = message.copyWith(
        content: 'Updated content',
        type: MessageType.command,
      );

      expect(updatedMessage.id, '1');
      expect(updatedMessage.content, 'Updated content');
      expect(updatedMessage.type, MessageType.command);
      expect(updatedMessage.sender, MessageSender.user);
    });
  });

  group('Enum Tests', () {
    test('ChatStatus enum should have all expected values', () {
      expect(ChatStatus.values.length, 3);
      expect(ChatStatus.values, contains(ChatStatus.active));
      expect(ChatStatus.values, contains(ChatStatus.idle));
      expect(ChatStatus.values, contains(ChatStatus.completed));
    });

    test('MessageSender enum should have all expected values', () {
      expect(MessageSender.values.length, 3);
      expect(MessageSender.values, contains(MessageSender.user));
      expect(MessageSender.values, contains(MessageSender.cursor));
      expect(MessageSender.values, contains(MessageSender.system));
    });

    test('MessageType enum should have all expected values', () {
      expect(MessageType.values.length, 4);
      expect(MessageType.values, contains(MessageType.text));
      expect(MessageType.values, contains(MessageType.command));
      expect(MessageType.values, contains(MessageType.code));
      expect(MessageType.values, contains(MessageType.error));
    });
  });
}
