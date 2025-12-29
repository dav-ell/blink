import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../models/todo_item.dart';
import '../utils/theme.dart';

class TodoItemWidget extends StatelessWidget {
  final TodoItem todo;

  const TodoItemWidget({
    super.key,
    required this.todo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingSmall),
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(
          color: _getBorderColor(),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusIcon(),
          const SizedBox(width: AppTheme.spacingMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  todo.content,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                    decoration: todo.status == TodoStatus.completed
                        ? TextDecoration.lineThrough
                        : null,
                    decorationThickness: 2,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingXSmall),
                Text(
                  _getStatusLabel(),
                  style: TextStyle(
                    fontSize: 11,
                    color: _getStatusColor(),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon() {
    IconData icon;
    Color color;

    switch (todo.status) {
      case TodoStatus.completed:
        icon = CupertinoIcons.check_mark_circled_solid;
        color = AppTheme.activeStatus;
        break;
      case TodoStatus.inProgress:
        icon = CupertinoIcons.arrow_2_circlepath;
        color = AppTheme.todoColor;
        break;
      case TodoStatus.cancelled:
        icon = CupertinoIcons.xmark_circle_fill;
        color = AppTheme.archivedStatus;
        break;
      case TodoStatus.pending:
        icon = CupertinoIcons.circle;
        color = AppTheme.textTertiary;
        break;
    }

    return Icon(
      icon,
      size: 20,
      color: color,
    );
  }

  Color _getBackgroundColor() {
    switch (todo.status) {
      case TodoStatus.completed:
        return AppTheme.activeStatus.withOpacity(0.05);
      case TodoStatus.inProgress:
        return AppTheme.todoColor.withOpacity(0.05);
      case TodoStatus.cancelled:
        return AppTheme.archivedStatus.withOpacity(0.05);
      case TodoStatus.pending:
        return AppTheme.surfaceLight;
    }
  }

  Color _getBorderColor() {
    switch (todo.status) {
      case TodoStatus.completed:
        return AppTheme.activeStatus.withOpacity(0.3);
      case TodoStatus.inProgress:
        return AppTheme.todoColor.withOpacity(0.3);
      case TodoStatus.cancelled:
        return AppTheme.archivedStatus.withOpacity(0.3);
      case TodoStatus.pending:
        return AppTheme.textTertiary.withOpacity(0.2);
    }
  }

  Color _getStatusColor() {
    switch (todo.status) {
      case TodoStatus.completed:
        return AppTheme.activeStatus;
      case TodoStatus.inProgress:
        return AppTheme.todoColor;
      case TodoStatus.cancelled:
        return AppTheme.archivedStatus;
      case TodoStatus.pending:
        return AppTheme.textTertiary;
    }
  }

  String _getStatusLabel() {
    switch (todo.status) {
      case TodoStatus.completed:
        return 'COMPLETED';
      case TodoStatus.inProgress:
        return 'IN PROGRESS';
      case TodoStatus.cancelled:
        return 'CANCELLED';
      case TodoStatus.pending:
        return 'PENDING';
    }
  }
}

