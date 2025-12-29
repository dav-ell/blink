import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/remote_theme.dart';
import '../../services/input_service.dart';
import '../../services/stream_service.dart';
import '../../utils/haptics.dart';

// #region agent log
void _debugLog(String location, String message, Map<String, dynamic> data, String hypothesisId) {
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

/// Transparent overlay that captures touch gestures and translates them to input events
class TouchOverlay extends StatefulWidget {
  final Widget child;
  final InputService inputService;
  final StreamService? streamService;
  final int windowId;
  final VoidCallback? onTwoFingerSwipeLeft;
  final VoidCallback? onTwoFingerSwipeRight;
  final VoidCallback? onThreeFingerSwipeDown;

  const TouchOverlay({
    super.key,
    required this.child,
    required this.inputService,
    required this.windowId,
    this.streamService,
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
  
  // For pinch zoom - actual zoom state
  double _scale = 1.0;
  double _previousScale = 1.0;
  Offset _offset = Offset.zero;
  Offset _previousOffset = Offset.zero;
  Offset _focalPoint = Offset.zero;
  
  // Viewport update debouncing
  Timer? _viewportDebouncer;
  
  // For ripple effect
  final List<_RippleData> _ripples = [];
  
  /// Calculate the current viewport based on zoom state
  /// Returns (x, y, width, height) in normalized 0.0-1.0 coordinates
  (double, double, double, double) _calculateViewport(Size size) {
    if (_scale <= 1.0) {
      return (0.0, 0.0, 1.0, 1.0);
    }
    
    // Width and height of visible area as fraction of full image
    final viewWidth = 1.0 / _scale;
    final viewHeight = 1.0 / _scale;
    
    // Calculate offset as fraction of image
    // Offset is in screen pixels, need to convert to image fraction
    final offsetX = -_offset.dx / (size.width * _scale);
    final offsetY = -_offset.dy / (size.height * _scale);
    
    // Clamp to valid range
    final x = offsetX.clamp(0.0, 1.0 - viewWidth);
    final y = offsetY.clamp(0.0, 1.0 - viewHeight);
    
    return (x, y, viewWidth, viewHeight);
  }
  
  /// Send viewport update to server (debounced)
  void _sendViewportUpdate() {
    _viewportDebouncer?.cancel();
    _viewportDebouncer = Timer(const Duration(milliseconds: 100), () {
      if (widget.streamService == null) return;
      
      final size = context.size ?? const Size(1, 1);
      final (x, y, w, h) = _calculateViewport(size);
      
      widget.streamService!.updateViewport(
        windowId: widget.windowId,
        x: x,
        y: y,
        width: w,
        height: h,
      );
    });
  }
  
  /// Reset zoom to 1:1
  void resetZoom() {
    setState(() {
      _scale = 1.0;
      _offset = Offset.zero;
    });
    _sendViewportUpdate();
  }

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
    // #region agent log
    _debugLog('touch_overlay.dart:_handleScaleStart', 'Scale gesture started', {
      'pointerCount': details.pointerCount,
      'localFocalPoint': {'dx': details.localFocalPoint.dx, 'dy': details.localFocalPoint.dy},
      'currentScale': _scale,
    }, 'A');
    // #endregion
    
    _dragStartPosition = details.localFocalPoint;
    _focalPoint = details.localFocalPoint;
    _previousScale = _scale;
    _previousOffset = _offset;
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
    // #region agent log
    _debugLog('touch_overlay.dart:_handleScaleUpdate', 'Scale gesture update', {
      'pointerCount': details.pointerCount,
      'scale': details.scale,
      'previousScale': _previousScale,
      'currentScale': _scale,
      'isDragging': _isDragging,
    }, 'B');
    // #endregion
    
    final size = context.size ?? const Size(1, 1);
    final normalized = _normalizePosition(details.localFocalPoint, size);
    
    if (details.pointerCount == 1 && _isDragging) {
      // Single finger drag - if zoomed in, pan the view; otherwise, mouse drag
      if (_scale > 1.0) {
        // Pan the zoomed view
        final delta = details.localFocalPoint - _dragStartPosition!;
        setState(() {
          _offset = _previousOffset + delta;
          _clampOffset(size);
        });
        _dragStartPosition = details.localFocalPoint;
        _previousOffset = _offset;
        _sendViewportUpdate();
      } else {
        // Normal mouse drag
        widget.inputService.sendMove(
          windowId: widget.windowId,
          x: normalized.dx,
          y: normalized.dy,
          isDragging: true,
        );
      }
    } else if (details.pointerCount == 2) {
      // Pinch zoom - actual zoom with viewport update
      final newScale = (_previousScale * details.scale).clamp(1.0, 4.0);
      
      // #region agent log
      _debugLog('touch_overlay.dart:_handleScaleUpdate:pinch', 'Pinch zoom detected', {
        'detailsScale': details.scale,
        'previousScale': _previousScale,
        'newScale': newScale,
        'currentScale': _scale,
        'focalPoint': {'dx': details.localFocalPoint.dx, 'dy': details.localFocalPoint.dy},
        'initialFocalPoint': {'dx': _focalPoint.dx, 'dy': _focalPoint.dy},
      }, 'B');
      // #endregion
      
      if ((newScale - _scale).abs() > 0.01 || details.localFocalPoint != _dragStartPosition) {
        setState(() {
          final oldScale = _scale;
          _scale = newScale;
          
          if (_scale > 1.0) {
            // Calculate offset to keep the focal point stable during zoom
            // The focal point should stay at the same screen position
            // Formula: newOffset = focalPoint - (focalPoint - oldOffset) * (newScale / oldScale)
            final scaleRatio = _scale / oldScale;
            final focalPointInContent = _focalPoint - _previousOffset;
            _offset = _focalPoint - (focalPointInContent * scaleRatio);
            
            // Also apply pan movement if fingers moved
            final panDelta = details.localFocalPoint - _dragStartPosition!;
            _offset = _offset + panDelta;
            
            _clampOffset(size);
            _dragStartPosition = details.localFocalPoint;
          } else {
            _offset = Offset.zero;
          }
        });
        
        // #region agent log
        _debugLog('touch_overlay.dart:_handleScaleUpdate:afterSetState', 'Scale updated', {
          'newScale': _scale,
          'offset': {'dx': _offset.dx, 'dy': _offset.dy},
        }, 'C');
        // #endregion
        
        _sendViewportUpdate();
      }
    }
  }
  
  void _clampOffset(Size size) {
    if (_scale <= 1.0) {
      _offset = Offset.zero;
      return;
    }
    
    // Calculate bounds for offset
    final maxOffsetX = size.width * (_scale - 1);
    final maxOffsetY = size.height * (_scale - 1);
    
    _offset = Offset(
      _offset.dx.clamp(-maxOffsetX, 0),
      _offset.dy.clamp(-maxOffsetY, 0),
    );
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    if (_isDragging && _scale <= 1.0) {
      final size = context.size ?? const Size(1, 1);
      final lastPos = _dragStartPosition ?? Offset.zero;
      final normalized = _normalizePosition(lastPos, size);
      
      widget.inputService.sendMouseUp(
        windowId: widget.windowId,
        x: normalized.dx,
        y: normalized.dy,
      );
    }
    
    // Check for swipe gestures (only when not zoomed)
    if (_scale <= 1.0 && details.velocity.pixelsPerSecond.dx.abs() > 500) {
      if (details.velocity.pixelsPerSecond.dx > 0) {
        widget.onTwoFingerSwipeRight?.call();
      } else {
        widget.onTwoFingerSwipeLeft?.call();
      }
    }
    
    _isDragging = false;
    _dragStartPosition = null;
    _previousScale = _scale;
    _previousOffset = _offset;
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
    _viewportDebouncer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onDoubleTap: _scale > 1.0 ? resetZoom : _handleDoubleTap, // Double-tap to reset zoom
      onScaleStart: _handleScaleStart,
      onScaleUpdate: _handleScaleUpdate,
      onScaleEnd: _handleScaleEnd,
      // Two-finger tap detection through scale gesture
      behavior: HitTestBehavior.translucent,
      child: Stack(
        children: [
          // Apply zoom transformation to child
          // Use alignment-based scaling for correct focal point behavior
          ClipRect(
            child: Transform(
              alignment: Alignment.topLeft,
              transform: Matrix4.identity()
                ..scale(_scale)
                ..translate(_offset.dx / _scale, _offset.dy / _scale),
              child: widget.child,
            ),
          ),
          
          // Zoom indicator when zoomed in
          if (_scale > 1.0)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${(_scale * 100).toInt()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          
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

