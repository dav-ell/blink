import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/remote_theme.dart';
import '../theme/glassmorphism.dart';
import '../theme/animations.dart';
import '../providers/windows_provider.dart';
import '../providers/stream_provider.dart' show VideoStreamProvider;
import '../models/remote_window.dart';
import '../utils/haptics.dart';
import '../widgets/window/window_video.dart';

/// Grid view showing all streaming windows
class GridViewScreen extends StatelessWidget {
  const GridViewScreen({super.key});

  void _selectWindow(BuildContext context, RemoteWindow window) {
    Haptics.windowSelected();
    context.read<WindowsProvider>().setActiveWindow(window.id.toString());
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: RemoteTheme.background,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: RemoteTheme.surface.withOpacity(0.8),
        border: null,
        middle: const Text('All Windows'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ),
      child: SafeArea(
        child: Consumer2<WindowsProvider, VideoStreamProvider>(
          builder: (context, windowsProvider, streamProvider, child) {
            final windows = windowsProvider.subscribedWindows;

            if (windows.isEmpty) {
              return _buildEmptyState();
            }

            return Padding(
              padding: const EdgeInsets.all(RemoteTheme.spacingMD),
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: windows.length > 2 ? 2 : 1,
                  mainAxisSpacing: RemoteTheme.spacingMD,
                  crossAxisSpacing: RemoteTheme.spacingMD,
                  childAspectRatio: 16 / 10,
                ),
                itemCount: windows.length,
                itemBuilder: (context, index) {
                  final window = windows[index];
                  final isActive = window.id.toString() == windowsProvider.activeWindowId;
                  
                  return FadeSlideIn(
                    delay: StaggeredListAnimation.getDelay(index),
                    child: _WindowGridTile(
                      window: window,
                      isActive: isActive,
                      renderer: streamProvider.getRenderer(window.id.toString()),
                      onTap: () => _selectWindow(context, window),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.rectangle_stack,
            size: 64,
            color: RemoteTheme.textTertiary.withOpacity(0.5),
          ),
          const SizedBox(height: RemoteTheme.spacingMD),
          Text(
            'No windows streaming',
            style: RemoteTheme.titleMedium.copyWith(
              color: RemoteTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _WindowGridTile extends StatefulWidget {
  final RemoteWindow window;
  final bool isActive;
  final dynamic renderer;
  final VoidCallback onTap;

  const _WindowGridTile({
    required this.window,
    required this.isActive,
    required this.renderer,
    required this.onTap,
  });

  @override
  State<_WindowGridTile> createState() => _WindowGridTileState();
}

class _WindowGridTileState extends State<_WindowGridTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
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
        child: Container(
          decoration: BoxDecoration(
            color: RemoteTheme.surface,
            borderRadius: BorderRadius.circular(RemoteTheme.radiusLG),
            border: Border.all(
              color: widget.isActive
                  ? RemoteTheme.accent
                  : RemoteTheme.surfaceHighlight,
              width: widget.isActive ? 2 : 1,
            ),
            boxShadow: widget.isActive ? RemoteTheme.glowAccent : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(RemoteTheme.radiusLG - 1),
            child: Stack(
              children: [
                // Video preview
                Positioned.fill(
                  child: widget.renderer != null
                      ? WindowVideo(
                          renderer: widget.renderer,
                          showPlaceholder: false,
                        )
                      : Container(
                          color: RemoteTheme.surfaceElevated,
                          child: Center(
                            child: Icon(
                              CupertinoIcons.rectangle,
                              size: 32,
                              color: RemoteTheme.textTertiary.withOpacity(0.5),
                            ),
                          ),
                        ),
                ),
                
                // Title overlay
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(RemoteTheme.spacingMD),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          RemoteTheme.background.withOpacity(0.8),
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        if (widget.isActive)
                          Container(
                            width: 8,
                            height: 8,
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.window.shortName,
                                style: RemoteTheme.titleSmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                widget.window.appName,
                                style: RemoteTheme.caption,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Active indicator badge
                if (widget.isActive)
                  Positioned(
                    top: RemoteTheme.spacingSM,
                    right: RemoteTheme.spacingSM,
                    child: GlassPill(
                      padding: const EdgeInsets.symmetric(
                        horizontal: RemoteTheme.spacingSM,
                        vertical: RemoteTheme.spacingXS,
                      ),
                      backgroundColor: RemoteTheme.accent.withOpacity(0.3),
                      child: Text(
                        'Active',
                        style: RemoteTheme.caption.copyWith(
                          color: RemoteTheme.accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

