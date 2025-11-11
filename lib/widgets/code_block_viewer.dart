import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_syntax_view/flutter_syntax_view.dart';
import '../models/code_block.dart';
import '../utils/theme.dart';

class CodeBlockViewer extends StatefulWidget {
  final CodeBlock codeBlock;
  final bool isExpanded;

  const CodeBlockViewer({
    super.key,
    required this.codeBlock,
    this.isExpanded = false,
  });

  @override
  State<CodeBlockViewer> createState() => _CodeBlockViewerState();
}

class _CodeBlockViewerState extends State<CodeBlockViewer> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isExpanded;
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: widget.codeBlock.code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Code copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lines = widget.codeBlock.code.split('\n');
    final shouldTruncate = lines.length > 10;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppTheme.spacingSmall),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: AppTheme.codeColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingSmall),
            decoration: BoxDecoration(
              color: AppTheme.codeColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppTheme.radiusMedium),
                topRight: Radius.circular(AppTheme.radiusMedium),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.code,
                  size: 16,
                  color: AppTheme.codeColor,
                ),
                const SizedBox(width: AppTheme.spacingXSmall),
                Text(
                  widget.codeBlock.language.toUpperCase(),
                  style: const TextStyle(
                    color: AppTheme.codeColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (widget.codeBlock.filePath != null) ...[
                  const SizedBox(width: AppTheme.spacingSmall),
                  Expanded(
                    child: Text(
                      widget.codeBlock.filePath!,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                const Spacer(),
                if (shouldTruncate)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isExpanded = !_isExpanded;
                      });
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingSmall,
                        vertical: AppTheme.spacingXSmall,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      _isExpanded ? 'Collapse' : 'Expand',
                      style: const TextStyle(
                        color: AppTheme.codeColor,
                        fontSize: 12,
                      ),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 16),
                  color: Colors.white.withOpacity(0.7),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: _copyToClipboard,
                ),
              ],
            ),
          ),
          
          // Code content
          Container(
            constraints: BoxConstraints(
              maxHeight: shouldTruncate && !_isExpanded ? 200 : double.infinity,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacingMedium),
              child: SyntaxView(
                code: widget.codeBlock.code,
                syntax: _getSyntax(widget.codeBlock.language),
                syntaxTheme: SyntaxTheme.vscodeDark(),
                fontSize: 13.0,
                withZoom: false,
                withLinesCount: true,
                expanded: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Syntax _getSyntax(String language) {
    switch (language.toLowerCase()) {
      case 'dart':
        return Syntax.DART;
      case 'python':
      case 'py':
        return Syntax.PYTHON;
      case 'javascript':
      case 'js':
      case 'typescript':
      case 'ts':
      case 'json':
        return Syntax.JAVASCRIPT;
      case 'java':
        return Syntax.JAVA;
      case 'swift':
        return Syntax.SWIFT;
      case 'kotlin':
        return Syntax.KOTLIN;
      case 'yaml':
      case 'yml':
        return Syntax.YAML;
      default:
        return Syntax.JAVASCRIPT;
    }
  }
}

