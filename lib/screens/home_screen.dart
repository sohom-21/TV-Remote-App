import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/android_tv_service.dart';
import '../widgets/remote_control_widget.dart';
import '../widgets/connection_widget.dart';
import '../widgets/quick_apps_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final AndroidTVService _tvService = AndroidTVService();
  late TabController _tabController;
  bool _isConnected = false;
  String? _connectedDevice;
  bool _isAttemptingReconnect = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _attemptAutoReconnect();
  }

  // Attempt to reconnect using last saved connection
  Future<void> _attemptAutoReconnect() async {
    setState(() {
      _isAttemptingReconnect = true;
    });

    final lastConnection = await _tvService.getLastConnection();
    if (lastConnection != null) {
      final ip = lastConnection['ip'] as String;
      final port = lastConnection['port'] as int;

      // Show reconnect attempt feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Attempting to reconnect to $ip:$port...'),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      final success = await _tvService.attemptAutoReconnect();
      if (success) {
        _onConnectionChanged(true, ip);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to reconnect to $ip:$port'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }

    setState(() {
      _isAttemptingReconnect = false;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onConnectionChanged(bool connected, String? deviceIP) {
    setState(() {
      _isConnected = connected;
      _connectedDevice = deviceIP;
    });

    if (connected) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connected to $deviceIP'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Disconnected from TV'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // Manual disconnect with option to clear saved connection
  void _disconnect() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Disconnect'),
            content: const Text('Do you want to forget this connection?'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _tvService.disconnect();
                  _onConnectionChanged(false, null);
                },
                child: const Text('Just Disconnect'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _tvService.clearLastConnection();
                  _tvService.disconnect();
                  _onConnectionChanged(false, null);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Connection forgotten'),
                      backgroundColor: Colors.grey,
                    ),
                  );
                },
                child: const Text('Forget Connection'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'TV Remote Control',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          if (_isAttemptingReconnect)
            Container(
              margin: const EdgeInsets.only(right: 16),
              child: const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            )
          else
            GestureDetector(
              onTap: _isConnected ? _disconnect : null,
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _isConnected ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_isConnected ? Icons.wifi : Icons.wifi_off, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      _isConnected ? 'Connected' : 'Disconnected',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).colorScheme.primary,
          indicatorWeight: 3,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Theme.of(
            context,
          ).colorScheme.onSurface.withOpacity(0.6),
          tabs: const [
            Tab(icon: Icon(Icons.settings_remote), text: 'Remote'),
            Tab(icon: Icon(Icons.apps), text: 'Apps'),
            Tab(icon: Icon(Icons.settings), text: 'Settings'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Remote Control Tab
          RemoteControlWidget(tvService: _tvService, isConnected: _isConnected),
          // Quick Apps Tab
          QuickAppsWidget(tvService: _tvService, isConnected: _isConnected),
          // Connection Settings Tab
          ConnectionWidget(
            tvService: _tvService,
            onConnectionChanged: _onConnectionChanged,
          ),
        ],
      ),
    );
  }
}
