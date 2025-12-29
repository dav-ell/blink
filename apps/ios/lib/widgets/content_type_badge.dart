import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../utils/theme.dart';

class ContentTypeBadge extends StatelessWidget {
  final String type;
  final bool small;

  const ContentTypeBadge({
    super.key,
    required this.type,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final config = _getTypeConfig(type);
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? AppTheme.spacingXSmall : AppTheme.spacingSmall,
        vertical: AppTheme.spacingXSmall,
      ),
      decoration: BoxDecoration(
        color: config.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(
          color: config.color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            config.icon,
            size: small ? 12 : 14,
            color: config.color,
          ),
          if (!small) ...[
            const SizedBox(width: AppTheme.spacingXSmall),
            Text(
              config.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: config.color,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  _BadgeConfig _getTypeConfig(String type) {
    switch (type.toLowerCase()) {
      case 'code':
        return _BadgeConfig(
          icon: CupertinoIcons.chevron_left_slash_chevron_right,
          label: 'CODE',
          color: AppTheme.codeColor,
        );
      case 'todo':
        return _BadgeConfig(
          icon: CupertinoIcons.check_mark_circled,
          label: 'TODO',
          color: AppTheme.todoColor,
        );
      case 'tool':
      case 'tool_call':
        return _BadgeConfig(
          icon: CupertinoIcons.wrench_fill,
          label: 'TOOL',
          color: AppTheme.toolCallColor,
        );
      case 'thinking':
        return _BadgeConfig(
          icon: CupertinoIcons.lightbulb,
          label: 'THINKING',
          color: AppTheme.thinkingColor,
        );
      default:
        return _BadgeConfig(
          icon: CupertinoIcons.question_circle,
          label: type.toUpperCase(),
          color: AppTheme.textSecondary,
        );
    }
  }
}

class _BadgeConfig {
  final IconData icon;
  final String label;
  final Color color;

  _BadgeConfig({
    required this.icon,
    required this.label,
    required this.color,
  });
}

