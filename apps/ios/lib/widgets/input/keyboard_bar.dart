import 'dart:ui';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/remote_theme.dart';
import '../../services/input_service.dart';
import '../../utils/haptics.dart';

// #region agent log
void _debugLogKeyboard(String location, String message, Map<String, dynamic> data, String hypothesisId) {
  try {
    final logEntry = jsonEncode({
      'location': location,
      'message': message,
      'data': data,
      'hypothesisId': hypothesisId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'sessionId': 'debug-session',
    });
    File('/Users/davell/Documents/github/blink/.cursor/debug.log')
        .writeAsStringSync('$logEntry\n', mode: FileMode.append, flush: true);
  } catch (_) {}
}
// #endregion

/// Floating keyboard trigger and input bar
class KeyboardBar extends StatefulWidget {
  final InputService inputService;
  final int windowId;

  const KeyboardBar({
    super.key,
    required this.inputService,
    required this.windowId,
  });

  @override
  State<KeyboardBar> createState() => _KeyboardBarState();
}

class _KeyboardBarState extends State<KeyboardBar> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isExpanded = _focusNode.hasFocus;
    });
  }

  void _toggleKeyboard() {
    // #region agent log
    _debugLogKeyboard('keyboard_bar.dart:_toggleKeyboard', 'Toggle keyboard called', {
      'hasFocus': _focusNode.hasFocus,
      'isExpanded': _isExpanded,
      'windowId': widget.windowId,
    }, 'E');
    // #endregion
    
    Haptics.tap();
    if (_isExpanded) {
      // Already expanded, close it
      _focusNode.unfocus();
    } else {
      // Not expanded - first expand the bar, then request focus after rebuild
      setState(() {
        _isExpanded = true;
      });
      // Request focus in next frame after TextField is built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
        // #region agent log
        _debugLogKeyboard('keyboard_bar.dart:_toggleKeyboard:postFrame', 'Focus requested after rebuild', {
          'hasFocus': _focusNode.hasFocus,
          'isExpanded': _isExpanded,
        }, 'F');
        // #endregion
      });
    }
  }

  String _previousText = '';
  
  void _onTextChanged(String text) {
    // #region agent log
    _debugLogKeyboard('keyboard_bar.dart:_onTextChanged', 'Text changed callback', {
      'text': text,
      'textLength': text.length,
      'isEmpty': text.isEmpty,
      'previousText': _previousText,
      'previousTextLength': _previousText.length,
      'windowId': widget.windowId,
      'inputServiceConnected': widget.inputService.isConnected,
    }, 'A');
    // #endregion
    
    // FIX for Hypothesis A: Detect backspace when text gets shorter
    if (text.length < _previousText.length) {
      // #region agent log
      _debugLogKeyboard('keyboard_bar.dart:_onTextChanged:backspaceDetected', 'Backspace detected - sending key', {
        'text': text,
        'previousText': _previousText,
        'deletedCount': _previousText.length - text.length,
        'windowId': widget.windowId,
      }, 'A');
      // #endregion
      
      // Calculate how many characters were deleted (usually 1 for backspace)
      final deletedCount = _previousText.length - text.length;
      for (var i = 0; i < deletedCount; i++) {
        // Send backspace key (macOS key code 51)
        Haptics.tap();
        widget.inputService.sendKeyPress(
          windowId: widget.windowId,
          keyCode: 51, // Backspace key code on macOS
        );
      }
      _previousText = text;
      return; // Don't process as text input
    }
    
    // Detect new characters added (could be more than one if pasting)
    if (text.length > _previousText.length) {
      // Get the newly added characters
      final newChars = text.substring(_previousText.length);
      
      // #region agent log
      _debugLogKeyboard('keyboard_bar.dart:_onTextChanged:newChars', 'New characters detected', {
        'newChars': newChars,
        'text': text,
        'previousText': _previousText,
        'windowId': widget.windowId,
      }, 'D');
      // #endregion
      
      // Send each new character
      for (final char in newChars.characters) {
        widget.inputService.sendTextInput(
          windowId: widget.windowId,
          text: char,
        );
      }
    }
    
    _previousText = text;
    
    // Periodically clear the text field to prevent excessive accumulation
    // but preserve the ability to detect backspace
    if (text.length > 100) {
      _textController.clear();
      _previousText = '';
    }
  }
  
  void _onSubmitted(String value) {
    // #region agent log
    _debugLogKeyboard('keyboard_bar.dart:_onSubmitted', 'Done/Submit pressed - sending Enter', {
      'value': value,
      'windowId': widget.windowId,
    }, 'B');
    // #endregion
    
    // FIX for Hypothesis B: Send Enter key when Done is pressed
    Haptics.tap();
    widget.inputService.sendKeyPress(
      windowId: widget.windowId,
      keyCode: 36, // Return/Enter key code on macOS
    );
    
    // Keep focus so user can continue typing
    _focusNode.requestFocus();
  }

  void _sendSpecialKey(int keyCode, {List<KeyModifier> modifiers = const []}) {
    // #region agent log
    _debugLogKeyboard('keyboard_bar.dart:_sendSpecialKey', 'Special key pressed', {
      'keyCode': keyCode,
      'modifiers': modifiers.map((m) => m.name).toList(),
      'windowId': widget.windowId,
      'inputServiceConnected': widget.inputService.isConnected,
    }, 'D');
    // #endregion
    
    Haptics.tap();
    widget.inputService.sendKeyPress(
      windowId: widget.windowId,
      keyCode: keyCode,
      modifiers: modifiers,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: RemoteTheme.durationNormal,
      curve: RemoteTheme.curveDefault,
      width: _isExpanded ? 280 : 48,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(RemoteTheme.radiusFull),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: RemoteTheme.glassWhite,
              borderRadius: BorderRadius.circular(RemoteTheme.radiusFull),
              border: Border.all(
                color: _isExpanded
                    ? RemoteTheme.accent.withOpacity(0.5)
                    : RemoteTheme.glassBorder,
                width: 1,
              ),
            ),
            child: _isExpanded ? _buildExpandedBar() : _buildCollapsedButton(),
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsedButton() {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: _toggleKeyboard,
      child: const Icon(
        CupertinoIcons.keyboard,
        size: 22,
        color: RemoteTheme.textSecondary,
      ),
    );
  }

  Widget _buildExpandedBar() {
    return Row(
      children: [
        // Close button
        CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: RemoteTheme.spacingSM),
          onPressed: _toggleKeyboard,
          child: const Icon(
            CupertinoIcons.xmark,
            size: 18,
            color: RemoteTheme.textSecondary,
          ),
        ),
        
        // Text input (hidden, just to capture keyboard)
        Expanded(
          child: CupertinoTextField(
            controller: _textController,
            focusNode: _focusNode,
            placeholder: 'Type here...',
            placeholderStyle: RemoteTheme.bodySmall.copyWith(
              color: RemoteTheme.textTertiary,
            ),
            style: RemoteTheme.bodySmall,
            decoration: const BoxDecoration(),
            padding: const EdgeInsets.symmetric(horizontal: RemoteTheme.spacingSM),
            onChanged: _onTextChanged,
            onSubmitted: _onSubmitted, // FIX: Handle Done/Enter button
            autocorrect: false,
            enableSuggestions: false,
          ),
        ),
        
        // Special keys
        _SpecialKeyButton(
          label: '⌘',
          onPressed: () => _sendSpecialKey(55), // Command key
        ),
        _SpecialKeyButton(
          label: '↵',
          onPressed: () => _sendSpecialKey(36), // Return key
        ),
        _SpecialKeyButton(
          label: 'esc',
          onPressed: () => _sendSpecialKey(53), // Escape key
        ),
        
        const SizedBox(width: RemoteTheme.spacingXS),
      ],
    );
  }
}

class _SpecialKeyButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _SpecialKeyButton({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: RemoteTheme.spacingSM),
      minSize: 32,
      onPressed: onPressed,
      child: Text(
        label,
        style: RemoteTheme.caption.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

