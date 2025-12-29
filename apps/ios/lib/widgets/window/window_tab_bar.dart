import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../theme/remote_theme.dart';
import '../../models/remote_window.dart';
import '../../utils/haptics.dart';

/// Frosted glass tab bar for switching between windows
class WindowTabBar extends StatelessWidget {
  final List<RemoteWindow> windows;
  final String? activeWindowId;
  final ValueChanged<String> onWindowSelected;
  final VoidCallback? onGridViewPressed;

  const WindowTabBar({
    super.key,
    required this.windows,
    required this.activeWindowId,
    required this.onWindowSelected,
    this.onGridViewPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(RemoteTheme.radiusLG),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: RemoteTheme.glassWhite,
            borderRadius: BorderRadius.circular(RemoteTheme.radiusLG),
            border: Border.all(
              color: RemoteTheme.glassBorder,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Window tabs
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: RemoteTheme.spacingXS,
                  ),
                  child: Row(
                    children: windows.map((window) {
                      final isActive = window.id.toString() == activeWindowId;
                      return _WindowTab(
                        window: window,
                        isActive: isActive,
                        onTap: () {
                          Haptics.tabSwitch();
                          onWindowSelected(window.id.toString());
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
              
              // Grid view button
              if (onGridViewPressed != null && windows.length > 1) ...[
                Container(
                  width: 1,
                  height: 24,
                  color: RemoteTheme.glassBorder,
                ),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: RemoteTheme.spacingMD,
                  ),
                  onPressed: () {
                    Haptics.tap();
                    onGridViewPressed?.call();
                  },
                  child: const Icon(
                    CupertinoIcons.square_grid_2x2,
                    size: 20,
                    color: RemoteTheme.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _WindowTab extends StatefulWidget {
  final RemoteWindow window;
  final bool isActive;
  final VoidCallback onTap;

  const _WindowTab({
    required this.window,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_WindowTab> createState() => _WindowTabState();
}

class _WindowTabState extends State<_WindowTab>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _controller.reverse();
    widget.onTap();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: AnimatedContainer(
          duration: RemoteTheme.durationFast,
          margin: const EdgeInsets.symmetric(
            horizontal: RemoteTheme.spacingXS,
            vertical: RemoteTheme.spacingXS,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: RemoteTheme.spacingMD,
            vertical: RemoteTheme.spacingSM,
          ),
          decoration: BoxDecoration(
            color: widget.isActive
                ? RemoteTheme.accent.withOpacity(0.3)
                : _isPressed
                    ? RemoteTheme.glassHighlight
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(RemoteTheme.radiusMD),
            border: widget.isActive
                ? Border.all(
                    color: RemoteTheme.accent.withOpacity(0.5),
                    width: 1,
                  )
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Active indicator
              if (widget.isActive)
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(right: RemoteTheme.spacingSM),
                  decoration: BoxDecoration(
                    color: RemoteTheme.accent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: RemoteTheme.accent.withOpacity(0.5),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              
              // Window name
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: Text(
                  widget.window.shortName,
                  style: RemoteTheme.bodySmall.copyWith(
                    color: widget.isActive
                        ? RemoteTheme.textPrimary
                        : RemoteTheme.textSecondary,
                    fontWeight: widget.isActive
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

