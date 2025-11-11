import '../models/chat_session.dart';
import '../models/chat_message.dart';

/// Service for managing chat sessions and messages with Cursor IDE
/// Currently using mock data - will be replaced with real API calls
class ChatService {
  // Singleton pattern
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  /// Get all chat sessions
  /// TODO: Replace with actual API call to fetch sessions from Cursor CLI
  /// API endpoint: GET /api/sessions
  Future<List<ChatSession>> getSessions() async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    // Mock data
    final now = DateTime.now();
    return [
      ChatSession(
        id: '1',
        title: 'Implement user authentication',
        startTime: now.subtract(const Duration(hours: 2)),
        lastActivityTime: now.subtract(const Duration(minutes: 5)),
        status: ChatStatus.active,
        messageCount: 12,
      ),
      ChatSession(
        id: '2',
        title: 'Fix database migration issue',
        startTime: now.subtract(const Duration(days: 1)),
        lastActivityTime: now.subtract(const Duration(hours: 3)),
        status: ChatStatus.idle,
        messageCount: 8,
      ),
      ChatSession(
        id: '3',
        title: 'Add API endpoint for user profile',
        startTime: now.subtract(const Duration(days: 2)),
        lastActivityTime: now.subtract(const Duration(days: 2)),
        status: ChatStatus.completed,
        messageCount: 15,
      ),
      ChatSession(
        id: '4',
        title: 'Refactor payment processing',
        startTime: now.subtract(const Duration(hours: 5)),
        lastActivityTime: now.subtract(const Duration(minutes: 30)),
        status: ChatStatus.active,
        messageCount: 6,
      ),
      ChatSession(
        id: '5',
        title: 'Update dependencies to latest versions',
        startTime: now.subtract(const Duration(days: 3)),
        lastActivityTime: now.subtract(const Duration(days: 3)),
        status: ChatStatus.completed,
        messageCount: 4,
      ),
    ];
  }

  /// Get messages for a specific session
  /// TODO: Replace with actual API call to fetch messages from Cursor CLI
  /// API endpoint: GET /api/sessions/{sessionId}/messages
  Future<List<ChatMessage>> getMessages(String sessionId) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 300));

    // Mock data
    final now = DateTime.now();
    return [
      ChatMessage(
        id: '1',
        sessionId: sessionId,
        content: 'I need help implementing user authentication',
        timestamp: now.subtract(const Duration(minutes: 30)),
        sender: MessageSender.user,
        type: MessageType.text,
      ),
      ChatMessage(
        id: '2',
        sessionId: sessionId,
        content: 'I can help you with that. Let me create the authentication structure.',
        timestamp: now.subtract(const Duration(minutes: 29)),
        sender: MessageSender.cursor,
        type: MessageType.text,
      ),
      ChatMessage(
        id: '3',
        sessionId: sessionId,
        content: '''class AuthService {
  Future<User> login(String email, String password) async {
    // Implementation here
  }
}''',
        timestamp: now.subtract(const Duration(minutes: 28)),
        sender: MessageSender.cursor,
        type: MessageType.code,
      ),
      ChatMessage(
        id: '4',
        sessionId: sessionId,
        content: 'Can you add password reset functionality?',
        timestamp: now.subtract(const Duration(minutes: 15)),
        sender: MessageSender.user,
        type: MessageType.command,
      ),
      ChatMessage(
        id: '5',
        sessionId: sessionId,
        content: 'Sure, I\'ll add the password reset feature now.',
        timestamp: now.subtract(const Duration(minutes: 14)),
        sender: MessageSender.cursor,
        type: MessageType.text,
      ),
    ];
  }

  /// Send a message to a session
  /// TODO: Replace with actual API call to send message to Cursor CLI
  /// API endpoint: POST /api/sessions/{sessionId}/messages
  /// Request body: { "content": string, "type": string }
  Future<ChatMessage> sendMessage({
    required String sessionId,
    required String content,
    MessageType type = MessageType.text,
  }) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    // Mock response - create a new message
    final message = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sessionId: sessionId,
      content: content,
      timestamp: DateTime.now(),
      sender: MessageSender.user,
      type: type,
    );

    // TODO: Handle actual API response and return the created message
    return message;
  }

  /// Create a new chat session
  /// TODO: Replace with actual API call to create a new session in Cursor CLI
  /// API endpoint: POST /api/sessions
  /// Request body: { "title": string }
  Future<ChatSession> createSession(String title) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    // Mock response
    final session = ChatSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      startTime: DateTime.now(),
      lastActivityTime: DateTime.now(),
      status: ChatStatus.idle,
      messageCount: 0,
    );

    // TODO: Handle actual API response and return the created session
    return session;
  }

  /// Delete a chat session
  /// TODO: Replace with actual API call to delete session from Cursor CLI
  /// API endpoint: DELETE /api/sessions/{sessionId}
  Future<void> deleteSession(String sessionId) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 300));

    // TODO: Implement actual API call
  }

  /// Update session status
  /// TODO: Replace with actual API call to update session status
  /// API endpoint: PATCH /api/sessions/{sessionId}
  /// Request body: { "status": string }
  Future<void> updateSessionStatus(String sessionId, ChatStatus status) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 300));

    // TODO: Implement actual API call
  }
}
