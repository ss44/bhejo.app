import 'dart:io'; // For exit()
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For rootBundle
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:ghall/core/providers/platforms_provider.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:giphy_get/giphy_get.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with TrayListener, WindowListener {
  final TextEditingController _postController = TextEditingController();
  
  // Platform selection state (Set of Platform IDs)
  final Set<String> _selectedPlatformIds = {};
  final Set<String> _temporarilyDisabledPlatformIds = {};
  
  // Selected media paths
  final List<String> _mediaPaths = [];
  
  int _characterCount = 0;

  @override
  void initState() {
    super.initState();
    trayManager.addListener(this);
    windowManager.addListener(this);
    _postController.addListener(() {
      setState(() {
        _characterCount = _postController.text.length;
      });
    });
    _initTray();
    _initPlatforms();
  }

  Future<void> _initPlatforms() async {
    final platforms = ref.read(platformsProvider);
    bool anyConnected = false;
    
    for (final platform in platforms) {
      await platform.initialize();
      if (await platform.isConnected) {
        anyConnected = true;
        _selectedPlatformIds.add(platform.id);
      }
    }
    
    if (mounted) {
      setState(() {});
      
      // If no platforms are connected, redirect to settings/accounts
      if (!anyConnected) {
        // Small delay to ensure the window is ready
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) context.push('/settings');
        });
      }
    }
  }

  Future<void> _initTray() async {
    String iconPath = 'assets/icon.png';
    
    // On Linux, tray_manager often needs an absolute path to a file on disk
    if (Platform.isLinux) {
      try {
        final byteData = await rootBundle.load('assets/icon.png');
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/ghall_tray_icon.png');
        await file.writeAsBytes(byteData.buffer.asUint8List());
        iconPath = file.path;
      } catch (e) {
        debugPrint('Failed to extract icon: $e');
      }
    }

    // await trayManager.setIcon(iconPath);
    // await trayManager.setToolTip('Ghall');
    
    // Simplified menu without separator to test stability
    /* Menu menu = Menu(
      items: [
        MenuItem(
          key: 'show_window',
          label: 'Show Ghall',
        ),
        MenuItem(
          key: 'exit_app',
          label: 'Exit',
        ),
      ],
    );
    await trayManager.setContextMenu(menu); */
  }

  @override
  void onTrayIconMouseDown() {
    windowManager.show();
    windowManager.focus();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'show_window') {
      windowManager.show();
      windowManager.focus();
    } else if (menuItem.key == 'exit_app') {
      // Remove listener to prevent onWindowClose from intercepting if we used close()
      windowManager.removeListener(this); 
      windowManager.destroy();
      // Ensure the process exits
      exit(0);
    }
  }

  @override
  void onWindowClose() {
    // Instead of closing, hide the window
    windowManager.hide();
  }

  @override
  void dispose() {
    trayManager.removeListener(this);
    windowManager.removeListener(this);
    _postController.dispose();
    super.dispose();
  }

  Future<void> _pickGif() async {
    GiphyGif? gif = await GiphyGet.getGif(
      context: context,
      apiKey: dotenv.env['GIPHY_API_KEY'] ?? '', 
      lang: GiphyLanguage.english,
    );

    if (gif != null) {
      // Just use the URL directly
      final url = gif.images?.original?.url;
      if (url != null) {
        setState(() {
          _mediaPaths.add(url);
          _validatePlatformConstraints();
        });
      }
    }
  }

  Future<void> _pickMedia() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.media,
      allowMultiple: true,
    );

    if (result != null) {
      setState(() {
        for (var file in result.files) {
          if (file.path != null) {
            _mediaPaths.add(file.path!);
          }
        }
        _validatePlatformConstraints();
      });
    }
  }

  void _removeMedia(int index) {
    setState(() {
      _mediaPaths.removeAt(index);
      _validatePlatformConstraints();
    });
  }

  void _validatePlatformConstraints() {
    // Bluesky limit: 4 images
    if (_mediaPaths.length > 4) {
      if (_selectedPlatformIds.contains('bluesky')) {
        _selectedPlatformIds.remove('bluesky');
        _temporarilyDisabledPlatformIds.add('bluesky');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bluesky allows max 4 images. Temporarily deselected.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } else {
      // Re-enable if it was temporarily disabled
      if (_temporarilyDisabledPlatformIds.contains('bluesky')) {
        _selectedPlatformIds.add('bluesky');
        _temporarilyDisabledPlatformIds.remove('bluesky');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image count within limits. Re-selected Bluesky.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _handlePost() async {
    final content = _postController.text;
    if (content.isEmpty) return;
    
    if (_selectedPlatformIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one platform')),
      );
      return;
    }

    final platforms = ref.read(platformsProvider)
        .where((p) => _selectedPlatformIds.contains(p.id));

    int successCount = 0;
    List<String> errors = [];

    // Show loading indicator or disable button here if desired

    for (final platform in platforms) {
      try {
        await platform.post(content, mediaPaths: _mediaPaths);
        successCount++;
      } catch (e) {
        errors.add('${platform.name}: $e');
      }
    }

    if (mounted) {
      if (errors.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Posted successfully to $successCount platform(s)!')),
        );
        _postController.clear();
        setState(() {
          _mediaPaths.clear();
        });
        // Optional: Hide window on success
        // windowManager.hide();
      } else {
        // Show errors
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errors: ${errors.join(", ")}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: Colors.deepPurple,
            child: Icon(Icons.share, color: Colors.white, size: 20),
          ),
        ),
        title: const Text('Ghall'),
        actions: [
          IconButton(
            icon: const Icon(Icons.manage_accounts),
            tooltip: 'Accounts',
            onPressed: () {
              context.push('/settings');
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Composer Area
            Expanded(
              child: TextField(
                controller: _postController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: 'What do you want to say?',
                  border: OutlineInputBorder(),
                  filled: true,
                ),
              ),
            ),
            
            const Gap(12),

            // Media Preview
            if (_mediaPaths.isNotEmpty)
              SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _mediaPaths.length,
                  separatorBuilder: (context, index) => const Gap(8),
                  itemBuilder: (context, index) {
                    final path = _mediaPaths[index];
                    final isNetwork = path.startsWith('http');
                    final isVideo = !isNetwork && ['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(path.split('.').last.toLowerCase());
                    return Stack(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: isNetwork
                              ? Image.network(path, fit: BoxFit.cover)
                              : (isVideo
                                  ? const Center(child: Icon(Icons.videocam, size: 40))
                                  : Image.file(File(path), fit: BoxFit.cover)),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => _removeMedia(index),
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(4),
                              child: const Icon(Icons.close, color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            
            if (_mediaPaths.isNotEmpty) const Gap(12),

            // Media Buttons
            Row(
              children: [
                IconButton.filledTonal(
                  onPressed: _pickGif,
                  icon: const Icon(Icons.gif),
                  tooltip: 'Add GIF',
                ),
                const Gap(8),
                IconButton.filledTonal(
                  onPressed: _pickMedia,
                  icon: const Icon(Icons.image),
                  tooltip: 'Add Image/Video',
                ),
                const Spacer(),
                Text(
                  '$_characterCount chars',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _characterCount > 280 ? Colors.red : null,
                  ),
                ),
              ],
            ),

            const Gap(12),

            // Platform Selection (Checkboxes)
            const Text('Post to:', style: TextStyle(fontWeight: FontWeight.bold)),
            Consumer(
              builder: (context, ref, child) {
                final platforms = ref.watch(platformsProvider);
                return Wrap(
                  spacing: 8,
                  children: platforms.map((platform) {
                    final isSelected = _selectedPlatformIds.contains(platform.id);
                    return FilterChip(
                      label: Text(platform.name),
                      selected: isSelected,
                      onSelected: (val) {
                        setState(() {
                          if (val) {
                            // Check constraints before selecting
                            if (platform.id == 'bluesky' && _mediaPaths.length > 4) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Cannot select Bluesky: Max 4 images allowed.'),
                                ),
                              );
                              return;
                            }
                            _selectedPlatformIds.add(platform.id);
                            _temporarilyDisabledPlatformIds.remove(platform.id);
                          } else {
                            _selectedPlatformIds.remove(platform.id);
                            _temporarilyDisabledPlatformIds.remove(platform.id);
                          }
                        });
                      },
                      avatar: isSelected ? const Icon(Icons.check, size: 18) : null,
                    );
                  }).toList(),
                );
              },
            ),
            
            const Gap(16),
            
            // Action Button
            FilledButton.icon(
              onPressed: _handlePost,
              icon: const Icon(Icons.send),
              label: const Text('Post Now!'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
