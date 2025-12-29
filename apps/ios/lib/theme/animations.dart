import 'package:flutter/material.dart';
import 'remote_theme.dart';

/// Standard animation curves used throughout the app
class AppAnimations {
  // ============================================================================
  // ANIMATION CURVES
  // ============================================================================
  
  /// Default easing for most transitions
  static const Curve defaultCurve = Curves.easeOutCubic;
  
  /// Spring-like curve for bouncy effects
  static const Curve springCurve = Curves.elasticOut;
  
  /// Smooth curve for subtle movements
  static const Curve smoothCurve = Curves.easeInOutCubic;
  
  /// Bounce curve for playful effects
  static const Curve bounceCurve = Curves.bounceOut;
  
  /// Decelerate curve for things coming to rest
  static const Curve decelerateCurve = Curves.decelerate;

  // ============================================================================
  // ANIMATION DURATIONS
  // ============================================================================
  
  /// Very fast - micro-interactions (50ms)
  static const Duration microDuration = Duration(milliseconds: 50);
  
  /// Fast - quick feedback (150ms)
  static const Duration fastDuration = Duration(milliseconds: 150);
  
  /// Normal - standard transitions (250ms)
  static const Duration normalDuration = Duration(milliseconds: 250);
  
  /// Slow - deliberate animations (400ms)
  static const Duration slowDuration = Duration(milliseconds: 400);
  
  /// Very slow - dramatic reveals (600ms)
  static const Duration dramaticDuration = Duration(milliseconds: 600);

  // ============================================================================
  // TWEEN FACTORIES
  // ============================================================================
  
  /// Standard fade in/out
  static Tween<double> get fadeTween => Tween<double>(begin: 0.0, end: 1.0);
  
  /// Scale from nothing to full size
  static Tween<double> get scaleUpTween => Tween<double>(begin: 0.0, end: 1.0);
  
  /// Scale down for press effect
  static Tween<double> get pressScaleTween => Tween<double>(begin: 1.0, end: 0.95);
  
  /// Slide from bottom
  static Tween<Offset> get slideUpTween => 
      Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero);
  
  /// Slide from right
  static Tween<Offset> get slideFromRightTween => 
      Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero);
  
  /// Slide from left
  static Tween<Offset> get slideFromLeftTween => 
      Tween<Offset>(begin: const Offset(-1, 0), end: Offset.zero);
}

/// A widget that fades and slides in when first built
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset slideOffset;
  final Curve curve;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = AppAnimations.normalDuration,
    this.slideOffset = const Offset(0, 0.1),
    this.curve = AppAnimations.defaultCurve,
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: widget.slideOffset,
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );

    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}

/// A widget that scales in with a spring effect
class SpringScaleIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;

  const SpringScaleIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = AppAnimations.slowDuration,
  });

  @override
  State<SpringScaleIn> createState() => _SpringScaleInState();
}

class _SpringScaleInState extends State<SpringScaleIn>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: AppAnimations.springCurve),
    );

    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: widget.child,
    );
  }
}

/// A pulsing indicator animation
class PulseAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double minScale;
  final double maxScale;

  const PulseAnimation({
    super.key,
    required this.child,
    this.duration = RemoteTheme.durationPulse,
    this.minScale = 0.95,
    this.maxScale = 1.05,
  });

  @override
  State<PulseAnimation> createState() => _PulseAnimationState();
}

class _PulseAnimationState extends State<PulseAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    )..repeat(reverse: true);
    
    _scaleAnimation = Tween<double>(
      begin: widget.minScale,
      end: widget.maxScale,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: widget.child,
    );
  }
}

/// A ripple effect at a specific point
class RippleEffect extends StatefulWidget {
  final Offset position;
  final Color color;
  final double maxRadius;
  final Duration duration;
  final VoidCallback? onComplete;

  const RippleEffect({
    super.key,
    required this.position,
    this.color = RemoteTheme.accent,
    this.maxRadius = 50,
    this.duration = AppAnimations.slowDuration,
    this.onComplete,
  });

  @override
  State<RippleEffect> createState() => _RippleEffectState();
}

class _RippleEffectState extends State<RippleEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _radiusAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    
    _radiusAnimation = Tween<double>(begin: 0, end: widget.maxRadius).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    
    _opacityAnimation = Tween<double>(begin: 0.5, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward().then((_) {
      widget.onComplete?.call();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _RipplePainter(
            center: widget.position,
            radius: _radiusAnimation.value,
            opacity: _opacityAnimation.value,
            color: widget.color,
          ),
        );
      },
    );
  }
}

class _RipplePainter extends CustomPainter {
  final Offset center;
  final double radius;
  final double opacity;
  final Color color;

  _RipplePainter({
    required this.center,
    required this.radius,
    required this.opacity,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_RipplePainter oldDelegate) {
    return oldDelegate.radius != radius || oldDelegate.opacity != opacity;
  }
}

/// Staggered animation helper for lists
class StaggeredListAnimation {
  /// Creates staggered delay for list items
  static Duration getDelay(int index, {Duration baseDelay = const Duration(milliseconds: 50)}) {
    return Duration(milliseconds: baseDelay.inMilliseconds * index);
  }
}

