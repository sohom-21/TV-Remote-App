import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/android_tv_service.dart';

class QuickAppsWidget extends StatefulWidget {
  final AndroidTVService tvService;
  final bool isConnected;

  const QuickAppsWidget({
    super.key,
    required this.tvService,
    required this.isConnected,
  });

  @override
  State<QuickAppsWidget> createState() => _QuickAppsWidgetState();
}

class _QuickAppsWidgetState extends State<QuickAppsWidget> {
  final List<AppItem> _popularApps = [
    // System apps (available on Android TV emulator)
    AppItem(
      name: 'YouTube TV',
      packageName: 'com.google.android.youtube.tv',
      icon: Icons.play_circle_filled,
      color: const Color(0xFFFF0000),
    ),
    // Popular streaming apps (may not be installed on emulator)
    AppItem(
      name: 'Netflix',
      packageName: 'com.netflix.ninja',
      icon: Icons.movie,
      color: const Color(0xFFE50914),
    ),
    AppItem(
      name: 'Prime Video',
      packageName: 'com.amazon.amazonvideo.livingroom',
      icon: Icons.video_library,
      color: const Color(0xFF00A8E1),
    ),
    AppItem(
      name: 'JioHotstar',
      packageName: 'in.startv.hotstar',
      icon: Icons.ondemand_video,
      color: const Color(0xFF113CCF),
    ),
    AppItem(
      name: 'Spotify',
      packageName: 'com.spotify.tv.android',
      icon: Icons.music_note,
      color: const Color(0xFF1DB954),
    ),
    AppItem(
      name: 'Plex',
      packageName: 'com.plexapp.android',
      icon: Icons.folder_open,
      color: const Color(0xFFE5A00D),
    ),
    AppItem(
      name: 'Kodi',
      packageName: 'org.xbmc.kodi',
      icon: Icons.play_arrow,
      color: const Color(0xFF17B2E7),
    ),
    AppItem(
      name: 'VLC',
      packageName: 'org.videolan.vlc',
      icon: Icons.play_circle_outline,
      color: const Color(0xFFFF8800),
    ),
    AppItem(
      name: 'TV Settings',
      packageName: 'com.android.tv.settings',
      icon: Icons.settings,
      color: const Color(0xFF607D8B),
    ),
    AppItem(
      name: 'Google Play',
      packageName: 'com.android.vending',
      icon: Icons.store,
      color: const Color(0xFF34A853),
    ),
  ];

  final TextEditingController _packageController = TextEditingController();

  @override
  void dispose() {
    _packageController.dispose();
    super.dispose();
  }

  Future<void> _launchApp(String packageName, String appName) async {
    if (!widget.isConnected) {
      _showNotConnectedSnackBar();
      return;
    }

    HapticFeedback.lightImpact();
    final success = await widget.tvService.launchApp(packageName);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Launched $appName'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to launch $appName'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _launchCustomApp() async {
    final packageName = _packageController.text.trim();
    if (packageName.isEmpty) return;

    await _launchApp(packageName, packageName);
    _packageController.clear();
  }

  void _showNotConnectedSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Not connected to TV'),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Popular Apps
          Text(
            'Popular Apps',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.5,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _popularApps.length,
            itemBuilder: (context, index) {
              final app = _popularApps[index];
              return _buildAppCard(app);
            },
          ),

          const SizedBox(height: 32),

          // Custom App Launch
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Launch Custom App',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Enter the package name of any Android app',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _packageController,
                          decoration: const InputDecoration(
                            hintText: 'e.g., com.example.app',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.apps),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          onSubmitted: (_) => _launchCustomApp(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _launchCustomApp,
                        child: const Text('Launch'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Quick Actions
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Actions',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildQuickActionButton(
                        icon: Icons.home,
                        label: 'Home',
                        onPressed: () async {
                          if (widget.isConnected) {
                            await widget.tvService.sendKey(TVKeyCode.home);
                          } else {
                            _showNotConnectedSnackBar();
                          }
                        },
                      ),
                      _buildQuickActionButton(
                        icon: Icons.app_shortcut,
                        label: 'Recent Apps',
                        onPressed: () async {
                          if (widget.isConnected) {
                            // Send the key code for recent apps (long press home)
                            await widget.tvService.sendKey(
                              'KEYCODE_APP_SWITCH',
                            );
                          } else {
                            _showNotConnectedSnackBar();
                          }
                        },
                      ),
                      _buildQuickActionButton(
                        icon: Icons.search,
                        label: 'Search',
                        onPressed: () async {
                          if (widget.isConnected) {
                            await widget.tvService.sendKey('KEYCODE_SEARCH');
                          } else {
                            _showNotConnectedSnackBar();
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // App Categories
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Common Package Names',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Here are some common package names you can use:',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ..._getCommonPackages().map(
                    (package) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              package['name']!,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: GestureDetector(
                              onTap: () {
                                _packageController.text = package['package']!;
                              },
                              child: Text(
                                package['package']!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.primary,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppCard(AppItem app) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: () => _launchApp(app.packageName, app.name),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [app.color.withOpacity(0.1), app.color.withOpacity(0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: app.color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(app.icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  app.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(
              icon,
              size: 28,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  List<Map<String, String>> _getCommonPackages() {
    return [
      // Available on Android TV Emulator
      {'name': 'TV Settings', 'package': 'com.android.tv.settings'},
      {'name': 'Google Play Store', 'package': 'com.android.vending'},
      {'name': 'YouTube TV', 'package': 'com.google.android.youtube.tv'},
      {'name': 'Google Services', 'package': 'com.google.android.gms'},
      // Popular streaming apps (may need to be installed)
      {'name': 'Netflix', 'package': 'com.netflix.ninja'},
      {'name': 'Prime Video', 'package': 'com.amazon.amazonvideo.livingroom'},
      {'name': 'Disney+', 'package': 'com.disney.disneyplus'},
      {'name': 'Spotify', 'package': 'com.spotify.tv.android'},
      {'name': 'Chrome', 'package': 'com.android.chrome'},
      {'name': 'Twitch', 'package': 'tv.twitch.android.app'},
    ];
  }
}

class AppItem {
  final String name;
  final String packageName;
  final IconData icon;
  final Color color;

  const AppItem({
    required this.name,
    required this.packageName,
    required this.icon,
    required this.color,
  });
}
