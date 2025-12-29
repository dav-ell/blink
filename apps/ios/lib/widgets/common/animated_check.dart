import 'package:flutter/material.dart';
import '../../theme/remote_theme.dart';

/// Animated checkmark that draws itself
class AnimatedCheck extends StatefulWidget {
  final bool isChecked;
  final double size;
  final Color? color;
  final Duration duration;

  const AnimatedCheck({
    super.key,
    required this.isChecked,
    this.size = 24,
    this.color,
    this.duration = RemoteTheme.durationNormal,
  });

  @override
  State<AnimatedCheck> createState() => _AnimatedCheckState();
}

class _AnimatedCheckState extends State<AnimatedCheck>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    if (widget.isChecked) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(AnimatedCheck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isChecked != oldWidget.isChecked) {
      if (widget.isChecked) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: Color.lerp(
              RemoteTheme.surfaceElevated,
              widget.color ?? RemoteTheme.accent,
              _animation.value,
            ),
            borderRadius: BorderRadius.circular(widget.size / 4),
            border: Border.all(
              color: Color.lerp(
                RemoteTheme.surfaceHighlight,
                widget.color ?? RemoteTheme.accent,
                _animation.value,
              )!,
              width: 2,
            ),
          ),
          child: _animation.value > 0.5
              ? Icon(
                  Icons.check,
                  size: widget.size * 0.6,
                  color: Colors.white.withOpacity((_animation.value - 0.5) * 2),
                )
              : null,
        );
      },
    );
  }
}

