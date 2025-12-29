import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../utils/theme.dart';

class ThinkingBox extends StatefulWidget {
  final String content;

  const ThinkingBox({
    super.key,
    required this.content,
  });

  @override
  State<ThinkingBox> createState() => _ThinkingBoxState();
}

class _ThinkingBoxState extends State<ThinkingBox> {
  bool _isExpanded = false;

  int _getLineCount() {
    return '\n'.allMatches(widget.content).length + 1;
  }

  String _getPreview() {
    final lines = widget.content.split('\n');
    if (lines.length <= 2) {
      return widget.content;
    }
    return lines.take(2).join('\n') + '...';
  }

  String _formatLength(String content) {
    final lines = _getLineCount();
    final chars = content.length;
    
    if (chars < 1000) {
      return '$lines lines, ~$chars chars';
    } else {
      return '$lines lines, ~${(chars / 1000).toStringAsFixed(1)}k chars';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(
        left: AppTheme.spacingMedium,
        right: AppTheme.spacingMedium,
        bottom: AppTheme.spacingSmall,
      ),
      decoration: BoxDecoration(
        color: AppTheme.thinkingColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: AppTheme.thinkingColor.withOpacity(0.3),
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
                      CupertinoIcons.lightbulb,
                      size: 16,
                      color: AppTheme.thinkingColor,
                    ),
                    const SizedBox(width: AppTheme.spacingXSmall),
                    Text(
                      'Reasoning',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.thinkingColor,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatLength(widget.content),
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.thinkingColor.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _isExpanded ? CupertinoIcons.chevron_up : CupertinoIcons.chevron_down,
                      size: 16,
                      color: AppTheme.thinkingColor,
                    ),
                  ],
                ),
                
                // Preview or full content
                if (!_isExpanded) ...[
                  const SizedBox(height: 4),
                  Text(
                    _getPreview(),
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                
                // Expanded content with markdown
                if (_isExpanded) ...[
                  const SizedBox(height: AppTheme.spacingSmall),
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingSmall),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    ),
                    child: MarkdownBody(
                      data: widget.content,
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textPrimary,
                          height: 1.4,
                        ),
                        code: TextStyle(
                          fontSize: 10,
                          fontFamily: 'monospace',
                          backgroundColor: Colors.black.withOpacity(0.05),
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

