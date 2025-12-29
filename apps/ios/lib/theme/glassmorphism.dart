import 'dart:ui';
import 'package:flutter/material.dart';
import 'remote_theme.dart';

/// A container with frosted glass effect
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final bool showBorder;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final Color? backgroundColor;
  final double blurStrength;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = RemoteTheme.radiusMD,
    this.showBorder = true,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.backgroundColor,
    this.blurStrength = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurStrength, sigmaY: blurStrength),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: backgroundColor ?? RemoteTheme.glassWhite,
              borderRadius: BorderRadius.circular(borderRadius),
              border: showBorder
                  ? Border.all(color: RemoteTheme.glassBorder, width: 1)
                  : null,
              gradient: backgroundColor == null ? RemoteTheme.glassGradient : null,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A button with frosted glass effect
class GlassButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final bool isSelected;

  const GlassButton({
    super.key,
    required this.child,
    this.onPressed,
    this.borderRadius = RemoteTheme.radiusMD,
    this.padding = const EdgeInsets.symmetric(
      horizontal: RemoteTheme.spacingMD,
      vertical: RemoteTheme.spacingSM,
    ),
    this.isSelected = false,
  });

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton>
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
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
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
    widget.onPressed?.call();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onPressed != null ? _handleTapDown : null,
      onTapUp: widget.onPressed != null ? _handleTapUp : null,
      onTapCancel: widget.onPressed != null ? _handleTapCancel : null,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: AnimatedContainer(
              duration: RemoteTheme.durationFast,
              padding: widget.padding,
              decoration: BoxDecoration(
                color: widget.isSelected
                    ? RemoteTheme.accent.withOpacity(0.3)
                    : _isPressed
                        ? RemoteTheme.glassHighlight
                        : RemoteTheme.glassWhite,
                borderRadius: BorderRadius.circular(widget.borderRadius),
                border: Border.all(
                  color: widget.isSelected
                      ? RemoteTheme.accent.withOpacity(0.5)
                      : RemoteTheme.glassBorder,
                  width: 1,
                ),
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// A pill-shaped glass indicator (like iOS dynamic island)
class GlassPill extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;

  const GlassPill({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(
      horizontal: RemoteTheme.spacingMD,
      vertical: RemoteTheme.spacingSM,
    ),
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: RemoteTheme.radiusFull,
      padding: padding,
      backgroundColor: backgroundColor,
      child: child,
    );
  }
}

/// Animated glass card that can expand/collapse
class AnimatedGlassCard extends StatelessWidget {
  final Widget child;
  final bool isExpanded;
  final double collapsedHeight;
  final double expandedHeight;
  final Duration duration;

  const AnimatedGlassCard({
    super.key,
    required this.child,
    this.isExpanded = false,
    this.collapsedHeight = 60,
    this.expandedHeight = 200,
    this.duration = RemoteTheme.durationNormal,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: duration,
      curve: RemoteTheme.curveDefault,
      height: isExpanded ? expandedHeight : collapsedHeight,
      child: GlassContainer(
        child: child,
      ),
    );
  }
}

