import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;
import '../models/device.dart';
import '../models/chat.dart';
import '../services/cursor_agent_service.dart';
import '../core/service_locator.dart';
import '../utils/theme.dart';
import 'chat_detail_screen.dart';
import 'package:provider/provider.dart';
import '../providers/chat_detail_provider.dart';

/// Screen for creating a new chat (local or remote)
class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final _agentService = getIt<CursorAgentService>();
  ChatLocation _selectedLocation = ChatLocation.local;
  List<Device> _devices = [];
  Device? _selectedDevice;
  final _directoryController = TextEditingController(text: '/');
  bool _isLoadingDevices = false;
  bool _isCreating = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() {
      _isLoadingDevices = true;
      _errorMessage = '';
    });

    try {
      final devices = await _agentService.listDevices();
      setState(() {
        _devices = devices;
        _selectedDevice = devices.isNotEmpty ? devices.first : null;
        _isLoadingDevices = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load devices: $e';
        _isLoadingDevices = false;
      });
    }
  }

  Future<void> _createChat() async {
    setState(() => _isCreating = true);

    try {
      String chatId;

      if (_selectedLocation == ChatLocation.local) {
        // Create local chat
        chatId = await _agentService.createNewChat();
      } else {
        // Create remote chat
        if (_selectedDevice == null) {
          throw Exception('No device selected');
        }

        final directory = _directoryController.text.trim();
        if (directory.isEmpty) {
          throw Exception('Working directory is required');
        }

        chatId = await _agentService.createRemoteChat(
          _selectedDevice!.id,
          directory,
        );
      }

      // Navigate to chat detail screen
      if (mounted) {
        await Navigator.pushReplacement(
          context,
          CupertinoPageRoute(
            builder: (context) => ChangeNotifierProvider(
              create: (_) => getIt<ChatDetailProvider>(),
              child: ChatDetailScreen(
                chat: Chat(
                  id: chatId,
                  title: _selectedLocation == ChatLocation.local 
                      ? 'New Chat'
                      : 'Remote: ${_selectedDevice!.name}',
                  status: ChatStatus.active,
                  createdAt: DateTime.now(),
                  lastMessageAt: DateTime.now(),
                  messages: [],
                  location: _selectedLocation,
                  remoteInfo: _selectedLocation == ChatLocation.remote
                      ? RemoteChatInfo(
                          chatId: chatId,
                          deviceId: _selectedDevice!.id,
                          deviceName: _selectedDevice!.name,
                          deviceStatus: _selectedDevice!.status,
                          workingDirectory: _directoryController.text.trim(),
                        )
                      : null,
                ),
              ),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isCreating = false);
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text('Failed to create chat: $e'),
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
        middle: const Text('New Chat'),
        trailing: _isCreating
            ? const CupertinoActivityIndicator()
            : CupertinoButton(
                padding: EdgeInsets.zero,
                child: const Text('Create'),
                onPressed: (_selectedLocation == ChatLocation.remote && _selectedDevice == null)
                    ? null
                    : _createChat,
              ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Location selector
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.surfaceDark : AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Location',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  CupertinoSegmentedControl<ChatLocation>(
                    groupValue: _selectedLocation,
                    children: const {
                      ChatLocation.local: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        child: Text('Local'),
                      ),
                      ChatLocation.remote: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        child: Text('Remote'),
                      ),
                    },
                    onValueChanged: (value) {
                      setState(() => _selectedLocation = value);
                    },
                  ),
                ],
              ),
            ),

            // Remote configuration (if remote selected)
            if (_selectedLocation == ChatLocation.remote) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.surfaceDark : AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Device',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (_isLoadingDevices)
                          const CupertinoActivityIndicator()
                        else
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            child: const Icon(CupertinoIcons.refresh, size: 20),
                            onPressed: _loadDevices,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_devices.isEmpty)
                      Column(
                        children: [
                          Text(
                            'No devices configured',
                            style: TextStyle(
                              color: isDark ? CupertinoColors.systemGrey : CupertinoColors.systemGrey2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          CupertinoButton(
                            child: const Text('Manage Devices'),
                            onPressed: () {
                              Navigator.pushNamed(context, '/devices');
                            },
                          ),
                        ],
                      )
                    else
                      CupertinoButton(
                        padding: const EdgeInsets.all(12),
                        color: isDark ? AppTheme.backgroundDark : CupertinoColors.systemGrey6,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _selectedDevice?.name ?? 'Select device',
                                style: TextStyle(
                                  color: isDark ? CupertinoColors.white : CupertinoColors.black,
                                ),
                              ),
                            ),
                            const Icon(CupertinoIcons.chevron_down, size: 20),
                          ],
                        ),
                        onPressed: () => _showDevicePicker(),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.surfaceDark : AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Working Directory',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    CupertinoTextField(
                      controller: _directoryController,
                      placeholder: '/path/to/directory',
                      padding: const EdgeInsets.all(12),
                      prefix: const Padding(
                        padding: EdgeInsets.only(left: 12),
                        child: Icon(CupertinoIcons.folder, size: 20),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _selectedDevice != null
                          ? '${_selectedDevice!.name}:${_directoryController.text}'
                          : 'Select a device first',
                      style: const TextStyle(
                        fontSize: 12,
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Info box
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CupertinoColors.systemBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    CupertinoIcons.info_circle,
                    size: 20,
                    color: CupertinoColors.systemBlue,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedLocation == ChatLocation.local
                          ? 'Local chats use cursor-agent on this machine'
                          : 'Remote chats execute cursor-agent on the selected device via SSH',
                      style: const TextStyle(
                        fontSize: 12,
                        color: CupertinoColors.systemBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDevicePicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 250,
        color: CupertinoTheme.of(context).brightness == Brightness.dark
            ? CupertinoColors.darkBackgroundGray
            : CupertinoColors.white,
        child: Column(
          children: [
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const Text('Cancel'),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text('Select Device'),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const Text('Done'),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoPicker(
                itemExtent: 40,
                onSelectedItemChanged: (index) {
                  setState(() => _selectedDevice = _devices[index]);
                },
                children: _devices.map((device) {
                  return Center(
                    child: Text('${device.name} (${device.status.displayName})'),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _directoryController.dispose();
    super.dispose();
  }
}

