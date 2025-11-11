import 'message.dart';

enum ChatStatus {
  active,
  inactive,
  completed,
}

class Chat {
  final String id;
  final String title;
  final ChatStatus status;
  final DateTime createdAt;
  final DateTime lastMessageAt;
  final List<Message> messages;

  Chat({
    required this.id,
    required this.title,
    required this.status,
    required this.createdAt,
    required this.lastMessageAt,
    required this.messages,
  });

  String get preview {
    if (messages.isEmpty) return 'No messages yet';
    return messages.last.content;
  }

  int get messageCount => messages.length;

  // TODO: Add fromJson factory for backend integration
  // factory Chat.fromJson(Map<String, dynamic> json) {
  //   return Chat(
  //     id: json['id'],
  //     title: json['title'],
  //     status: ChatStatus.values.firstWhere((e) => e.name == json['status']),
  //     createdAt: DateTime.parse(json['createdAt']),
  //     lastMessageAt: DateTime.parse(json['lastMessageAt']),
  //     messages: (json['messages'] as List)
  //         .map((m) => Message.fromJson(m))
  //         .toList(),
  //   );
  // }

  // TODO: Add toJson method for backend integration
  // Map<String, dynamic> toJson() {
  //   return {
  //     'id': id,
  //     'title': title,
  //     'status': status.name,
  //     'createdAt': createdAt.toIso8601String(),
  //     'lastMessageAt': lastMessageAt.toIso8601String(),
  //     'messages': messages.map((m) => m.toJson()).toList(),
  //   };
  // }
}
