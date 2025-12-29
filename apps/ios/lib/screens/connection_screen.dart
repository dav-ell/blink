import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/remote_theme.dart';
import '../theme/glassmorphism.dart';
import '../theme/animations.dart';
import '../providers/connection_provider.dart';
import '../models/server.dart';
import '../models/connection_state.dart' show ConnectionPhase, ConnectionPhaseExtension;
import '../utils/haptics.dart';
import '../widgets/connection/server_card.dart';
import '../widgets/connection/scanning_indicator.dart';
import 'window_picker_screen.dart';

/// Server discovery and connection screen
class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  final TextEditingController _manualHostController = TextEditingController();
  bool _showManualEntry = false;

  @override
  void initState() {
    super.initState();
    // Start discovery when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ConnectionProvider>().startDiscovery();
    });
  }

  @override
  void dispose() {
    _manualHostController.dispose();
    super.dispose();
  }

  void _connectToServer(StreamServer server) async {
    Haptics.tap();
    final provider = context.read<ConnectionProvider>();
    await provider.connectToServer(server);
  }

  void _addManualServer() {
    final host = _manualHostController.text.trim();
    if (host.isEmpty) return;

    Haptics.tap();
    
    // Parse host:port format
    String hostName = host;
    int port = 8080;
    
    if (host.contains(':')) {
      final parts = host.split(':');
      hostName = parts[0];
      port = int.tryParse(parts[1]) ?? 8080;
    }

    context.read<ConnectionProvider>().addManualServer(hostName, port: port);
    _manualHostController.clear();
    setState(() => _showManualEntry = false);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: RemoteTheme.background,
      child: SafeArea(
        child: Consumer<ConnectionProvider>(
          builder: (context, provider, child) {
            // Navigate to window picker when connected
            if (provider.state.phase == ConnectionPhase.connected) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.of(context).pushReplacement(
                  CupertinoPageRoute(
                    builder: (_) => const WindowPickerScreen(),
                  ),
                );
              });
            }

            return CustomScrollView(
              slivers: [
                // Header
                SliverToBoxAdapter(
                  child: _buildHeader(provider),
                ),

                // Scanning indicator
                if (provider.isDiscovering)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: RemoteTheme.spacingLG),
                      child: ScanningIndicator(),
                    ),
                  ),

                // Connection status
                if (provider.state.isConnecting)
                  SliverToBoxAdapter(
                    child: _buildConnectingStatus(provider),
                  ),

                // Error message
                if (provider.state.hasError)
                  SliverToBoxAdapter(
                    child: _buildErrorMessage(provider.state.error!),
                  ),

                // Discovered servers
                if (provider.discoveredServers.isNotEmpty) ...[
                  const SliverToBoxAdapter(
                    child: _SectionHeader(title: 'Discovered'),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final server = provider.discoveredServers[index];
                        return FadeSlideIn(
                          delay: StaggeredListAnimation.getDelay(index),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: RemoteTheme.spacingMD,
                              vertical: RemoteTheme.spacingXS,
                            ),
                            child: ServerCard(
                              server: server,
                              onTap: () => _connectToServer(server),
                              isConnecting: provider.state.server?.id == server.id &&
                                  provider.state.isConnecting,
                            ),
                          ),
                        );
                      },
                      childCount: provider.discoveredServers.length,
                    ),
                  ),
                ],

                // Recent servers
                if (provider.recentServers.isNotEmpty) ...[
                  const SliverToBoxAdapter(
                    child: _SectionHeader(title: 'Recent'),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final server = provider.recentServers[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: RemoteTheme.spacingMD,
                            vertical: RemoteTheme.spacingXS,
                          ),
                          child: ServerCard(
                            server: server,
                            onTap: () => _connectToServer(server),
                            isConnecting: provider.state.server?.id == server.id &&
                                provider.state.isConnecting,
                          ),
                        );
                      },
                      childCount: provider.recentServers.length,
                    ),
                  ),
                ],

                // Manual entry section
                SliverToBoxAdapter(
                  child: _buildManualEntry(),
                ),

                // Empty state
                if (provider.discoveredServers.isEmpty &&
                    provider.recentServers.isEmpty &&
                    !provider.isDiscovering)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(provider),
                  ),

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

  Widget _buildHeader(ConnectionProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(RemoteTheme.spacingLG),
      child: Column(
        children: [
          const SizedBox(height: RemoteTheme.spacingXL),
          
          // Icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: RemoteTheme.accentGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: RemoteTheme.glowAccent,
            ),
            child: const Icon(
              CupertinoIcons.desktopcomputer,
              size: 40,
              color: Colors.white,
            ),
          ),
          
          const SizedBox(height: RemoteTheme.spacingLG),
          
          // Title
          Text(
            'Blink',
            style: RemoteTheme.titleLarge.copyWith(
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: RemoteTheme.spacingSM),
          
          // Subtitle
          Text(
            provider.isDiscovering
                ? 'Looking for servers...'
                : 'Connect to start streaming',
            style: RemoteTheme.bodyMedium.copyWith(
              color: RemoteTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectingStatus(ConnectionProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(RemoteTheme.spacingMD),
      child: GlassContainer(
        padding: const EdgeInsets.all(RemoteTheme.spacingMD),
        child: Row(
          children: [
            const CupertinoActivityIndicator(),
            const SizedBox(width: RemoteTheme.spacingMD),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    provider.state.server?.name ?? 'Connecting',
                    style: RemoteTheme.titleSmall,
                  ),
                  Text(
                    provider.state.phase.statusMessage,
                    style: RemoteTheme.caption,
                  ),
                ],
              ),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                Haptics.tap();
                provider.disconnect();
              },
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorMessage(String error) {
    return Padding(
      padding: const EdgeInsets.all(RemoteTheme.spacingMD),
      child: GlassContainer(
        padding: const EdgeInsets.all(RemoteTheme.spacingMD),
        backgroundColor: RemoteTheme.error.withOpacity(0.2),
        child: Row(
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_circle,
              color: RemoteTheme.error,
            ),
            const SizedBox(width: RemoteTheme.spacingMD),
            Expanded(
              child: Text(
                error,
                style: RemoteTheme.bodySmall.copyWith(color: RemoteTheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualEntry() {
    return Padding(
      padding: const EdgeInsets.all(RemoteTheme.spacingMD),
      child: Column(
        children: [
          // Divider
          Row(
            children: [
              const Expanded(child: Divider(color: RemoteTheme.surfaceHighlight)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: RemoteTheme.spacingMD),
                child: Text(
                  'or enter manually',
                  style: RemoteTheme.caption,
                ),
              ),
              const Expanded(child: Divider(color: RemoteTheme.surfaceHighlight)),
            ],
          ),
          
          const SizedBox(height: RemoteTheme.spacingMD),
          
          // Manual entry field
          AnimatedContainer(
            duration: RemoteTheme.durationNormal,
            child: _showManualEntry
                ? _buildManualEntryField()
                : GlassButton(
                    onPressed: () {
                      Haptics.tap();
                      setState(() => _showManualEntry = true);
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          CupertinoIcons.plus,
                          size: 18,
                          color: RemoteTheme.textSecondary,
                        ),
                        const SizedBox(width: RemoteTheme.spacingSM),
                        Text(
                          'Add Server',
                          style: RemoteTheme.bodyMedium.copyWith(
                            color: RemoteTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualEntryField() {
    return GlassContainer(
      padding: const EdgeInsets.all(RemoteTheme.spacingMD),
      child: Column(
        children: [
          CupertinoTextField(
            controller: _manualHostController,
            placeholder: 'IP Address (e.g., 192.168.1.100:8080)',
            style: RemoteTheme.bodyMedium,
            placeholderStyle: RemoteTheme.bodyMedium.copyWith(
              color: RemoteTheme.textTertiary,
            ),
            decoration: BoxDecoration(
              color: RemoteTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(RemoteTheme.radiusSM),
            ),
            padding: const EdgeInsets.all(RemoteTheme.spacingMD),
            onSubmitted: (_) => _addManualServer(),
          ),
          const SizedBox(height: RemoteTheme.spacingMD),
          Row(
            children: [
              Expanded(
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: RemoteTheme.spacingSM),
                  onPressed: () {
                    Haptics.tap();
                    setState(() => _showManualEntry = false);
                    _manualHostController.clear();
                  },
                  child: Text(
                    'Cancel',
                    style: RemoteTheme.bodyMedium.copyWith(
                      color: RemoteTheme.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: RemoteTheme.spacingMD),
              Expanded(
                child: CupertinoButton.filled(
                  padding: const EdgeInsets.symmetric(vertical: RemoteTheme.spacingSM),
                  onPressed: _addManualServer,
                  child: const Text('Connect'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ConnectionProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(RemoteTheme.spacingXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.wifi_slash,
              size: 64,
              color: RemoteTheme.textTertiary.withOpacity(0.5),
            ),
            const SizedBox(height: RemoteTheme.spacingMD),
            Text(
              'No servers found',
              style: RemoteTheme.titleMedium.copyWith(
                color: RemoteTheme.textSecondary,
              ),
            ),
            const SizedBox(height: RemoteTheme.spacingSM),
            Text(
              'Make sure the stream server is running on your Mac',
              style: RemoteTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: RemoteTheme.spacingLG),
            CupertinoButton(
              onPressed: () {
                Haptics.tap();
                provider.startDiscovery();
              },
              child: const Text('Scan Again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        RemoteTheme.spacingMD,
        RemoteTheme.spacingLG,
        RemoteTheme.spacingMD,
        RemoteTheme.spacingSM,
      ),
      child: Text(
        title.toUpperCase(),
        style: RemoteTheme.label,
      ),
    );
  }
}

