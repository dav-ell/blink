import 'package:flutter/material.dart';
import '../models/tool_call.dart';
import '../utils/theme.dart';

class ToolCallBox extends StatefulWidget {
  final ToolCall toolCall;

  const ToolCallBox({
    super.key,
    required this.toolCall,
  });

  @override
  State<ToolCallBox> createState() => _ToolCallBoxState();
}

class _ToolCallBoxState extends State<ToolCallBox> {
  bool _isExpanded = false;

  String _getToolDisplayName() {
    // Convert snake_case to Title Case
    final name = widget.toolCall.name;
    return name
        .split('_')
        .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  String _getContentSummary() {
    if (widget.toolCall.explanation != null && widget.toolCall.explanation!.isNotEmpty) {
      return widget.toolCall.explanation!;
    }
    if (widget.toolCall.command != null && widget.toolCall.command!.isNotEmpty) {
      return widget.toolCall.command!;
    }
    
    // Try to get a summary from arguments
    if (widget.toolCall.arguments != null) {
      final args = widget.toolCall.arguments!;
      if (args['target_file'] != null) {
        return 'File: ${args['target_file']}';
      }
      if (args['pattern'] != null) {
        return 'Pattern: ${args['pattern']}';
      }
      if (args['query'] != null) {
        return 'Query: ${args['query']}';
      }
    }
    
    return 'Tool execution';
  }

  int _getApproximateSize() {
    int size = 0;
    if (widget.toolCall.explanation != null) {
      size += widget.toolCall.explanation!.length;
    }
    if (widget.toolCall.command != null) {
      size += widget.toolCall.command!.length;
    }
    if (widget.toolCall.arguments != null) {
      size += widget.toolCall.arguments.toString().length;
    }
    return size;
  }

  String _formatSize(int chars) {
    if (chars < 1000) {
      return '~$chars chars';
    } else {
      return '~${(chars / 1000).toStringAsFixed(1)}k chars';
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = _getApproximateSize();
    
    return Container(
      margin: const EdgeInsets.only(
        left: AppTheme.spacingMedium,
        right: AppTheme.spacingMedium,
        bottom: AppTheme.spacingSmall,
      ),
      decoration: BoxDecoration(
        color: AppTheme.toolCallColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: AppTheme.toolCallColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingSmall),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    Icon(
                      Icons.build_circle,
                      size: 16,
                      color: AppTheme.toolCallColor,
                    ),
                    const SizedBox(width: AppTheme.spacingXSmall),
                    Text(
                      'Tool Call',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.toolCallColor,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingXSmall),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.toolCallColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      ),
                      child: Text(
                        _getToolDisplayName(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.toolCallColor,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatSize(size),
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.toolCallColor.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 16,
                      color: AppTheme.toolCallColor,
                    ),
                  ],
                ),
                
                // Summary
                if (!_isExpanded) ...[
                  const SizedBox(height: 4),
                  Text(
                    _getContentSummary(),
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                
                // Expanded content
                if (_isExpanded) ...[
                  const SizedBox(height: AppTheme.spacingSmall),
                  if (widget.toolCall.explanation != null && widget.toolCall.explanation!.isNotEmpty) ...[
                    Text(
                      'Purpose:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.toolCall.explanation!,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingSmall),
                  ],
                  if (widget.toolCall.command != null && widget.toolCall.command!.isNotEmpty) ...[
                    Text(
                      'Command:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spacingSmall),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      ),
                      child: Text(
                        widget.toolCall.command!,
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

