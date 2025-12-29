import 'package:flutter/cupertino.dart';
import '../models/device.dart';
import '../services/cursor_agent_service.dart';
import '../core/service_locator.dart';
import '../utils/theme.dart';

/// Device management screen for configuring SSH-accessible remote devices
class DeviceManagementScreen extends StatefulWidget {
  const DeviceManagementScreen({super.key});

  @override
  State<DeviceManagementScreen> createState() => _DeviceManagementScreenState();
}

class _DeviceManagementScreenState extends State<DeviceManagementScreen> {
  final _agentService = getIt<CursorAgentService>();
  List<Device> _devices = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final devices = await _agentService.listDevices();
      setState(() {
        _devices = devices;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _testDevice(Device device) async {
    try {
      final result = await _agentService.testDevice(device.id);
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: Text(result.success ? 'Connection Successful' : 'Connection Failed'),
            content: Text(result.message),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
        
        if (result.success) {
          _loadDevices(); // Refresh to update last_seen
        }
      }
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text('Failed to test device: $e'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _deleteDevice(Device device) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete Device'),
        content: Text('Are you sure you want to delete "${device.name}"? This will also remove all associated remote chats.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Delete'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _agentService.deleteDevice(device.id);
        _loadDevices();
      } catch (e) {
        if (mounted) {
          showCupertinoDialog(
            context: context,
            builder: (context) => CupertinoAlertDialog(
              title: const Text('Error'),
              content: Text('Failed to delete device: $e'),
              actions: [
                CupertinoDialogAction(
                  child: const Text('OK'),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          );
        }
      }
    }
  }

  void _showAddDeviceDialog() {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => AddDeviceScreen(
          onDeviceAdded: () => _loadDevices(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;

    return CupertinoPageScaffold(
      backgroundColor: isDark ? AppTheme.backgroundDark : AppTheme.background,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Devices'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.add),
          onPressed: _showAddDeviceDialog,
        ),
      ),
      child: SafeArea(
        child: _isLoading
            ? const Center(child: CupertinoActivityIndicator())
            : _errorMessage.isNotEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _errorMessage,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isDark ? CupertinoColors.systemGrey : CupertinoColors.systemGrey2,
                            ),
                          ),
                          const SizedBox(height: 16),
                          CupertinoButton(
                            child: const Text('Retry'),
                            onPressed: _loadDevices,
                          ),
                        ],
                      ),
                    ),
                  )
                : _devices.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              CupertinoIcons.device_laptop,
                              size: 64,
                              color: isDark ? CupertinoColors.systemGrey : CupertinoColors.systemGrey2,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No devices configured',
                              style: TextStyle(
                                fontSize: 18,
                                color: isDark ? CupertinoColors.systemGrey : CupertinoColors.systemGrey2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Add a device to start remote development',
                              style: TextStyle(
                                fontSize: 14,
                                color: CupertinoColors.systemGrey,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _devices.length,
                        itemBuilder: (context, index) {
                          final device = _devices[index];
                          return _DeviceTile(
                            device: device,
                            onTest: () => _testDevice(device),
                            onDelete: () => _deleteDevice(device),
                          );
                        },
                      ),
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  final Device device;
  final VoidCallback onTest;
  final VoidCallback onDelete;

  const _DeviceTile({
    required this.device,
    required this.onTest,
    required this.onDelete,
  });

  Color _getStatusColor() {
    switch (device.status) {
      case DeviceStatus.online:
        return CupertinoColors.systemGreen;
      case DeviceStatus.offline:
        return CupertinoColors.systemGrey;
      case DeviceStatus.unknown:
        return CupertinoColors.systemYellow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : AppTheme.surface,
        border: Border(
          bottom: BorderSide(
            color: (isDark ? CupertinoColors.white : CupertinoColors.black).withOpacity(0.1),
            width: 0.5,
          ),
        ),
      ),
      child: CupertinoListTile(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: _getStatusColor(),
            shape: BoxShape.circle,
          ),
        ),
        title: Text(device.name),
        subtitle: Text(device.apiEndpoint),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Icon(CupertinoIcons.checkmark_shield, size: 24),
              onPressed: onTest,
            ),
            const SizedBox(width: 8),
            CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Icon(CupertinoIcons.delete, size: 24, color: CupertinoColors.systemRed),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

/// Screen for adding a new device
class AddDeviceScreen extends StatefulWidget {
  final VoidCallback onDeviceAdded;

  const AddDeviceScreen({
    super.key,
    required this.onDeviceAdded,
  });

  @override
  State<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends State<AddDeviceScreen> {
  final _nameController = TextEditingController();
  final _apiEndpointController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _agentService = getIt<CursorAgentService>();
  bool _isSubmitting = false;

  Future<void> _addDevice() async {
    final name = _nameController.text.trim();
    final apiEndpoint = _apiEndpointController.text.trim();
    final apiKey = _apiKeyController.text.trim();

    if (name.isEmpty || apiEndpoint.isEmpty) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Invalid Input'),
          content: const Text('Please fill in name and API endpoint'),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final deviceCreate = DeviceCreate(
        name: name,
        apiEndpoint: apiEndpoint,
        apiKey: apiKey.isNotEmpty ? apiKey : null,
      );

      await _agentService.createDevice(deviceCreate);

      if (mounted) {
        widget.onDeviceAdded();
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text('Failed to add device: $e'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;

    return CupertinoPageScaffold(
      backgroundColor: isDark ? AppTheme.backgroundDark : AppTheme.background,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Add Device'),
        trailing: _isSubmitting
            ? const CupertinoActivityIndicator()
            : CupertinoButton(
                padding: EdgeInsets.zero,
                child: const Text('Save'),
                onPressed: _addDevice,
              ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            CupertinoTextField(
              controller: _nameController,
              placeholder: 'Device Name',
              padding: const EdgeInsets.all(16),
            ),
            const SizedBox(height: 16),
            CupertinoTextField(
              controller: _apiEndpointController,
              placeholder: 'API Endpoint (e.g., http://192.168.1.10:8080)',
              padding: const EdgeInsets.all(16),
            ),
            const SizedBox(height: 16),
            CupertinoTextField(
              controller: _apiKeyController,
              placeholder: 'API Key (optional)',
              padding: const EdgeInsets.all(16),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            const Text(
              'Enter the API endpoint of the remote agent service running on your Mac.',
              style: TextStyle(
                fontSize: 12,
                color: CupertinoColors.systemGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _apiEndpointController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }
}

