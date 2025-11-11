enum TodoStatus {
  pending,
  inProgress,
  completed,
  cancelled,
}

class TodoItem {
  final String id;
  final String content;
  final TodoStatus status;

  TodoItem({
    required this.id,
    required this.content,
    required this.status,
  });

  factory TodoItem.fromJson(Map<String, dynamic> json) {
    final statusStr = json['status'] ?? 'pending';
    TodoStatus status;
    
    switch (statusStr.toLowerCase()) {
      case 'in_progress':
      case 'inprogress':
        status = TodoStatus.inProgress;
        break;
      case 'completed':
      case 'done':
        status = TodoStatus.completed;
        break;
      case 'cancelled':
      case 'canceled':
        status = TodoStatus.cancelled;
        break;
      default:
        status = TodoStatus.pending;
    }

    return TodoItem(
      id: json['id'] ?? '',
      content: json['content'] ?? json['text'] ?? '',
      status: status,
    );
  }

  Map<String, dynamic> toJson() {
    String statusStr;
    switch (status) {
      case TodoStatus.inProgress:
        statusStr = 'in_progress';
        break;
      case TodoStatus.completed:
        statusStr = 'completed';
        break;
      case TodoStatus.cancelled:
        statusStr = 'cancelled';
        break;
      default:
        statusStr = 'pending';
    }

    return {
      'id': id,
      'content': content,
      'status': statusStr,
    };
  }
}

