import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/android_tv_service.dart';

class RemoteControlWidget extends StatefulWidget {
  final AndroidTVService tvService;
  final bool isConnected;

  const RemoteControlWidget({
    super.key,
    required this.tvService,
    required this.isConnected,
  });

  @override
  State<RemoteControlWidget> createState() => _RemoteControlWidgetState();
}

class _RemoteControlWidgetState extends State<RemoteControlWidget> {
  final TextEditingController _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _sendCommand(String keyCode) async {
    if (!widget.isConnected) {
      _showNotConnectedSnackBar();
      return;
    }

    HapticFeedback.lightImpact();
    final success = await widget.tvService.sendKey(keyCode);

    if (!success) {
      _showErrorSnackBar('Failed to send command');
    }
  }

  Future<void> _sendText() async {
    if (!widget.isConnected) {
      _showNotConnectedSnackBar();
      return;
    }

    final text = _textController.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.lightImpact();
    final success = await widget.tvService.sendText(text);

    if (success) {
      _textController.clear();
    } else {
      _showErrorSnackBar('Failed to send text');
    }
  }

  void _showNotConnectedSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Not connected to TV'),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Power and Home buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildCircularButton(
                icon: Icons.power_settings_new,
                label: 'Power',
                onPressed: () => _sendCommand(TVKeyCode.power),
                color: Colors.red,
              ),
              _buildCircularButton(
                icon: Icons.home,
                label: 'Home',
                onPressed: () => _sendCommand(TVKeyCode.home),
                color: Colors.blue,
              ),
              _buildCircularButton(
                icon: Icons.menu,
                label: 'Menu',
                onPressed: () => _sendCommand(TVKeyCode.menu),
                color: Colors.green,
              ),
            ],
          ),

          const SizedBox(height: 32),

          // D-Pad Navigation
          Column(
            children: [
              // Up button
              _buildNavigationButton(
                icon: Icons.keyboard_arrow_up,
                onPressed: () => _sendCommand(TVKeyCode.up),
              ),

              // Left, Center, Right buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildNavigationButton(
                    icon: Icons.keyboard_arrow_left,
                    onPressed: () => _sendCommand(TVKeyCode.left),
                  ),
                  const SizedBox(width: 8),
                  _buildNavigationButton(
                    icon: Icons.radio_button_checked,
                    onPressed: () => _sendCommand(TVKeyCode.center),
                    isCenter: true,
                  ),
                  const SizedBox(width: 8),
                  _buildNavigationButton(
                    icon: Icons.keyboard_arrow_right,
                    onPressed: () => _sendCommand(TVKeyCode.right),
                  ),
                ],
              ),

              // Down button
              _buildNavigationButton(
                icon: Icons.keyboard_arrow_down,
                onPressed: () => _sendCommand(TVKeyCode.down),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Back button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _sendCommand(TVKeyCode.back),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Volume Controls
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Volume Control',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildVolumeButton(
                        icon: Icons.volume_down,
                        label: 'Vol -',
                        onPressed: () => _sendCommand(TVKeyCode.volumeDown),
                      ),
                      _buildVolumeButton(
                        icon: Icons.volume_mute,
                        label: 'Mute',
                        onPressed: () => _sendCommand(TVKeyCode.mute),
                      ),
                      _buildVolumeButton(
                        icon: Icons.volume_up,
                        label: 'Vol +',
                        onPressed: () => _sendCommand(TVKeyCode.volumeUp),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Media Controls
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Media Control',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildMediaButton(
                        icon: Icons.skip_previous,
                        onPressed: () => _sendCommand(TVKeyCode.previous),
                      ),
                      _buildMediaButton(
                        icon: Icons.fast_rewind,
                        onPressed: () => _sendCommand(TVKeyCode.rewind),
                      ),
                      _buildMediaButton(
                        icon: Icons.play_arrow,
                        onPressed: () => _sendCommand(TVKeyCode.playPause),
                        isPrimary: true,
                      ),
                      _buildMediaButton(
                        icon: Icons.fast_forward,
                        onPressed: () => _sendCommand(TVKeyCode.fastForward),
                      ),
                      _buildMediaButton(
                        icon: Icons.skip_next,
                        onPressed: () => _sendCommand(TVKeyCode.next),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Text Input
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Text Input',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          decoration: const InputDecoration(
                            hintText: 'Type to send to TV...',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          onSubmitted: (_) => _sendText(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _sendText,
                        child: const Text('Send'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircularButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: color ?? Theme.of(context).colorScheme.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildNavigationButton({
    required IconData icon,
    required VoidCallback onPressed,
    bool isCenter = false,
  }) {
    return Container(
      width: isCenter ? 80 : 60,
      height: isCenter ? 80 : 60,
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color:
            isCenter
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(isCenter ? 40 : 30),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          icon,
          size: isCenter ? 32 : 28,
          color:
              isCenter ? Colors.white : Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildVolumeButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Column(
      children: [
        IconButton(
          onPressed: onPressed,
          icon: Icon(icon, size: 32),
          style: IconButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.surface,
            padding: const EdgeInsets.all(16),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildMediaButton({
    required IconData icon,
    required VoidCallback onPressed,
    bool isPrimary = false,
  }) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 28),
      style: IconButton.styleFrom(
        backgroundColor:
            isPrimary
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.surface,
        foregroundColor:
            isPrimary ? Colors.white : Theme.of(context).colorScheme.onSurface,
        padding: const EdgeInsets.all(12),
      ),
    );
  }
}
