#!/usr/bin/env python3
"""
Android TV Remote Server for Emulator
This server receives HTTP requests from the Flutter app and sends ADB commands to the Android TV emulator.
"""

import json
import subprocess
import sys
import socket
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse

class TVRemoteHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        """Handle GET requests"""
        path = urlparse(self.path).path
        
        if path == '/api/status':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            
            # Get computer's IP for network info
            local_ip = self.get_local_ip()
            
            response = {
                'status': 'connected',
                'device': 'Android TV Emulator',
                'model': 'AOSP TV x86',
                'manufacturer': 'Google',
                'version': 'Android TV',
                'ip': local_ip,
                'port': 8080,
                'emulator_status': self.check_emulator_status()
            }
            self.wfile.write(json.dumps(response).encode())
            
        elif path == '/api/info':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            
            local_ip = self.get_local_ip()
            
            response = {
                'name': 'Android TV Emulator',
                'model': 'AOSP TV x86',
                'manufacturer': 'Google',
                'version': 'Android TV',
                'ip': local_ip,
                'port': 8080,
                'connection_type': 'emulator_bridge'
            }
            self.wfile.write(json.dumps(response).encode())
            
        else:
            self.send_response(404)
            self.end_headers()
    
    def do_POST(self):
        """Handle POST requests"""
        path = urlparse(self.path).path
        
        if path == '/api/command':
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            
            try:
                command = json.loads(post_data.decode())
                print(f"Received command: {command}")
                
                success = self.execute_command(command)
                
                self.send_response(200 if success else 500)
                self.send_header('Content-type', 'application/json')
                self.send_header('Access-Control-Allow-Origin', '*')
                self.end_headers()
                
                response = {
                    'success': success,
                    'command': command
                }
                self.wfile.write(json.dumps(response).encode())
                
            except json.JSONDecodeError:
                self.send_response(400)
                self.end_headers()
        
        else:
            self.send_response(404)
            self.end_headers()
    
    def do_OPTIONS(self):
        """Handle OPTIONS requests for CORS"""
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()
    
    def get_local_ip(self):
        """Get the local IP address of this computer"""
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.connect(("8.8.8.8", 80))
            local_ip = s.getsockname()[0]
            s.close()
            return local_ip
        except Exception:
            return "127.0.0.1"
    
    def get_adb_path(self):
        """Get the working ADB path"""
        adb_paths = [
            "adb",
            r"C:\Users\ritwi\AppData\Local\Android\Sdk\platform-tools\adb.exe",
            r"C:\Android\Sdk\platform-tools\adb.exe"
        ]
        
        for adb_path in adb_paths:
            try:
                result = subprocess.run([adb_path, "version"], capture_output=True, text=True, timeout=5)
                if result.returncode == 0:
                    return adb_path
            except:
                continue
        return None

    def check_emulator_status(self):
        """Check if the Android TV emulator is running"""
        try:
            adb_path = self.get_adb_path()
            if not adb_path:
                print("ADB not found in system")
                return False
            
            result = subprocess.run([
                adb_path, "devices"
            ], capture_output=True, text=True, timeout=5)
            
            if result.returncode == 0:
                print(f"ADB found at: {adb_path}")
                print(f"Connected devices:\n{result.stdout}")
                
                # Look for TV emulator device (prefer emulator-5556)
                lines = result.stdout.split('\n')
                
                # First check for TV emulator specifically
                for line in lines:
                    if 'emulator-5556' in line and 'device' in line:
                        print("Android TV emulator (5556) found and ready")
                        return True
                
                # Fallback: any emulator
                for line in lines:
                    if 'emulator-' in line and 'device' in line:
                        emulator_id = line.split('\t')[0]
                        print(f"Found emulator: {emulator_id} (may not be TV emulator)")
                        return True
                        
                print("No Android TV emulator found")
                return False
            else:
                print(f"ADB command failed: {result.stderr}")
                return False
        except Exception as e:
            print(f"Error checking emulator status: {e}")
            return False
    
    def execute_command(self, command):
        """Execute the received command via ADB"""
        try:
            cmd_type = command.get('type')
            
            if cmd_type == 'key':
                key_code = command.get('code')
                print(f"Sending key: {key_code}")
                
                # Find active emulator
                emulator_id = self.get_emulator_id()
                if not emulator_id:
                    print("No active emulator found")
                    return False
                
                # Send key event to emulator
                adb_path = self.get_adb_path()
                if not adb_path:
                    print("ADB not found")
                    return False
                    
                adb_command = [
                    adb_path, "-s", emulator_id,
                    "shell", "input", "keyevent", self.get_key_code(key_code)
                ]
                
                result = subprocess.run(adb_command, capture_output=True, text=True, timeout=10)
                
                if result.returncode == 0:
                    print(f"✓ Key {key_code} sent successfully")
                    return True
                else:
                    print(f"✗ Failed to send key: {result.stderr}")
                    return False
                
            elif cmd_type == 'text':
                text = command.get('text')
                print(f"Sending text: {text}")
                
                emulator_id = self.get_emulator_id()
                if not emulator_id:
                    return False
                
                # Send text input to emulator
                adb_path = self.get_adb_path()
                if not adb_path:
                    return False
                    
                adb_command = [
                    adb_path, "-s", emulator_id,
                    "shell", "input", "text", f'"{text}"'
                ]
                
                result = subprocess.run(adb_command, capture_output=True, text=True, timeout=10)
                return result.returncode == 0
                
            elif cmd_type == 'launch':
                package = command.get('package')
                print(f"Launching app: {package}")
                
                emulator_id = self.get_emulator_id()
                if not emulator_id:
                    return False
                
                # Special handling for TV Settings
                adb_path = self.get_adb_path()
                if not adb_path:
                    return False
                    
                if package == 'com.android.tv.settings':
                    adb_command = [
                        adb_path, "-s", emulator_id,
                        "shell", "am", "start", "-a", "android.settings.SETTINGS"
                    ]
                else:
                    # Universal launch method
                    adb_command = [
                        adb_path, "-s", emulator_id,
                        "shell", "am", "start",
                        "-a", "android.intent.action.MAIN",
                        "-c", "android.intent.category.LAUNCHER",
                        package
                    ]
                
                result = subprocess.run(adb_command, capture_output=True, text=True, timeout=10)
                
                if result.returncode == 0:
                    print(f"✓ App {package} launched successfully")
                    return True
                else:
                    print(f"✗ Failed to launch app: {result.stderr}")
                    
                    # Fallback: Try monkey
                    print(f"Trying monkey for {package}...")
                    monkey_command = [
                        adb_path, "-s", emulator_id,
                        "shell", "monkey", "-p", package, "1"
                    ]
                    
                    monkey_result = subprocess.run(monkey_command, capture_output=True, text=True, timeout=10)
                    if monkey_result.returncode == 0:
                        print(f"✓ App launched via monkey")
                        return True
                    
                    return False
                
            return False
            
        except Exception as e:
            print(f"Error executing command: {e}")
            return False
    
    def get_emulator_id(self):
        """Get the TV emulator device ID (prioritize 5556 for Android TV)"""
        try:
            adb_path = self.get_adb_path()
            if not adb_path:
                return None
                
            result = subprocess.run([
                adb_path, "devices"
            ], capture_output=True, text=True, timeout=5)
            
            lines = result.stdout.split('\n')
            
            # First, look specifically for emulator-5556 (Android TV emulator)
            for line in lines:
                if 'emulator-5556' in line and 'device' in line:
                    print("Found Android TV emulator: emulator-5556")
                    return 'emulator-5556'
            
            # If not found, look for any emulator but prefer higher numbers (likely TV)
            emulators = []
            for line in lines:
                if 'emulator-' in line and 'device' in line:
                    emulator_id = line.split('\t')[0]
                    emulators.append(emulator_id)
            
            if emulators:
                # Sort by emulator number, prefer higher numbers (TV emulators typically use 5556+)
                emulators.sort(reverse=True)
                selected = emulators[0]
                print(f"Selected emulator: {selected} from available: {emulators}")
                return selected
            
            print("No emulator found")
            return None
        except Exception as e:
            print(f"Error getting emulator ID: {e}")
            return None
    
    def get_key_code(self, key_name):
        """Convert key name to Android key code number"""
        key_codes = {
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
        }
        
        return key_codes.get(key_name, '23')  # Default to center/enter
    
    def log_message(self, format, *args):
        """Override to customize logging"""
        print(f"[{self.date_time_string()}] {format % args}")

def main():
    # Get local IP address
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        local_ip = s.getsockname()[0]
        s.close()
    except Exception:
        local_ip = "127.0.0.1"
    
    # Start server on all interfaces
    server_address = ('0.0.0.0', 8080)  # Listen on all interfaces
    httpd = HTTPServer(server_address, TVRemoteHandler)
    
    print("Android TV Remote Server for Emulator")
    print("=" * 40)
    print(f"✓ Server running on http://{local_ip}:8080")
    print(f"✓ Local access: http://127.0.0.1:8080")
    print(f"✓ Network access: http://{local_ip}:8080")
    print("✓ Ready to receive remote control commands!")
    print()
    print("Make sure:")
    print("- Your Android TV emulator is running")
    print("- ADB is available in your system PATH")
    print("- Your phone and computer are on the same network")
    print()
    print("Press Ctrl+C to stop the server")
    
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down the server...")
        httpd.shutdown()

if __name__ == '__main__':
    main()