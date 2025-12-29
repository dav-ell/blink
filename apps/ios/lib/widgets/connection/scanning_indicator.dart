import 'package:flutter/material.dart';
import '../../theme/remote_theme.dart';

/// Animated scanning indicator with ripple effect
class ScanningIndicator extends StatefulWidget {
  const ScanningIndicator({super.key});

  @override
  State<ScanningIndicator> createState() => _ScanningIndicatorState();
}

class _ScanningIndicatorState extends State<ScanningIndicator>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _radiusAnimations;
  late List<Animation<double>> _opacityAnimations;

  static const int _rippleCount = 3;
  static const Duration _rippleDuration = Duration(milliseconds: 2000);
  static const double _maxRadius = 100;

  @override
  void initState() {
    super.initState();
    
    _controllers = List.generate(
      _rippleCount,
      (index) => AnimationController(
        duration: _rippleDuration,
        vsync: this,
      ),
    );

    _radiusAnimations = _controllers.map((controller) {
      return Tween<double>(begin: 20, end: _maxRadius).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeOut),
      );
    }).toList();

    _opacityAnimations = _controllers.map((controller) {
      return Tween<double>(begin: 0.6, end: 0).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeOut),
      );
    }).toList();

    // Start ripples with staggered delays
    for (var i = 0; i < _rippleCount; i++) {
      Future.delayed(
        Duration(milliseconds: i * (_rippleDuration.inMilliseconds ~/ _rippleCount)),
        () {
          if (mounted) {
            _controllers[i].repeat();
          }
        },
      );
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _maxRadius * 2,
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Ripples
            ...List.generate(_rippleCount, (index) {
              return AnimatedBuilder(
                animation: _controllers[index],
                builder: (context, child) {
                  return Container(
                    width: _radiusAnimations[index].value * 2,
                    height: _radiusAnimations[index].value * 2,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: RemoteTheme.accent.withOpacity(
                          _opacityAnimations[index].value,
                        ),
                        width: 2,
                      ),
                    ),
                  );
                },
              );
            }),
            
            // Center dot
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: RemoteTheme.accent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: RemoteTheme.accent.withOpacity(0.5),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

