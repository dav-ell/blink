import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../utils/theme.dart';

/// Message input bar with text field and send button
class MessageInputBar extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final bool isSending;
  
  const MessageInputBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSend,
    this.isSending = false,
  });

  @override
  State<MessageInputBar> createState() => _MessageInputBarState();
}

class _MessageInputBarState extends State<MessageInputBar> {
  bool _hasText = false;
  
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_updateHasText);
  }
  
  @override
  void dispose() {
    widget.controller.removeListener(_updateHasText);
    super.dispose();
  }
  
  void _updateHasText() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }
  
  void _handleSend() {
    if (_hasText && !widget.isSending) {
      widget.onSend();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppTheme.surfaceDark : AppTheme.surface;
    final borderColor = (isDark ? Colors.white : Colors.black).withOpacity(0.1);
    final canSend = _hasText && !widget.isSending;

    return Container(
      padding: const EdgeInsets.only(
        left: AppTheme.spacingMedium,
        right: AppTheme.spacingMedium,
        top: AppTheme.spacingSmall,
        bottom: AppTheme.spacingSmall,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          top: BorderSide(
            color: borderColor,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(
                maxHeight: 120,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.surfaceLightDark
                    : AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              ),
              child: CupertinoTextField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                placeholder: 'Type a message...',
                placeholderStyle: TextStyle(
                  color: isDark
                      ? AppTheme.textTertiaryDark
                      : AppTheme.textTertiary,
                ),
                style: TextStyle(
                  color: isDark
                      ? AppTheme.textPrimaryDark
                      : AppTheme.textPrimary,
                  fontSize: 16,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingMedium,
                  vertical: AppTheme.spacingSmall,
                ),
                decoration: const BoxDecoration(),
                maxLines: null,
                textInputAction: TextInputAction.newline,
                enabled: !widget.isSending,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spacingSmall),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: canSend ? _handleSend : null,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: canSend
                    ? (isDark ? AppTheme.primaryLight : AppTheme.primary)
                    : (isDark
                        ? AppTheme.textTertiaryDark
                        : AppTheme.textTertiary),
                shape: BoxShape.circle,
              ),
              child: widget.isSending
                  ? const CupertinoActivityIndicator(
                      color: Colors.white,
                    )
                  : const Icon(
                      CupertinoIcons.arrow_up,
                      color: Colors.white,
                      size: 20,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

