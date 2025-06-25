import 'package:flutter/material.dart';
import '../services/android_tv_service.dart';

class ConnectionWidget extends StatefulWidget {
  final AndroidTVService tvService;
  final Function(bool connected, String? deviceIP) onConnectionChanged;

  const ConnectionWidget({
    super.key,
    required this.tvService,
    required this.onConnectionChanged,
  });

  @override
  State<ConnectionWidget> createState() => _ConnectionWidgetState();
}

class _ConnectionWidgetState extends State<ConnectionWidget> {
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _portController = TextEditingController(
    text: '8080',
  );
  bool _isScanning = false;
  bool _isConnecting = false;
  List<String> _discoveredDevices = [];
  Map<String, dynamic>? _deviceInfo;
  Map<String, dynamic>? _lastConnection;

  @override
  void initState() {
    super.initState();
    _loadLastConnection();
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _loadLastConnection() async {
    final lastConnection = await widget.tvService.getLastConnection();
    if (lastConnection != null) {
      setState(() {
        _lastConnection = lastConnection;
        // Pre-fill the form with last connection
        _ipController.text = lastConnection['ip'];
        _portController.text = lastConnection['port'].toString();
      });
    }
  }

  Future<void> _scanForDevices() async {
    setState(() {
      _isScanning = true;
      _discoveredDevices.clear();
    });

    try {
      final devices = await widget.tvService.scanForDevices();
      setState(() {
        _discoveredDevices = devices;
      });

      if (devices.isEmpty) {
        _showSnackBar('No Android TV devices found', Colors.orange);
      } else {
        _showSnackBar('Found ${devices.length} device(s)', Colors.green);
      }
    } catch (e) {
      _showSnackBar('Scan failed: $e', Colors.red);
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  Future<void> _connectToDevice(String ip, int port) async {
    setState(() {
      _isConnecting = true;
    });

    try {
      final success = await widget.tvService.connect(ip, port: port);
      if (success) {
        // Get device info
        final info = await widget.tvService.getDeviceInfo();
        setState(() {
          _deviceInfo = info;
        });

        widget.onConnectionChanged(true, ip);
      } else {
        widget.onConnectionChanged(false, null);
        _showSnackBar('Failed to connect to $ip:$port', Colors.red);
      }
    } catch (e) {
      widget.onConnectionChanged(false, null);
      _showSnackBar('Connection error: $e', Colors.red);
    } finally {
      setState(() {
        _isConnecting = false;
      });
    }
  }

  void _disconnect() {
    widget.tvService.disconnect();
    widget.onConnectionChanged(false, null);
    setState(() {
      _deviceInfo = null;
    });
  }

  Future<void> _reconnectToLast() async {
    if (_lastConnection == null) return;

    final ip = _lastConnection!['ip'] as String;
    final port = _lastConnection!['port'] as int;
    await _connectToDevice(ip, port);
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = widget.tvService.isConnected;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Connection Status
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isConnected ? Icons.wifi : Icons.wifi_off,
                        color: isConnected ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Connection Status',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isConnected
                        ? 'Connected to ${widget.tvService.deviceIP}'
                        : 'Not connected',
                    style: TextStyle(
                      color: isConnected ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (isConnected) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _disconnect,
                        icon: const Icon(Icons.power_off),
                        label: const Text('Disconnect'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          if (_deviceInfo != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Device Information',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._deviceInfo!.entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 80,
                              child: Text(
                                '${entry.key}:',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Expanded(child: Text(entry.value.toString())),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 16), // Last Connection
          if (_lastConnection != null && !isConnected) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.history, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          'Last Connection',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${_lastConnection!['ip']}:${_lastConnection!['port']}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed:
                            _isConnecting ? null : () => _reconnectToLast(),
                        icon:
                            _isConnecting
                                ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Icon(Icons.refresh),
                        label: Text(
                          _isConnecting ? 'Reconnecting...' : 'Reconnect',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Manual Connection
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Manual Connection',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _ipController,
                    decoration: const InputDecoration(
                      labelText: 'TV IP Address',
                      hintText: 'e.g., 192.168.1.100',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.router),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _portController,
                    decoration: const InputDecoration(
                      labelText: 'Port',
                      hintText: '8080',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.settings_ethernet),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          _isConnecting || isConnected
                              ? null
                              : () {
                                final ip = _ipController.text.trim();
                                final port =
                                    int.tryParse(_portController.text) ?? 8080;
                                if (ip.isNotEmpty) {
                                  _connectToDevice(ip, port);
                                }
                              },
                      icon:
                          _isConnecting
                              ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Icon(Icons.link),
                      label: Text(_isConnecting ? 'Connecting...' : 'Connect'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Auto Discovery
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Auto Discovery',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Scan your local network for Android TV devices',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isScanning ? null : _scanForDevices,
                      icon:
                          _isScanning
                              ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Icon(Icons.search),
                      label: Text(
                        _isScanning ? 'Scanning...' : 'Scan for Devices',
                      ),
                    ),
                  ),
                  if (_discoveredDevices.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Discovered Devices:',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    ..._discoveredDevices.map(
                      (device) => Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: const Icon(Icons.tv),
                          title: Text(device),
                          subtitle: const Text('Android TV Device'),
                          trailing: IconButton(
                            icon: const Icon(Icons.link),
                            onPressed:
                                isConnected
                                    ? null
                                    : () => _connectToDevice(device, 8080),
                          ),
                          onTap:
                              isConnected
                                  ? null
                                  : () {
                                    _ipController.text = device;
                                    _connectToDevice(device, 8080);
                                  },
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Instructions
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline),
                      const SizedBox(width: 8),
                      Text(
                        'Setup Instructions',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '1. Make sure your Android TV and phone are on the same WiFi network\n'
                    '2. Enable Developer Options on your Android TV\n'
                    '3. Enable USB/Network debugging\n'
                    '4. Install and run an ADB TCP server app on your TV\n'
                    '5. Use the scan feature or enter the TV\'s IP address manually',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
