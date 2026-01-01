import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bhejo/core/providers/platforms_provider.dart';
import 'package:bhejo/core/interfaces/social_platform.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _storage = const FlutterSecureStorage();

  Future<void> _handleConnect(SocialPlatform platform) async {
    if (platform.id == 'bluesky') {
      await _showBlueskyLoginDialog(platform);
    }
    // Add other platforms here
    setState(() {}); // Refresh UI to show connected status
  }

  Future<void> _handleDisconnect(SocialPlatform platform) async {
    await platform.logout();
    // Delete the specific keys we used for storage
    await _storage.delete(key: '${platform.id}_identifier');
    await _storage.delete(key: '${platform.id}_password');
    setState(() {});
  }

  Future<void> _showBlueskyLoginDialog(SocialPlatform platform) async {
    final identifierController = TextEditingController();
    final passwordController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connect to Bluesky'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: identifierController,
              decoration: const InputDecoration(
                labelText: 'Handle (e.g. user.bsky.social)',
                hintText: 'user.bsky.social',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(
                labelText: 'App Password',
                helperText: 'Get this from Settings > App Passwords',
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                final creds = {
                  'identifier': identifierController.text.trim(),
                  'password': passwordController.text.trim(),
                };
                
                await platform.login(creds);
                
                // Save to secure storage if login successful
                // We'll store as a simple comma-separated string for now or JSON
                // For simplicity in this prototype:
                await _storage.write(
                  key: '${platform.id}_identifier', 
                  value: creds['identifier']
                );
                await _storage.write(
                  key: '${platform.id}_password', 
                  value: creds['password']
                );

                if (mounted) Navigator.pop(context);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Login failed: $e')),
                  );
                }
              }
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final platforms = ref.watch(platformsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
      ),
      body: ListView.builder(
        itemCount: platforms.length,
        itemBuilder: (context, index) {
          final platform = platforms[index];
          return FutureBuilder<bool>(
            future: platform.isConnected,
            builder: (context, snapshot) {
              final isConnected = snapshot.data ?? false;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: isConnected ? Colors.green : Colors.grey,
                  child: const Icon(Icons.cloud, color: Colors.white),
                ),
                title: Text(platform.name),
                subtitle: Text(isConnected ? 'Connected' : 'Not connected'),
                trailing: isConnected
                    ? OutlinedButton(
                        onPressed: () => _handleDisconnect(platform),
                        child: const Text('Disconnect'),
                      )
                    : FilledButton(
                        onPressed: () => _handleConnect(platform),
                        child: const Text('Connect'),
                      ),
              );
            },
          );
        },
      ),
    );
  }
}
