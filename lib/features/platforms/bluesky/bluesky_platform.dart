import 'dart:io';
import 'dart:typed_data';
import 'package:bluesky/bluesky.dart' as bsky;
import 'package:bluesky/app_bsky_embed_images.dart';
import 'package:bluesky/app_bsky_embed_video.dart';
import 'package:bluesky/app_bsky_embed_external.dart';
import 'package:bluesky/app_bsky_feed_post.dart';
import 'package:atproto/atproto.dart' as atproto;
import 'package:bhejo/core/interfaces/social_platform.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image/image.dart' as img;

class BlueskyPlatform implements SocialPlatform {
  bsky.Bluesky? _client;
  final _storage = const FlutterSecureStorage();

  @override
  String get id => 'bluesky';

  @override
  String get name => 'Bluesky';

  @override
  String get iconAsset => 'assets/icons/bluesky.png'; // Placeholder

  @override
  Future<bool> get isConnected async => _client != null;

  @override
  Future<void> initialize() async {
    try {
      final identifier = await _storage.read(key: '${id}_identifier');
      final password = await _storage.read(key: '${id}_password');

      if (identifier != null && password != null) {
        await login({'identifier': identifier, 'password': password});
      }
    } catch (e) {
      // Failed to restore session, maybe credentials changed or network issue
      print('Failed to restore Bluesky session: $e');
    }
  }

  @override
  Future<void> login(Map<String, String> credentials) async {
    final identifier = credentials['identifier'];
    final password = credentials['password'];

    if (identifier == null || password == null) {
      throw Exception('Missing identifier or password');
    }

    // Create a session
    final session = await atproto.createSession(
      service: 'bsky.social',
      identifier: identifier,
      password: password,
    );

    // Initialize the client with the session
    _client = bsky.Bluesky.fromSession(session.data);
  }

  @override
  Future<void> logout() async {
    _client = null;
  }

  @override
  Future<void> post(String content, {List<String>? mediaPaths}) async {
    if (_client == null) {
      throw Exception('Not connected to Bluesky');
    }

    UFeedPostEmbed? embed;

    if (mediaPaths != null && mediaPaths.isNotEmpty) {
      // Check if it's a URL (External Embed)
      if (mediaPaths.first.startsWith('http')) {
        final url = mediaPaths.first;
        
        // For now, we just create an external embed with the URL.
        // Ideally, we should fetch OG tags (title, description, thumb).
        // Since we don't have them, we'll use placeholders or just the URL.
        // Note: Bluesky might require a thumb blob for external embeds to look good.
        
        embed = UFeedPostEmbed.embedExternal(
          data: EmbedExternal(
            external: EmbedExternalExternal(
              uri: url,
              title: 'GIF from Giphy',
              description: 'Shared via Bhejo',
              // thumb: blob, // We need to upload a thumb blob if we want an image
            ),
          ),
        );
      } else {
        final isVideo = _isVideoFile(mediaPaths.first);

        if (isVideo) {
          if (mediaPaths.length > 1) {
            throw Exception('Bluesky allows only 1 video per post.');
          }

          final file = File(mediaPaths.first);
          final bytes = await file.readAsBytes();

          // Upload video using the video service
          final uploadedVideo = await _client!.video.uploadVideo(bytes: bytes);

          if (uploadedVideo.data.blob == null) {
            throw Exception('Failed to upload video blob');
          }

          embed = UFeedPostEmbed.embedVideo(
            data: EmbedVideo(
              video: uploadedVideo.data.blob!,
            ),
          );
        } else {
          // Images
          if (mediaPaths.length > 4) {
            throw Exception('Bluesky allows only up to 4 images per post.');
          }

          final images = <EmbedImagesImage>[];

          for (final path in mediaPaths) {
            final file = File(path);
            var bytes = await file.readAsBytes();

            // Check size limit (5MB)
            if (bytes.lengthInBytes > 5 * 1024 * 1024) {
              bytes = await _compressImage(bytes);
            }

            // Upload image blob
            // Accessing atproto via the client if available.
            // The agent suggested _client!.atproto.repo.uploadBlob
            // This is safer if Bluesky wraps AtProto.
            final uploadedBlob = await _client!.atproto.repo.uploadBlob(bytes: bytes);

            images.add(
              EmbedImagesImage(
                image: uploadedBlob.data.blob,
                alt: 'Image', // TODO: Allow user to provide alt text
              ),
            );
          }

          embed = UFeedPostEmbed.embedImages(
            data: EmbedImages(images: images),
          );
        }
      }
    }

    await _client!.feed.post.create(
      text: content,
      embed: embed,
    );
  }

  bool _isVideoFile(String path) {
    final ext = path.split('.').last.toLowerCase();
    return ['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(ext);
  }

  Future<Uint8List> _compressImage(Uint8List bytes) async {
    print('Image size ${bytes.lengthInBytes} exceeds 5MB. Compressing...');
    
    // Decode the image
    final image = img.decodeImage(bytes);
    if (image == null) {
      throw Exception('Failed to decode image for compression.');
    }

    // Initial quality
    int quality = 85;
    Uint8List compressedBytes = bytes;
    
    // Loop until size is under 5MB
    // We also resize if quality reduction isn't enough
    int attempts = 0;
    img.Image currentImage = image;

    while (compressedBytes.lengthInBytes > 5 * 1024 * 1024 && attempts < 5) {
      // Encode to JPG
      compressedBytes = Uint8List.fromList(img.encodeJpg(currentImage, quality: quality));
      
      if (compressedBytes.lengthInBytes > 5 * 1024 * 1024) {
        // Reduce quality
        quality -= 10;
        
        // If quality gets too low, resize the image
        if (quality < 50) {
          currentImage = img.copyResize(
            currentImage, 
            width: (currentImage.width * 0.8).toInt(),
            height: (currentImage.height * 0.8).toInt(),
            interpolation: img.Interpolation.linear,
          );
          // Reset quality for the smaller image
          quality = 80; 
        }
      }
      attempts++;
    }

    if (compressedBytes.lengthInBytes > 5 * 1024 * 1024) {
      throw Exception('Unable to compress image below 5MB limit.');
    }

    print('Image compressed to ${compressedBytes.lengthInBytes} bytes.');
    return compressedBytes;
  }
}
