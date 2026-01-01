import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ghall/core/interfaces/social_platform.dart';
import 'package:ghall/features/platforms/bluesky/bluesky_platform.dart';

final platformsProvider = Provider<List<SocialPlatform>>((ref) {
  return [
    BlueskyPlatform(),
    // Add other platforms here later
  ];
});
