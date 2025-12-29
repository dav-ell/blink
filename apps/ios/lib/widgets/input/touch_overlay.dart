import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/remote_theme.dart';
import '../../services/input_service.dart';
import '../../utils/haptics.dart';

/// Transparent overlay that captures touch gestures and translates them to input events
class TouchOverlay extends StatefulWidget {
  final Widget child;
  final InputService inputService;
  final int windowId;
  final VoidCallback? onTwoFingerSwipeLeft;
  final VoidCallback? onTwoFingerSwipeRight;
  final VoidCallback? onThreeFingerSwipeDown;

  const TouchOverlay({
    super.key,
    required this.child,
    required this.inputService,
    required this.windowId,
    this.onTwoFingerSwipeLeft,
    this.onTwoFingerSwipeRight,
    this.onThreeFingerSwipeDown,
  });

  @override
  State<TouchOverlay> createState() => _TouchOverlayState();
}

class _TouchOverlayState extends State<TouchOverlay> {
  Offset? _lastTapPosition;
  Offset? _dragStartPosition;
  bool _isDragging = false;
  Timer? _longPressTimer;
  bool _longPressTriggered = false;
  
  // For pinch zoom
  double _initialScale = 1.0;
  double _currentScale = 1.0;
  
  // For ripple effect
  final List<_RippleData> _ripples = [];

  Offset _normalizePosition(Offset localPosition, Size size) {
    return Offset(
      (localPosition.dx / size.width).clamp(0.0, 1.0),
      (localPosition.dy / size.height).clamp(0.0, 1.0),
    );
  }

  void _handleTapDown(TapDownDetails details) {
    _lastTapPosition = details.localPosition;
    _longPressTriggered = false;
    
    // Start long press timer
    _longPressTimer?.cancel();
    _longPressTimer = Timer(const Duration(milliseconds: 500), () {
      if (!_isDragging && _lastTapPosition != null) {
        _handleLongPress();
      }
    });
  }

  void _handleTapUp(TapUpDetails details) {
    _longPressTimer?.cancel();
    
    if (_longPressTriggered) return;
    
    final size = context.size ?? const Size(1, 1);
    final normalized = _normalizePosition(details.localPosition, size);
    
    Haptics.tap();
    _showRipple(details.localPosition);
    
    widget.inputService.sendClick(
      windowId: widget.windowId,
      x: normalized.dx,
      y: normalized.dy,
    );
  }

  void _handleTapCancel() {
    _longPressTimer?.cancel();
  }

  void _handleDoubleTap() {
    if (_lastTapPosition == null) return;
    
    final size = context.size ?? const Size(1, 1);
    final normalized = _normalizePosition(_lastTapPosition!, size);
    
    Haptics.medium();
    _showRipple(_lastTapPosition!);
    
    widget.inputService.sendDoubleClick(
      windowId: widget.windowId,
      x: normalized.dx,
      y: normalized.dy,
    );
  }

