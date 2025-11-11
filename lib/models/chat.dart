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
  final bool isArchived;
  final bool isDraft;
  final int totalLinesAdded;
  final int totalLinesRemoved;
  final String? subtitle;
  final String? unifiedMode;
  final double? contextUsagePercent;

  Chat({
    required this.id,
    required this.title,
    required this.status,
    required this.createdAt,
    required this.lastMessageAt,
    required this.messages,
    this.isArchived = false,
    this.isDraft = false,
    this.totalLinesAdded = 0,
    this.totalLinesRemoved = 0,
    this.subtitle,
    this.unifiedMode,
    this.contextUsagePercent,
  });

  String get preview {
    if (messages.isEmpty) return 'No messages yet';
    return messages.last.content;
  }

  int get messageCount => messages.length;

  factory Chat.fromJson(Map<String, dynamic> json) {
    // Determine status based on archived/draft flags
    ChatStatus status = ChatStatus.active;
    if (json['is_archived'] == true) {
      status = ChatStatus.inactive;
    } else if (json['is_draft'] == true) {
      status = ChatStatus.inactive;
    }

    return Chat(
      id: json['chat_id'] ?? json['id'] ?? '',
      title: json['name'] ?? json['title'] ?? 'Untitled',
      status: status,
      createdAt: json['created_at_iso'] != null
          ? DateTime.parse(json['created_at_iso'])
          : (json['created_at'] != null
              ? DateTime.fromMillisecondsSinceEpoch(json['created_at'])
              : DateTime.now()),
      lastMessageAt: json['last_updated_at_iso'] != null
          ? DateTime.parse(json['last_updated_at_iso'])
          : (json['last_updated_at'] != null
              ? DateTime.fromMillisecondsSinceEpoch(json['last_updated_at'])
              : DateTime.now()),
      messages: json['messages'] != null
          ? (json['messages'] as List).map((m) => Message.fromJson(m)).toList()
          : [],
      isArchived: json['is_archived'] ?? false,
      isDraft: json['is_draft'] ?? false,
      totalLinesAdded: json['total_lines_added'] ?? 0,
      totalLinesRemoved: json['total_lines_removed'] ?? 0,
      subtitle: json['subtitle'],
      unifiedMode: json['unified_mode'],
      contextUsagePercent: json['context_usage_percent']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'chat_id': id,
      'name': title,
      'is_archived': isArchived,
      'is_draft': isDraft,
      'created_at_iso': createdAt.toIso8601String(),
      'last_updated_at_iso': lastMessageAt.toIso8601String(),
      'total_lines_added': totalLinesAdded,
      'total_lines_removed': totalLinesRemoved,
      'subtitle': subtitle,
      'unified_mode': unifiedMode,
      'context_usage_percent': contextUsagePercent,
      'messages': messages.map((m) => m.toJson()).toList(),
    };
  }
}
