import '../models/chat.dart';
import '../models/message.dart';

class ChatService {
  // Mock data storage
  final List<Chat> _mockChats = [];

  ChatService() {
    _initializeMockData();
  }

  void _initializeMockData() {
    final now = DateTime.now();

    _mockChats.addAll([
      Chat(
        id: '1',
        title: 'Build Flutter Login Screen',
        status: ChatStatus.active,
        createdAt: now.subtract(const Duration(hours: 2)),
        lastMessageAt: now.subtract(const Duration(minutes: 5)),
        messages: [
          Message(
            id: 'm1',
            content: 'Create a login screen with email and password fields',
            role: MessageRole.user,
            timestamp: now.subtract(const Duration(hours: 2)),
          ),
          Message(
            id: 'm2',
            content: 'I\'ll create a login screen with email and password fields, including validation and a modern UI design.',
            role: MessageRole.assistant,
            timestamp: now.subtract(const Duration(hours: 2, minutes: -1)),
          ),
          Message(
            id: 'm3',
            content: 'Add password visibility toggle',
            role: MessageRole.user,
            timestamp: now.subtract(const Duration(minutes: 5)),
          ),
        ],
      ),
      Chat(
        id: '2',
        title: 'Fix API Integration Bug',
        status: ChatStatus.completed,
        createdAt: now.subtract(const Duration(days: 1)),
        lastMessageAt: now.subtract(const Duration(hours: 3)),
        messages: [
          Message(
            id: 'm4',
            content: 'The API calls are timing out. Can you investigate?',
            role: MessageRole.user,
            timestamp: now.subtract(const Duration(days: 1)),
          ),
          Message(
            id: 'm5',
            content: 'I\'ll check the network configuration and timeout settings.',
            role: MessageRole.assistant,
            timestamp: now.subtract(const Duration(days: 1, minutes: -2)),
          ),
          Message(
            id: 'm6',
            content: 'Found the issue - the timeout was set to 5 seconds. I\'ve increased it to 30 seconds.',
            role: MessageRole.assistant,
            timestamp: now.subtract(const Duration(hours: 3)),
          ),
        ],
      ),
      Chat(
        id: '3',
        title: 'Implement Dark Mode',
        status: ChatStatus.inactive,
        createdAt: now.subtract(const Duration(days: 3)),
        lastMessageAt: now.subtract(const Duration(days: 2)),
        messages: [
          Message(
            id: 'm7',
            content: 'Add dark mode support to the app',
            role: MessageRole.user,
            timestamp: now.subtract(const Duration(days: 3)),
          ),
          Message(
            id: 'm8',
            content: 'I\'ll implement dark mode using ThemeData and a theme switcher.',
            role: MessageRole.assistant,
            timestamp: now.subtract(const Duration(days: 3, minutes: -1)),
          ),
        ],
      ),
    ]);
  }

  // TODO: Replace with actual API call to fetch all chats
  // Future<List<Chat>> fetchChats() async {
  //   final response = await http.get(Uri.parse('$baseUrl/chats'));
  //   if (response.statusCode == 200) {
  //     final List<dynamic> data = json.decode(response.body);
  //     return data.map((json) => Chat.fromJson(json)).toList();
  //   } else {
  //     throw Exception('Failed to load chats');
  //   }
  // }
  Future<List<Chat>> fetchChats() async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));
    return List.from(_mockChats)
      ..sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
  }

  // TODO: Replace with actual API call to fetch a specific chat
  // Future<Chat> fetchChat(String chatId) async {
  //   final response = await http.get(Uri.parse('$baseUrl/chats/$chatId'));
  //   if (response.statusCode == 200) {
  //     return Chat.fromJson(json.decode(response.body));
  //   } else {
  //     throw Exception('Failed to load chat');
  //   }
  // }
  Future<Chat> fetchChat(String chatId) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 300));
    return _mockChats.firstWhere((chat) => chat.id == chatId);
  }

  // TODO: Replace with actual API call to send a message
  // Future<Message> sendMessage(String chatId, String content) async {
  //   final response = await http.post(
  //     Uri.parse('$baseUrl/chats/$chatId/messages'),
  //     headers: {'Content-Type': 'application/json'},
  //     body: json.encode({'content': content}),
  //   );
  //   if (response.statusCode == 201) {
  //     return Message.fromJson(json.decode(response.body));
  //   } else {
  //     throw Exception('Failed to send message');
  //   }
  // }
  Future<Message> sendMessage(String chatId, String content) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    final chat = _mockChats.firstWhere((c) => c.id == chatId);
    final newMessage = Message(
      id: 'm${DateTime.now().millisecondsSinceEpoch}',
      content: content,
      role: MessageRole.user,
      timestamp: DateTime.now(),
    );

    chat.messages.add(newMessage);
    return newMessage;
  }

  // TODO: Replace with actual API call to create a new chat
  // Future<Chat> createChat(String title, String initialMessage) async {
  //   final response = await http.post(
  //     Uri.parse('$baseUrl/chats'),
  //     headers: {'Content-Type': 'application/json'},
  //     body: json.encode({
  //       'title': title,
  //       'initialMessage': initialMessage,
  //     }),
  //   );
  //   if (response.statusCode == 201) {
  //     return Chat.fromJson(json.decode(response.body));
  //   } else {
  //     throw Exception('Failed to create chat');
  //   }
  // }
  Future<Chat> createChat(String title, String initialMessage) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    final now = DateTime.now();
    final newChat = Chat(
      id: '${_mockChats.length + 1}',
      title: title,
      status: ChatStatus.active,
      createdAt: now,
      lastMessageAt: now,
      messages: [
        Message(
          id: 'm${now.millisecondsSinceEpoch}',
          content: initialMessage,
          role: MessageRole.user,
          timestamp: now,
        ),
      ],
    );

    _mockChats.add(newChat);
    return newChat;
  }
}
