import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:nsd/nsd.dart' as nsd;
import '../models/server.dart';

/// Service for discovering stream servers via mDNS/Bonjour
class DiscoveryService extends ChangeNotifier {
  static const String _serviceType = '_blink._tcp';
  static const Duration _discoveryTimeout = Duration(seconds: 10);

  final Map<String, StreamServer> _servers = {};
  nsd.Discovery? _discovery;
  bool _isDiscovering = false;
  String? _error;

  /// Currently discovered servers
  List<StreamServer> get servers => _servers.values.toList()
    ..sort((a, b) => (b.lastSeen ?? DateTime(0)).compareTo(a.lastSeen ?? DateTime(0)));

  /// Whether discovery is active
  bool get isDiscovering => _isDiscovering;

  /// Last error message
  String? get error => _error;

  /// Start discovering servers
  Future<void> startDiscovery() async {
    if (_isDiscovering) return;

    _isDiscovering = true;
    _error = null;
    notifyListeners();

    try {
      _discovery = await nsd.startDiscovery(_serviceType, autoResolve: true);
      
      _discovery!.addServiceListener((service, status) {
        if (status == nsd.ServiceStatus.found) {
          _handleServiceFound(service);
        } else if (status == nsd.ServiceStatus.lost) {
          _handleServiceLost(service);
        }
      });
      
      // Auto-stop after timeout to save battery
      Future.delayed(_discoveryTimeout, () {
        if (_isDiscovering) {
          stopDiscovery();
        }
      });
    } catch (e) {
      _error = 'Discovery failed: $e';
      _isDiscovering = false;
      notifyListeners();
    }
  }

  /// Stop discovering servers
  Future<void> stopDiscovery() async {
    if (!_isDiscovering) return;

    try {
      if (_discovery != null) {
        await nsd.stopDiscovery(_discovery!);
      }
    } catch (e) {
      debugPrint('Error stopping discovery: $e');
    }
    
    _discovery = null;
    _isDiscovering = false;
    notifyListeners();
  }

  /// Add a server manually by IP address
  void addManualServer(String host, {int port = 8080, String? name}) {
    final server = StreamServer.manual(
      host: host,
      port: port,
      name: name,
    );
    _servers[server.id] = server;
    notifyListeners();
  }

  /// Remove a server
  void removeServer(String serverId) {
    _servers.remove(serverId);
    notifyListeners();
  }

  /// Refresh a server's last seen time
  void refreshServer(String serverId) {
    final server = _servers[serverId];
    if (server != null) {
      _servers[serverId] = server.copyWith(lastSeen: DateTime.now());
      notifyListeners();
    }
  }

  void _handleServiceFound(nsd.Service service) {
    try {
      final host = service.host;
      final port = service.port;
      
      if (host != null && port != null) {
        // Convert txt records from Map<String, Uint8List?>? to Map<String, String>?
        Map<String, String>? txtRecords;
        if (service.txt != null) {
          txtRecords = <String, String>{};
          for (final entry in service.txt!.entries) {
            if (entry.value != null) {
              txtRecords[entry.key] = utf8.decode(entry.value!);
            }
          }
        }
        
        final server = StreamServer.fromMdns(
          name: service.name ?? 'Unknown Server',
          host: host,
          port: port,
          txtRecords: txtRecords,
        );
        
        _servers[server.id] = server;
        notifyListeners();
        
        debugPrint('Discovered server: ${server.name} at ${server.displayAddress}');
      }
    } catch (e) {
      debugPrint('Failed to process service: $e');
    }
  }

  void _handleServiceLost(nsd.Service service) {
    // Find and remove the server by name
    final serverToRemove = _servers.values.cast<StreamServer?>().firstWhere(
      (s) => s?.name == service.name,
      orElse: () => null,
    );
    
    if (serverToRemove != null) {
      _servers.remove(serverToRemove.id);
      notifyListeners();
      
      debugPrint('Lost server: ${serverToRemove.name}');
    }
  }

  @override
  void dispose() {
    stopDiscovery();
    super.dispose();
  }
}

