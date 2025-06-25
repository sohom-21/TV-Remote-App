#!/usr/bin/env python3
"""
Simple HTTP server for Android TV Remote Control
This server simulates an Android TV that can receive remote control commands.
"""

import json
import subprocess
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse, parse_qs
import threading
import time

class TVRemoteHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        """Handle GET requests"""
        path = urlparse(self.path).path
        
        if path == '/api/status':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            
            response = {
                'status': 'connected',
                'device': 'Android TV Emulator',
                'model': 'AOSP TV x86',
                'manufacturer': 'Google',
                'version': 'Android 16'
            }
            self.wfile.write(json.dumps(response).encode())
            
        elif path == '/api/info':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            
            response = {
                'name': 'Android TV Emulator',
                'model': 'AOSP TV x86',
                'manufacturer': 'Google',
                'version': 'Android 16',
                'ip': '127.0.0.1',
                'port': 8080
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
    
    def execute_command(self, command):
        """Execute the received command"""
        try:
            cmd_type = command.get('type')
            
            if cmd_type == 'key':
                key_code = command.get('code')
                print(f"Sending key: {key_code}")
                
                # Use ADB to send key event to the TV emulator
                adb_command = [
                    r"C:\Users\ritwi\AppData\Local\Android\sdk\platform-tools\adb.exe",
                    '-s', 'emulator-5556',  # TV emulator device ID
                    'shell', 'input', 'keyevent', self.get_key_code(key_code)
                ]
                
                result = subprocess.run(adb_command, capture_output=True, text=True)
                return result.returncode == 0
                
            elif cmd_type == 'text':
                text = command.get('text')
                print(f"Sending text: {text}")
                
                # Use ADB to send text input to the TV emulator
                adb_command = [
                    r"C:\Users\ritwi\AppData\Local\Android\sdk\platform-tools\adb.exe",
                    '-s', 'emulator-5556',  # TV emulator device ID
                    'shell', 'input', 'text', f'"{text}"'
                ]
                
                result = subprocess.run(adb_command, capture_output=True, text=True)
                return result.returncode == 0            
            elif cmd_type == 'launch':
                package = command.get('package')
                print(f"Launching app: {package}")
                
                # Special handling for specific apps that need different intents
                if package == 'com.android.tv.settings':
                    print("Launching TV Settings with settings intent...")
                    adb_command = [
                        r"C:\Users\ritwi\AppData\Local\Android\sdk\platform-tools\adb.exe",
                        '-s', 'emulator-5556',
                        'shell', 'am', 'start', '-a', 'android.settings.SETTINGS'
                    ]
                    result = subprocess.run(adb_command, capture_output=True, text=True)
                    print(f"TV Settings result: {result.returncode}")
                    if result.stdout:
                        print(f"Output: {result.stdout}")
                    return result.returncode == 0
                
                else:
                    # Universal launch method for all other apps
                    print(f"Launching {package} with generic method...")
                    adb_command = [
                        r"C:\Users\ritwi\AppData\Local\Android\sdk\platform-tools\adb.exe",
                        '-s', 'emulator-5556',
                        'shell', 'am', 'start',
                        '-a', 'android.intent.action.MAIN',
                        '-c', 'android.intent.category.LAUNCHER',
                        package
                    ]
                    
                    result = subprocess.run(adb_command, capture_output=True, text=True)
                    print(f"Launch result: {result.returncode}")
                    if result.stdout:
                        print(f"Output: {result.stdout}")
                    if result.stderr:
                        print(f"Error: {result.stderr}")
                    
                    if result.returncode == 0:
                        return True
                    
                    # Fallback: Try monkey for apps that don't respond to generic method
                    print(f"Generic method failed, trying monkey for {package}...")
                    adb_monkey = [
                        r"C:\Users\ritwi\AppData\Local\Android\sdk\platform-tools\adb.exe",
                        '-s', 'emulator-5556',
                        'shell', 'monkey', '-p', package, '1'
                    ]
                    
                    monkey_result = subprocess.run(adb_monkey, capture_output=True, text=True)
                    print(f"Monkey result: {monkey_result.returncode}")
                    
                    if monkey_result.returncode == 0 and "monkey aborted" not in monkey_result.stderr.lower():
                        return True
                    
                    print(f"All launch methods failed for {package}")
                    return False
                
            return False
            
        except Exception as e:
            print(f"Error executing command: {e}")
            return False
    
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
    server_address = ('localhost', 8080)
    httpd = HTTPServer(server_address, TVRemoteHandler)
    
    print("Starting Android TV Remote Server...")
    print(f"Server running on http://{server_address[0]}:{server_address[1]}")
    print("Ready to receive remote control commands!")
    print("Press Ctrl+C to stop the server")
    
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down the server...")
        httpd.shutdown()

if __name__ == '__main__':
    main()
