
abstract class SocialPlatform {
  String get id;
  String get name;
  String get iconAsset; // Or IconData
  
  Future<bool> get isConnected;
  
  Future<void> initialize(); // Add this
  
  Future<void> login(Map<String, String> credentials);
  Future<void> logout();
  
  Future<void> post(String content, {List<String>? mediaPaths});
}
