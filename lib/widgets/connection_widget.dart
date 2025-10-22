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
              child: Row(
                children: [
                  Icon(
                    isConnected ? Icons.wifi : Icons.wifi_off,
                    color: isConnected ? Colors.green : Colors.red,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isConnected ? 'Connected' : 'Not Connected',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isConnected ? Colors.green : Colors.grey,
                          ),
                        ),
                        if (isConnected)
                          Text(
                            widget.tvService.deviceIP ?? '',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (isConnected)
                    IconButton(
                      onPressed: _disconnect,
                      icon: const Icon(Icons.power_off, color: Colors.red),
                      tooltip: 'Disconnect',
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Last Connection (only if not connected)
          if (_lastConnection != null && !isConnected) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.history, color: Colors.blue, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Last Connection',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${_lastConnection!['ip']}:${_lastConnection!['port']}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _isConnecting ? null : _reconnectToLast,
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
                        _isConnecting ? 'Connecting...' : 'Reconnect',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
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
                  const Text(
                    'Connect to TV',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _ipController,
                          decoration: const InputDecoration(
                            labelText: 'IP Address',
                            hintText: '192.168.1.100',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.router),
                          ),
                          keyboardType: TextInputType.text,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _portController,
                          decoration: const InputDecoration(
                            labelText: 'Port',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
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
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Icon(Icons.link),
                      label: Text(_isConnecting ? 'Connecting...' : 'Connect'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Quick Connect Buttons
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildQuickConnectButton('127.0.0.1', 'Localhost'),
                      _buildQuickConnectButton('10.0.2.2', 'Emulator'),
                      _buildQuickConnectButton('10.106.178.46', 'Server'),
                      _buildQuickConnectButton('192.168.137.1', 'Windows'),
                    ],
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
                  Row(
                    children: [
                      const Text(
                        'Scan Network',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
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
                        label: Text(_isScanning ? 'Scanning...' : 'Scan'),
                      ),
                    ],
                  ),
                  if (_discoveredDevices.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    ..._discoveredDevices.map(
                      (device) => Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: const Icon(Icons.tv, color: Colors.blue),
                          title: Text(device),
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

          // Simple Connection Info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Colors.blue,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'How to Connect',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '• For Android TV emulator: Run the bridge server on your PC\n'
                    '• Connect your phone to PC\'s network (same WiFi or hotspot)\n'
                    '• Use port 8080 for HTTP server connections\n'
                    '• Try "Localhost" if testing on same device',
                    style: TextStyle(fontSize: 14, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickConnectButton(String ip, String label) {
    return OutlinedButton(
      onPressed:
          (_isConnecting || widget.tvService.isConnected)
              ? null
              : () {
                _ipController.text = ip;
                final port = int.tryParse(_portController.text) ?? 8080;
                _connectToDevice(ip, port);
              },
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}
