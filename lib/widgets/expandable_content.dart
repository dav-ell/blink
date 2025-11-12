import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../utils/theme.dart';

class ExpandableContent extends StatefulWidget {
  final String content;
  final bool isUserMessage;
  final int maxLines;

  const ExpandableContent({
    super.key,
    required this.content,
    this.isUserMessage = false,
    this.maxLines = 10,
  });

  @override
  State<ExpandableContent> createState() => _ExpandableContentState();
}

class _ExpandableContentState extends State<ExpandableContent> {
  bool _isExpanded = false;

  int _getLineCount() {
    if (widget.content.isEmpty) return 0;
    return '\n'.allMatches(widget.content).length + 1;
  }

  bool _shouldTruncate() {
    return _getLineCount() > widget.maxLines;
  }

  String _getTruncatedContent() {
    if (!_shouldTruncate()) return widget.content;
    
    final lines = widget.content.split('\n');
    return lines.take(widget.maxLines).join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final shouldTruncate = _shouldTruncate();
    final displayContent = (!_isExpanded && shouldTruncate) 
        ? _getTruncatedContent() 
        : widget.content;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Markdown content
        MarkdownBody(
          data: displayContent,
          selectable: true,
          styleSheet: MarkdownStyleSheet(
            // Paragraph style
            p: TextStyle(
              color: widget.isUserMessage ? Colors.white : AppTheme.textPrimary,
              fontSize: 13,
              height: 1.4,
            ),
            // Headers
            h1: TextStyle(
              color: widget.isUserMessage ? Colors.white : AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
            h2: TextStyle(
              color: widget.isUserMessage ? Colors.white : AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
            h3: TextStyle(
              color: widget.isUserMessage ? Colors.white : AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
            // Code
            code: TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              backgroundColor: widget.isUserMessage 
                  ? Colors.white.withOpacity(0.2)
                  : Colors.black.withOpacity(0.05),
              color: widget.isUserMessage ? Colors.white : AppTheme.textPrimary,
            ),
            codeblockPadding: const EdgeInsets.all(AppTheme.spacingSmall),
            codeblockDecoration: BoxDecoration(
              color: widget.isUserMessage 
                  ? Colors.white.withOpacity(0.15)
                  : Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            // Lists
            listBullet: TextStyle(
              color: widget.isUserMessage ? Colors.white : AppTheme.textPrimary,
              fontSize: 13,
            ),
            // Links
            a: TextStyle(
              color: widget.isUserMessage 
                  ? Colors.white
                  : AppTheme.primary,
              decoration: TextDecoration.underline,
              fontSize: 13,
            ),
            // Blockquote
            blockquote: TextStyle(
              color: widget.isUserMessage 
                  ? Colors.white.withOpacity(0.8)
                  : AppTheme.textSecondary,
              fontSize: 13,
              fontStyle: FontStyle.italic,
            ),
            blockquoteDecoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: widget.isUserMessage 
                      ? Colors.white.withOpacity(0.5)
                      : AppTheme.textTertiary,
                  width: 3,
                ),
              ),
            ),
            blockquotePadding: const EdgeInsets.only(
              left: AppTheme.spacingSmall,
            ),
            // Emphasis
            em: TextStyle(
              color: widget.isUserMessage ? Colors.white : AppTheme.textPrimary,
              fontStyle: FontStyle.italic,
              fontSize: 13,
            ),
            strong: TextStyle(
              color: widget.isUserMessage ? Colors.white : AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
        
        // Show more/less button
        if (shouldTruncate) ...[
          const SizedBox(height: AppTheme.spacingSmall),
          GestureDetector(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isExpanded ? 'Show less' : 'Show more',
                  style: TextStyle(
                    color: widget.isUserMessage 
                        ? Colors.white.withOpacity(0.8)
                        : AppTheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: widget.isUserMessage 
                      ? Colors.white.withOpacity(0.8)
                      : AppTheme.primary,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

