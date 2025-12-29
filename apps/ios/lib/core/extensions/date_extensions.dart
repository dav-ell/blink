import 'package:intl/intl.dart';

/// Extension methods for DateTime formatting
extension DateTimeExtensions on DateTime {
  /// Format as relative time (e.g., "2h ago", "Just now")
  String toRelativeTime() {
    final now = DateTime.now();
    final difference = now.difference(this);

    if (difference.inDays > 7) {
      return DateFormat('MMM d').format(this);
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
  
  /// Format as full timestamp with time (e.g., "Nov 12, 3:45 PM")
  String toFullTimestamp() {
    return DateFormat('MMM d, h:mm a').format(this);
  }
  
  /// Format as short date (e.g., "Nov 12")
  String toShortDate() {
    return DateFormat('MMM d').format(this);
  }
  
  /// Format as time only (e.g., "3:45 PM")
  String toTimeOnly() {
    return DateFormat('h:mm a').format(this);
  }
  
  /// Check if the date is today
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }
  
  /// Check if the date is yesterday
  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year && 
           month == yesterday.month && 
           day == yesterday.day;
  }
}

