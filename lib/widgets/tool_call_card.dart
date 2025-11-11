import 'package:flutter/material.dart';
import '../models/tool_call.dart';
import '../utils/theme.dart';

class ToolCallCard extends StatefulWidget {
  final ToolCall toolCall;

  const ToolCallCard({
    super.key,
    required this.toolCall,
  });

  @override
  State<ToolCallCard> createState() => _ToolCallCardState();
}

class _ToolCallCardState extends State<ToolCallCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final hasDetails = widget.toolCall.explanation != null ||
        widget.toolCall.command != null ||
        (widget.toolCall.arguments != null &&
            widget.toolCall.arguments!.isNotEmpty);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppTheme.spacingSmall),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.toolCallColor.withOpacity(0.1),
            AppTheme.toolCallColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: AppTheme.toolCallColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: hasDetails
                ? () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  }
                : null,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingMedium),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingSmall),
                    decoration: BoxDecoration(
                      color: AppTheme.toolCallColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    ),
                    child: const Icon(
                      Icons.build_circle,
                      size: 20,
                      color: AppTheme.toolCallColor,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingMedium),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tool Call',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.toolCallColor,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingXSmall),
                        Text(
                          widget.toolCall.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasDetails)
                    Icon(
                      _isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: AppTheme.toolCallColor,
                    ),
                ],
              ),
            ),
          ),
          if (_isExpanded && hasDetails) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacingMedium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.toolCall.explanation != null) ...[
                    Text(
                      'Purpose:',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingXSmall),
                    Text(
                      widget.toolCall.explanation!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingMedium),
                  ],
                  if (widget.toolCall.command != null) ...[
                    Text(
                      'Command:',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingXSmall),
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spacingSmall),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.05),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSmall),
                      ),
                      child: Text(
                        widget.toolCall.command!,
                        style: const TextStyle(
                          fontSize: 13,
                          fontFamily: 'monospace',
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingMedium),
                  ],
                  if (widget.toolCall.arguments != null &&
                      widget.toolCall.arguments!.isNotEmpty) ...[
                    Text(
                      'Arguments:',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingXSmall),
                    ...widget.toolCall.arguments!.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(
                            bottom: AppTheme.spacingXSmall),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${entry.key}: ',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                entry.value.toString(),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

