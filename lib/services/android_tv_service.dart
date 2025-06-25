import 'dart:async';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

class AndroidTVService {
  static const int defaultPort = 5555; // ADB port for real Android TV
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

  // Connect to Android TV via ADB
  Future<bool> connect(String ip, {int port = defaultPort}) async {
    _deviceIP = ip;
    _port = port;

    try {
      // Try to connect via socket first to check if ADB port is open
      final socket = await Socket.connect(ip, port, timeout: timeout);
      socket.destroy();

      _isConnected = true;
      // Save successful connection
      await _saveLastConnection(ip, port);
      print('Connected to Android TV at $ip:$port');
      return true;
    } catch (e) {
      print('Connection error: $e');
      _isConnected = false;
      return false;
    }
  }

  // Send key command via ADB
  Future<bool> sendKey(String keyCode) async {
    if (!_isConnected || _deviceIP == null) return false;

    try {
      // Use adb shell input keyevent command
      final result = await Process.run('adb', ['connect', '$_deviceIP:$_port']);

      if (result.exitCode != 0) {
        print('ADB connect failed: ${result.stderr}');
        return false;
      }

      // Send keyevent
      final keyResult = await Process.run('adb', [
        '-s',
        '$_deviceIP:$_port',
        'shell',
        'input',
        'keyevent',
        _getKeyCode(keyCode),
      ]);

      return keyResult.exitCode == 0;
    } catch (e) {
      print('Send key error: $e');
      return false;
    }
  }

  // Send text input via ADB
  Future<bool> sendText(String text) async {
    if (!_isConnected || _deviceIP == null) return false;

    try {
      final result = await Process.run('adb', [
        '-s',
        '$_deviceIP:$_port',
        'shell',
        'input',
        'text',
        '"$text"',
      ]);

      return result.exitCode == 0;
    } catch (e) {
      print('Send text error: $e');
      return false;
    }
  }

  // Launch an app via ADB
  Future<bool> launchApp(String packageName) async {
    if (!_isConnected || _deviceIP == null) return false;

    try {
      List<String> args = ['-s', '$_deviceIP:$_port', 'shell', 'am', 'start'];

      // Special handling for TV Settings
      if (packageName == 'com.android.tv.settings') {
        args.addAll(['-a', 'android.settings.SETTINGS']);
      } else {
        args.addAll([
          '-a',
          'android.intent.action.MAIN',
          '-c',
          'android.intent.category.LAUNCHER',
          packageName,
        ]);
      }

      final result = await Process.run('adb', args);

      if (result.exitCode == 0) {
        return true;
      }

      // Fallback: Try monkey command
      final monkeyResult = await Process.run('adb', [
        '-s',
        '$_deviceIP:$_port',
        'shell',
        'monkey',
        '-p',
        packageName,
        '1',
      ]);

      return monkeyResult.exitCode == 0;
    } catch (e) {
      print('Launch app error: $e');
      return false;
    }
  }

  // Get device information via ADB
  Future<Map<String, dynamic>?> getDeviceInfo() async {
    if (!_isConnected || _deviceIP == null) return null;

    try {
      final modelResult = await Process.run('adb', [
        '-s',
        '$_deviceIP:$_port',
        'shell',
        'getprop',
        'ro.product.model',
      ]);

      final manufacturerResult = await Process.run('adb', [
        '-s',
        '$_deviceIP:$_port',
        'shell',
        'getprop',
        'ro.product.manufacturer',
      ]);

      final versionResult = await Process.run('adb', [
        '-s',
        '$_deviceIP:$_port',
        'shell',
        'getprop',
        'ro.build.version.release',
      ]);

      return {
        'name': 'Android TV',
        'model': modelResult.stdout.toString().trim(),
        'manufacturer': manufacturerResult.stdout.toString().trim(),
        'version': 'Android ${versionResult.stdout.toString().trim()}',
        'ip': _deviceIP,
        'port': _port,
      };
    } catch (e) {
      print('Get device info error: $e');
      return null;
    }
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
    final List<String> subnets = await _getAllSubnets();

    if (subnets.isEmpty) return devices;

    print('Scanning subnets: $subnets');

    final List<Future<void>> futures = [];

    // Scan all detected subnets for port 5555 (ADB)
    for (final subnet in subnets) {
      for (int i = 1; i <= 254; i++) {
        final String ip = '$subnet.$i';
        futures.add(_checkDevice(ip, devices));
      }
    }

    await Future.wait(futures);

    return devices;
  }

  Future<void> _checkDevice(String ip, List<String> devices) async {
    try {
      // Try to connect via socket to check if ADB port 5555 is open
      final socket = await Socket.connect(
        ip,
        5555,
        timeout: const Duration(seconds: 2),
      );
      socket.destroy();

      print('Found Android TV at $ip:5555');
      devices.add(ip);
    } catch (e) {
      // Port not open or device not reachable
    }
  }

  // Convert key name to Android key code number
  String _getKeyCode(String keyName) {
    const keyMap = {
      'KEYCODE_POWER': '26',
      'KEYCODE_HOME': '3',
      'KEYCODE_MENU': '82',
      'KEYCODE_BACK': '4',
      'KEYCODE_DPAD_UP': '19',
      'KEYCODE_DPAD_DOWN': '20',
      'KEYCODE_DPAD_LEFT': '21',
      'KEYCODE_DPAD_RIGHT': '22',
      'KEYCODE_DPAD_CENTER': '23',
      'KEYCODE_VOLUME_UP': '24',
      'KEYCODE_VOLUME_DOWN': '25',
      'KEYCODE_VOLUME_MUTE': '164',
      'KEYCODE_MEDIA_PLAY_PAUSE': '85',
      'KEYCODE_MEDIA_PLAY': '126',
      'KEYCODE_MEDIA_PAUSE': '127',
      'KEYCODE_MEDIA_STOP': '86',
      'KEYCODE_MEDIA_NEXT': '87',
      'KEYCODE_MEDIA_PREVIOUS': '88',
      'KEYCODE_MEDIA_REWIND': '89',
      'KEYCODE_MEDIA_FAST_FORWARD': '90',
      'KEYCODE_SEARCH': '84',
      'KEYCODE_APP_SWITCH': '187',
    };

    return keyMap[keyName] ?? '23'; // Default to center/enter
  }

  Future<List<String>> _getAllSubnets() async {
    final List<String> subnets = [];

    try {
      final interfaces = await NetworkInterface.list();
      for (final interface in interfaces) {
        print('Interface: ${interface.name}');

        for (final address in interface.addresses) {
          if (address.type == InternetAddressType.IPv4 && !address.isLoopback) {
            final parts = address.address.split('.');
            if (parts.length == 4) {
              final subnet = '${parts[0]}.${parts[1]}.${parts[2]}';
              if (!subnets.contains(subnet)) {
                subnets.add(subnet);
                print('Added subnet: $subnet from ${address.address}');
              }
            }
          }
        }
      }
    } catch (e) {
      print('Get subnets error: $e');
    }

    // Add common hotspot subnets if not already present
    final commonSubnets = [
      '192.168.43', // Android hotspot
      '192.168.137', // Windows hotspot
      '172.20.10', // iOS hotspot
      '10.0.2', // Android emulator
      '192.168.1', // Common home network
      '192.168.0', // Common home network
    ];

    for (final subnet in commonSubnets) {
      if (!subnets.contains(subnet)) {
        subnets.add(subnet);
      }
    }

    return subnets;
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
