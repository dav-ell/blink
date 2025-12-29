import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/remote_theme.dart';
import '../theme/animations.dart';
import '../providers/connection_provider.dart';
import '../providers/windows_provider.dart';
import '../models/remote_window.dart';
import '../utils/haptics.dart';
import 'remote_desktop_screen.dart';
import 'connection_screen.dart';

/// Screen for selecting which windows to stream
class WindowPickerScreen extends StatefulWidget {
  const WindowPickerScreen({super.key});

  @override
  State<WindowPickerScreen> createState() => _WindowPickerScreenState();
}

class _WindowPickerScreenState extends State<WindowPickerScreen> {
  final Set<int> _selectedWindowIds = {};

  void _toggleWindow(RemoteWindow window) {
    Haptics.windowSelected();
    setState(() {
      if (_selectedWindowIds.contains(window.id)) {
        _selectedWindowIds.remove(window.id);
      } else {
        _selectedWindowIds.add(window.id);
      }
    });
  }

  void _startStreaming() async {
    if (_selectedWindowIds.isEmpty) return;

    Haptics.success();
    
    final windowsProvider = context.read<WindowsProvider>();
    await windowsProvider.subscribeToWindows(_selectedWindowIds.toList());

    if (mounted) {
      Navigator.of(context).pushReplacement(
        CupertinoPageRoute(
          builder: (_) => const RemoteDesktopScreen(),
        ),
      );
    }
  }

  void _disconnect() {
    Haptics.tap();
    context.read<ConnectionProvider>().disconnect();
    Navigator.of(context).pushReplacement(
      CupertinoPageRoute(
        builder: (_) => const ConnectionScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: RemoteTheme.background,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: RemoteTheme.surface.withOpacity(0.8),
        border: null,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _disconnect,
          child: const Icon(CupertinoIcons.back),
        ),
        middle: const Text('Select Windows'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _selectedWindowIds.isEmpty ? null : _startStreaming,
          child: Text(
            'Done',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: _selectedWindowIds.isEmpty
                  ? RemoteTheme.textTertiary
                  : RemoteTheme.accent,
            ),
          ),
        ),
      ),
      child: SafeArea(
        child: Consumer<ConnectionProvider>(
          builder: (context, provider, child) {
            final windows = provider.state.availableWindows;

            if (windows.isEmpty) {
              return _buildEmptyState();
            }

            // Group windows by app
            final groupedWindows = <String, List<RemoteWindow>>{};
            for (final window in windows) {
              groupedWindows.putIfAbsent(window.appName, () => []).add(window);
            }

            return CustomScrollView(
              slivers: [
                // Selection count
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(RemoteTheme.spacingMD),
                    child: Text(
                      '${_selectedWindowIds.length} window${_selectedWindowIds.length != 1 ? 's' : ''} selected',
                      style: RemoteTheme.caption,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

                // Window grid by app
                ...groupedWindows.entries.expand((entry) {
                  return [
                    // App header
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          RemoteTheme.spacingMD,
                          RemoteTheme.spacingMD,
                          RemoteTheme.spacingMD,
                          RemoteTheme.spacingSM,
                        ),
                        child: Text(
                          entry.key,
                          style: RemoteTheme.label,
                        ),
                      ),
                    ),
                    // Windows grid
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: RemoteTheme.spacingMD,
                      ),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: RemoteTheme.spacingMD,
                          crossAxisSpacing: RemoteTheme.spacingMD,
                          childAspectRatio: 1.2,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final window = entry.value[index];
                            final isSelected = _selectedWindowIds.contains(window.id);
                            
                            return FadeSlideIn(
                              delay: StaggeredListAnimation.getDelay(index),
                              child: _WindowTile(
                                window: window,
                                isSelected: isSelected,
                                onTap: () => _toggleWindow(window),
                              ),
                            );
                          },
                          childCount: entry.value.length,
                        ),
                      ),
                    ),
                  ];
                }),

                // Bottom padding
                const SliverToBoxAdapter(
                  child: SizedBox(height: RemoteTheme.spacing2XL),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(RemoteTheme.spacingXL),
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
              'No windows available',
              style: RemoteTheme.titleMedium.copyWith(
                color: RemoteTheme.textSecondary,
              ),
            ),
            const SizedBox(height: RemoteTheme.spacingSM),
            Text(
              'Open some applications on your Mac',
              style: RemoteTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _WindowTile extends StatelessWidget {
  final RemoteWindow window;
  final bool isSelected;
  final VoidCallback onTap;

  const _WindowTile({
    required this.window,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: RemoteTheme.durationFast,
        decoration: BoxDecoration(
          color: isSelected
              ? RemoteTheme.accent.withOpacity(0.2)
              : RemoteTheme.surface,
          borderRadius: BorderRadius.circular(RemoteTheme.radiusLG),
          border: Border.all(
            color: isSelected
                ? RemoteTheme.accent
                : RemoteTheme.surfaceHighlight,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            // Window preview placeholder
            Positioned.fill(
              child: Container(
                margin: const EdgeInsets.all(RemoteTheme.spacingSM),
                decoration: BoxDecoration(
                  color: RemoteTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(RemoteTheme.radiusMD),
                ),
                child: Center(
                  child: Icon(
                    CupertinoIcons.rectangle,
                    size: 32,
                    color: RemoteTheme.textTertiary.withOpacity(0.5),
                  ),
                ),
              ),
            ),
            
            // Window title
            Positioned(
              left: RemoteTheme.spacingSM,
              right: RemoteTheme.spacingSM,
              bottom: RemoteTheme.spacingSM,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: RemoteTheme.spacingSM,
                  vertical: RemoteTheme.spacingXS,
                ),
                decoration: BoxDecoration(
                  color: RemoteTheme.background.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(RemoteTheme.radiusSM),
                ),
                child: Text(
                  window.shortName,
                  style: RemoteTheme.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            
            // Selection indicator
            if (isSelected)
              Positioned(
                top: RemoteTheme.spacingSM,
                right: RemoteTheme.spacingSM,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: RemoteTheme.accent,
                    shape: BoxShape.circle,
                    boxShadow: RemoteTheme.glowAccent,
                  ),
                  child: const Icon(
                    CupertinoIcons.checkmark,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

