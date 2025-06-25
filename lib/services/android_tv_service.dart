import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AndroidTVService {
  static const int defaultPort = 8080;
  static const Duration timeout = Duration(seconds: 5);
  static const String _lastIPKey = 'last_connected_ip';
  static const String _lastPortKey = 'last_connected_port';

  String? _deviceIP;
  int _port = defaultPort;
  bool _isConnected = false;

  String? get deviceIP => _deviceIP;
  bool get isConnected => _isConnected;

  // Save last successful connection
  Future<void> _saveLastConnection(String ip, int port) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastIPKey, ip);
      await prefs.setInt(_lastPortKey, port);
    } catch (e) {
      print('Error saving last connection: $e');
    }
  }

  // Load last successful connection
  Future<Map<String, dynamic>?> getLastConnection() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ip = prefs.getString(_lastIPKey);
      final port = prefs.getInt(_lastPortKey) ?? defaultPort;

      if (ip != null) {
        return {'ip': ip, 'port': port};
      }
    } catch (e) {
      print('Error loading last connection: $e');
    }
    return null;
  }

  // Clear saved connection
  Future<void> clearLastConnection() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastIPKey);
      await prefs.remove(_lastPortKey);
    } catch (e) {
      print('Error clearing last connection: $e');
    }
  }

  // Attempt to reconnect using last saved connection
  Future<bool> attemptAutoReconnect() async {
    final lastConnection = await getLastConnection();
    if (lastConnection != null) {
      final ip = lastConnection['ip'] as String;
      final port = lastConnection['port'] as int;
      return await connect(ip, port: port);
    }
    return false;
  }

  // Connect to Android TV
  Future<bool> connect(String ip, {int port = defaultPort}) async {
    _deviceIP = ip;
    _port = port;

    try {
      final response = await http
          .get(
            Uri.http('$ip:$port', '/api/status'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        _isConnected = true;
        // Save successful connection
        await _saveLastConnection(ip, port);
        return true;
      }
    } catch (e) {
      print('Connection error: $e');
    }

    _isConnected = false;
    return false;
  }

  // Send key command to Android TV
  Future<bool> sendKey(String keyCode) async {
    if (!_isConnected || _deviceIP == null) return false;

    try {
      final response = await http
          .post(
            Uri.http('$_deviceIP:$_port', '/api/command'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'type': 'key', 'code': keyCode}),
          )
          .timeout(timeout);

      return response.statusCode == 200;
    } catch (e) {
      print('Send key error: $e');
      return false;
    }
  }

  // Send text input to Android TV
  Future<bool> sendText(String text) async {
    if (!_isConnected || _deviceIP == null) return false;

    try {
      final response = await http
          .post(
            Uri.http('$_deviceIP:$_port', '/api/command'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'type': 'text', 'text': text}),
          )
          .timeout(timeout);

      return response.statusCode == 200;
    } catch (e) {
      print('Send text error: $e');
      return false;
    }
  }

  // Launch an app on Android TV
  Future<bool> launchApp(String packageName) async {
    if (!_isConnected || _deviceIP == null) return false;

    try {
      final response = await http
          .post(
            Uri.http('$_deviceIP:$_port', '/api/command'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'type': 'launch', 'package': packageName}),
          )
          .timeout(timeout);

      return response.statusCode == 200;
    } catch (e) {
      print('Launch app error: $e');
      return false;
    }
  }

  // Get device information
  Future<Map<String, dynamic>?> getDeviceInfo() async {
    if (!_isConnected || _deviceIP == null) return null;

    try {
      final response = await http
          .get(
            Uri.http('$_deviceIP:$_port', '/api/info'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Get device info error: $e');
    }

    return null;
  }

  // Disconnect from Android TV
  void disconnect() {
    _isConnected = false;
    _deviceIP = null;
    _port = defaultPort;
  }

  // Scan for Android TV devices on local network
  Future<List<String>> scanForDevices() async {
    final List<String> devices = [];
    final String subnet = await _getSubnet();

    if (subnet.isEmpty) return devices;

    final List<Future<void>> futures = [];

    for (int i = 1; i <= 254; i++) {
      final String ip = '$subnet.$i';
      futures.add(_checkDevice(ip, devices));
    }

    await Future.wait(futures);
    return devices;
  }

  Future<void> _checkDevice(String ip, List<String> devices) async {
    try {
      final socket = await Socket.connect(
        ip,
        _port,
        timeout: const Duration(seconds: 2),
      );
      socket.destroy();

      // Try to verify it's an Android TV
      try {
        final response = await http
            .get(Uri.http('$ip:$_port', '/api/status'))
            .timeout(const Duration(seconds: 2));

        if (response.statusCode == 200) {
          devices.add(ip);
        }
      } catch (e) {
        // Ignore HTTP errors during scan
      }
    } catch (e) {
      // Device not reachable
    }
  }

  Future<String> _getSubnet() async {
    try {
      final interfaces = await NetworkInterface.list();
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (address.type == InternetAddressType.IPv4 && !address.isLoopback) {
            final parts = address.address.split('.');
            if (parts.length == 4) {
              return '${parts[0]}.${parts[1]}.${parts[2]}';
            }
          }
        }
      }
    } catch (e) {
      print('Get subnet error: $e');
    }
    return '';
  }
}

// Common Android TV key codes
class TVKeyCode {
  static const String power = 'KEYCODE_POWER';
  static const String home = 'KEYCODE_HOME';
  static const String menu = 'KEYCODE_MENU';
  static const String back = 'KEYCODE_BACK';
  static const String up = 'KEYCODE_DPAD_UP';
  static const String down = 'KEYCODE_DPAD_DOWN';
  static const String left = 'KEYCODE_DPAD_LEFT';
  static const String right = 'KEYCODE_DPAD_RIGHT';
  static const String center = 'KEYCODE_DPAD_CENTER';
  static const String volumeUp = 'KEYCODE_VOLUME_UP';
  static const String volumeDown = 'KEYCODE_VOLUME_DOWN';
  static const String mute = 'KEYCODE_VOLUME_MUTE';
  static const String playPause = 'KEYCODE_MEDIA_PLAY_PAUSE';
  static const String play = 'KEYCODE_MEDIA_PLAY';
  static const String pause = 'KEYCODE_MEDIA_PAUSE';
  static const String stop = 'KEYCODE_MEDIA_STOP';
  static const String next = 'KEYCODE_MEDIA_NEXT';
  static const String previous = 'KEYCODE_MEDIA_PREVIOUS';
  static const String rewind = 'KEYCODE_MEDIA_REWIND';
  static const String fastForward = 'KEYCODE_MEDIA_FAST_FORWARD';
}
