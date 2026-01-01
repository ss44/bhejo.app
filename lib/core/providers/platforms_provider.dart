import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bhejo/core/interfaces/social_platform.dart';
import 'package:bhejo/features/platforms/bluesky/bluesky_platform.dart';

final platformsProvider = Provider<List<SocialPlatform>>((ref) {
  return [
    BlueskyPlatform(),
    // Add other platforms here later
  ];
});
