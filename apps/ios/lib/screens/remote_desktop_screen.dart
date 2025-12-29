import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/service_locator.dart';
import '../theme/remote_theme.dart';
import '../theme/glassmorphism.dart';
import '../models/connection_state.dart';
import '../providers/connection_provider.dart';
import '../providers/windows_provider.dart';
import '../providers/stream_provider.dart' show VideoStreamProvider;
import '../services/input_service.dart';
import '../utils/haptics.dart';
import '../widgets/window/window_tab_bar.dart';
import '../widgets/window/window_video.dart';
import '../widgets/input/touch_overlay.dart';
import '../widgets/input/keyboard_bar.dart';
import 'grid_view_screen.dart';
import 'window_picker_screen.dart';
import 'connection_screen.dart';

/// Main remote desktop streaming experience
class RemoteDesktopScreen extends StatefulWidget {
  const RemoteDesktopScreen({super.key});

  @override
  State<RemoteDesktopScreen> createState() => _RemoteDesktopScreenState();
}

class _RemoteDesktopScreenState extends State<RemoteDesktopScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _uiVisibilityController;
  late Animation<double> _uiOpacityAnimation;
  bool _showUI = true;

  @override
  void initState() {
    super.initState();
    _uiVisibilityController = AnimationController(
      duration: RemoteTheme.durationFast,
      vsync: this,
      value: 1.0,
    );
    _uiOpacityAnimation = CurvedAnimation(
      parent: _uiVisibilityController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _uiVisibilityController.dispose();
    super.dispose();
  }

  void _toggleUI() {
    setState(() {
      _showUI = !_showUI;
      if (_showUI) {
        _uiVisibilityController.forward();
      } else {
        _uiVisibilityController.reverse();
      }
    });
  }

  void _showGridView() {
    Haptics.tap();
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => const GridViewScreen(),
      ),
    );
  }

  void _switchToNextWindow() {
    Haptics.tabSwitch();
    context.read<WindowsProvider>().nextWindow();
  }

  void _switchToPreviousWindow() {
    Haptics.tabSwitch();
    context.read<WindowsProvider>().previousWindow();
  }

  void _disconnect() {
    Haptics.tap();
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Disconnect'),
        content: const Text('End the streaming session?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Disconnect'),
            onPressed: () {
              Navigator.pop(context);
              context.read<ConnectionProvider>().disconnect();
              Navigator.of(context).pushAndRemoveUntil(
                CupertinoPageRoute(
                  builder: (_) => const ConnectionScreen(),
                ),
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }

  void _openWindowPicker() {
    Haptics.tap();
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => const WindowPickerScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inputService = getIt<InputService>();

    return CupertinoPageScaffold(
      backgroundColor: RemoteTheme.background,
      child: Consumer3<ConnectionProvider, WindowsProvider, VideoStreamProvider>(
        builder: (context, connectionProvider, windowsProvider, streamProvider, child) {
          final state = connectionProvider.state;
          final activeWindow = windowsProvider.activeWindow;
          final windows = windowsProvider.subscribedWindows;

          // Handle disconnection
          if (!state.isConnected && !state.isConnecting) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(context).pushAndRemoveUntil(
                CupertinoPageRoute(
                  builder: (_) => const ConnectionScreen(),
                ),
                (route) => false,
              );
            });
          }

          return GestureDetector(
            onTap: _toggleUI,
            child: Stack(
              children: [
                // Video stream with touch overlay
                if (activeWindow != null)
                  Positioned.fill(
                    child: TouchOverlay(
                      inputService: inputService,
                      windowId: activeWindow.id,
                      onTwoFingerSwipeLeft: _switchToNextWindow,
                      onTwoFingerSwipeRight: _switchToPreviousWindow,
                      onThreeFingerSwipeDown: _showGridView,
                      child: WindowVideo(
                        renderer: streamProvider.getRenderer(
                          windowsProvider.activeWindowId ?? '',
                        ),
                        windowTitle: activeWindow.shortName,
                      ),
                    ),
                  )
                else
                  const Center(
                    child: CupertinoActivityIndicator(),
                  ),

                // UI overlay
                FadeTransition(
                  opacity: _uiOpacityAnimation,
                  child: IgnorePointer(
                    ignoring: !_showUI,
                    child: Stack(
                      children: [
                        // Top bar with tabs
                        Positioned(
                          top: MediaQuery.of(context).padding.top + RemoteTheme.spacingSM,
                          left: RemoteTheme.spacingMD,
                          right: RemoteTheme.spacingMD,
                          child: WindowTabBar(
                            windows: windows,
                            activeWindowId: windowsProvider.activeWindowId,
                            onWindowSelected: (id) {
                              Haptics.tabSwitch();
                              windowsProvider.setActiveWindow(id);
                            },
                            onGridViewPressed: windows.length > 1 ? _showGridView : null,
                          ),
                        ),

                        // Bottom controls
                        Positioned(
                          bottom: MediaQuery.of(context).padding.bottom + RemoteTheme.spacingMD,
                          left: RemoteTheme.spacingMD,
                          right: RemoteTheme.spacingMD,
                          child: Row(
                            children: [
                              // Disconnect button
                              _ControlButton(
                                icon: CupertinoIcons.xmark_circle,
                                onPressed: _disconnect,
                              ),
                              
                              const SizedBox(width: RemoteTheme.spacingSM),
                              
                              // Add windows button
                              _ControlButton(
                                icon: CupertinoIcons.rectangle_stack_badge_plus,
                                onPressed: _openWindowPicker,
                              ),
                              
                              const Spacer(),
                              
                              // Keyboard button
                              KeyboardBar(
                                inputService: inputService,
                                windowId: activeWindow?.id ?? 0,
                              ),
                            ],
                          ),
                        ),

                        // Connection status indicator (when reconnecting)
                        if (state.phase == ConnectionPhase.reconnecting)
                          Positioned(
                            top: MediaQuery.of(context).padding.top + 60,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: GlassPill(
                                backgroundColor: RemoteTheme.connecting.withOpacity(0.3),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CupertinoActivityIndicator(),
                                    ),
                                    const SizedBox(width: RemoteTheme.spacingSM),
                                    Text(
                                      'Reconnecting...',
                                      style: RemoteTheme.caption.copyWith(
                                        color: RemoteTheme.connecting,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _ControlButton({
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(RemoteTheme.radiusFull),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: CupertinoButton(
          padding: const EdgeInsets.all(RemoteTheme.spacingMD),
          color: RemoteTheme.glassWhite,
          borderRadius: BorderRadius.circular(RemoteTheme.radiusFull),
          onPressed: () {
            Haptics.tap();
            onPressed();
          },
          child: Icon(
            icon,
            size: 22,
            color: RemoteTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