  void _handleLongPress() {
    _longPressTriggered = true;
    
    if (_lastTapPosition == null) return;
    
    final size = context.size ?? const Size(1, 1);
    final normalized = _normalizePosition(_lastTapPosition!, size);
    
    Haptics.longPress();
    _showRipple(_lastTapPosition!, color: RemoteTheme.accent);
    
    widget.inputService.sendRightClick(
      windowId: widget.windowId,
      x: normalized.dx,
      y: normalized.dy,
    );
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _dragStartPosition = details.localFocalPoint;
    _initialScale = _currentScale;
    _longPressTimer?.cancel();
    
    if (details.pointerCount == 1) {
      // Single finger drag start
      _isDragging = true;
      final size = context.size ?? const Size(1, 1);
      final normalized = _normalizePosition(details.localFocalPoint, size);
      
      widget.inputService.sendMouseDown(
        windowId: widget.windowId,
        x: normalized.dx,
        y: normalized.dy,
      );
    }
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    final size = context.size ?? const Size(1, 1);
    final normalized = _normalizePosition(details.localFocalPoint, size);
    
    if (details.pointerCount == 1 && _isDragging) {
      // Single finger drag
      widget.inputService.sendMove(
        windowId: widget.windowId,
        x: normalized.dx,
        y: normalized.dy,
        isDragging: true,
      );
    } else if (details.pointerCount == 2) {
      if (details.scale != 1.0) {
        // Pinch zoom - convert to scroll
        final scaleDelta = details.scale - _initialScale;
        _currentScale = _initialScale + scaleDelta;
        
        // Scroll based on scale change
        final scrollDelta = (details.scale - 1.0) * 50;
        widget.inputService.sendScroll(
          windowId: widget.windowId,
          x: normalized.dx,
          y: normalized.dy,
          deltaX: 0,
          deltaY: scrollDelta,
        );
      } else if (_dragStartPosition != null) {
        // Two-finger scroll
        final delta = details.localFocalPoint - _dragStartPosition!;
        
        widget.inputService.sendScroll(
          windowId: widget.windowId,
          x: normalized.dx,
          y: normalized.dy,
          deltaX: delta.dx * 0.5,
          deltaY: delta.dy * 0.5,
        );
        
        _dragStartPosition = details.localFocalPoint;
      }
    }
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    if (_isDragging) {
      final size = context.size ?? const Size(1, 1);
      final lastPos = _dragStartPosition ?? Offset.zero;
      final normalized = _normalizePosition(lastPos, size);
      
      widget.inputService.sendMouseUp(
        windowId: widget.windowId,
        x: normalized.dx,
        y: normalized.dy,
      );
    }
    
    // Check for swipe gestures
    if (details.velocity.pixelsPerSecond.dx.abs() > 500) {
      if (details.velocity.pixelsPerSecond.dx > 0) {
        widget.onTwoFingerSwipeRight?.call();
      } else {
        widget.onTwoFingerSwipeLeft?.call();
      }
    }
    
    _isDragging = false;
    _dragStartPosition = null;
    _initialScale = 1.0;
  }

  /// Handles two-finger tap for right-click (to be wired up to gesture detector)
  void handleTwoFingerTap() {
    if (_lastTapPosition == null) return;
    
    final size = context.size ?? const Size(1, 1);
    final normalized = _normalizePosition(_lastTapPosition!, size);
    
    Haptics.medium();
    _showRipple(_lastTapPosition!, color: RemoteTheme.accent);
    
    widget.inputService.sendRightClick(
      windowId: widget.windowId,
      x: normalized.dx,
      y: normalized.dy,
    );
  }

  void _showRipple(Offset position, {Color? color}) {
    setState(() {
      _ripples.add(_RippleData(
        position: position,
        color: color ?? RemoteTheme.textTertiary,
        createdAt: DateTime.now(),
      ));
    });
    
    // Remove ripple after animation
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() {
          _ripples.removeWhere(
            (r) => DateTime.now().difference(r.createdAt).inMilliseconds > 300,
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onDoubleTap: _handleDoubleTap,
      onScaleStart: _handleScaleStart,
      onScaleUpdate: _handleScaleUpdate,
      onScaleEnd: _handleScaleEnd,
      // Two-finger tap detection through scale gesture
      behavior: HitTestBehavior.translucent,
      child: Stack(
        children: [
          widget.child,
          
          // Ripple effects
          ..._ripples.map((ripple) => _RippleWidget(
            key: ValueKey(ripple.createdAt),
            position: ripple.position,
            color: ripple.color,
          )),
        ],
      ),
    );
  }
}

class _RippleData {
  final Offset position;
  final Color color;
  final DateTime createdAt;

  _RippleData({
    required this.position,
    required this.color,
    required this.createdAt,
  });
}

class _RippleWidget extends StatefulWidget {
  final Offset position;
  final Color color;

  const _RippleWidget({
    super.key,
    required this.position,
    required this.color,
  });

  @override
  State<_RippleWidget> createState() => _RippleWidgetState();
}

class _RippleWidgetState extends State<_RippleWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _radiusAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _radiusAnimation = Tween<double>(begin: 0, end: 40).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    
    _opacityAnimation = Tween<double>(begin: 0.5, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.position.dx - 40,
      top: widget.position.dy - 40,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            width: 80,
            height: 80,
            alignment: Alignment.center,
            child: Container(
              width: _radiusAnimation.value * 2,
              height: _radiusAnimation.value * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withOpacity(_opacityAnimation.value),
              ),
            ),
          );
        },
      ),
    );
  }
}

