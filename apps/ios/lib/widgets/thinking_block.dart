import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../utils/theme.dart';

class ThinkingBlock extends StatefulWidget {
  final String thinkingText;

  const ThinkingBlock({
    super.key,
    required this.thinkingText,
  });

  @override
  State<ThinkingBlock> createState() => _ThinkingBlockState();
}

class _ThinkingBlockState extends State<ThinkingBlock> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final shouldTruncate = widget.thinkingText.length > 200;
    final displayText = shouldTruncate && !_isExpanded
        ? '${widget.thinkingText.substring(0, 200)}...'
        : widget.thinkingText;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppTheme.spacingSmall),
      decoration: BoxDecoration(
        color: AppTheme.thinkingColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: AppTheme.thinkingColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: shouldTruncate
                ? () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  }
                : null,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingMedium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppTheme.spacingSmall),
                        decoration: BoxDecoration(
                          color: AppTheme.thinkingColor.withOpacity(0.2),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSmall),
                        ),
                        child: const Icon(
                          CupertinoIcons.lightbulb,
                          size: 16,
                          color: AppTheme.thinkingColor,
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacingSmall),
                      Text(
                        'INTERNAL REASONING',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.thinkingColor,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Spacer(),
                      if (shouldTruncate)
                        Icon(
                          _isExpanded
                              ? CupertinoIcons.chevron_up
                              : CupertinoIcons.chevron_down,
                          size: 20,
                          color: AppTheme.thinkingColor,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingMedium),
                  Text(
                    displayText,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textPrimary.withOpacity(0.8),
                      fontStyle: FontStyle.italic,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

