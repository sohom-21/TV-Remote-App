### TV Remote App

## Description
TV Remote Control is a Flutter-based mobile application designed to remotely control Android TV emulators over a local network. It allows users to discover compatible devices, establish HTTP connections, and send commands such as navigation, volume control, app launches, and text input. The app features a user-friendly interface with widgets for connection management, quick app access, and a virtual remote control. It operates entirely on the local network, ensuring no data is transmitted externally, and requires permissions for internet access, network state, and WiFi management to function properly.

Key features include:
- Network scanning to find Android TV devices.
- Remote control simulation with buttons for common TV functions.
- Quick access to popular apps.
- Connection history for easy reconnection.
- Minimal data collection: only local storage of connection details.

This app is ideal for developers testing Android TV apps or users wanting a custom remote solution on their local network.

### Steps to Run the Application

1. **Get Packages**
    ```
    flutter pub get
    ```
2. **Start Python Server for testing**
    ```
    python .\server\tv_remote_server.py
    ```

3. **Run the Application**
    ```
    flutter run
    ```
