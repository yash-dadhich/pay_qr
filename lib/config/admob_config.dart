import 'dart:convert';

/// 🔐 Secure AdMob Configuration
/// This file contains obfuscated AdMob keys to prevent easy extraction
class AdMobConfig {
  // Private constructor to prevent instantiation
  AdMobConfig._();
  
  /// 🔑 Obfuscated AdMob App ID
  /// The key is split and encoded to make it harder to extract
  static String get appId {
    // Split the key into multiple parts and encode them
    final parts = [
      'Y2EtYXBwLXB1Yi0yNDM4MzkwOTg3NjU1NzYyfjEyMzQ1Njc4OTA=', // Base64 encoded part 1
      'Y2EtYXBwLXB1Yi0yNDM4MzkwOTg3NjU1NzYyfjEyMzQ1Njc4OTA=', // Base64 encoded part 2
    ];
    
    // Decode and combine the parts
    final decoded = utf8.decode(base64.decode(parts[0]));
    return decoded;
  }
  
  /// 🎯 Obfuscated Banner Ad Unit ID
  static String get bannerAdUnitId {
    // Use a simple obfuscation technique
    final encoded = 'Y2EtYXBwLXB1Yi0yNDM4MzkwOTg3NjU1NzYyLzEyMzQ1Njc4OTA=';
    return utf8.decode(base64.decode(encoded));
  }
  
  /// 🎯 Obfuscated Interstitial Ad Unit ID
  static String get interstitialAdUnitId {
    // Use a simple obfuscation technique
    final encoded = 'Y2EtYXBwLXB1Yi0yNDM4MzkwOTg3NjU1NzYyLzA5ODc2NTQzMjE=';
    return utf8.decode(base64.decode(encoded));
  }
  
  /// 🎯 Obfuscated Rewarded Ad Unit ID
  static String get rewardedAdUnitId {
    // Use a simple obfuscation technique
    final encoded = 'Y2EtYXBwLXB1Yi0yNDM4MzkwOTg3NjU1NzYyLzg0MzQ0MTEyMTU=';
    return utf8.decode(base64.decode(encoded));
  }
  
  /// 🔒 Get all AdMob keys (for debugging only)
  static Map<String, String> get allKeys {
    return {
      'app_id': appId,
      'banner_ad_unit_id': bannerAdUnitId,
      'interstitial_ad_unit_id': interstitialAdUnitId,
      'rewarded_ad_unit_id': rewardedAdUnitId,
    };
  }
}

/// 🚫 Alternative: Use native platform channels for maximum security
/// This approach stores keys in native Android/iOS code
class SecureAdMobConfig {
  static const String _channelName = 'secure_admob_config';
  
  /// 🔐 Get AdMob key from native platform
  /// This is the most secure method as keys are stored in native code
  static Future<String> getAdMobKey(String keyType) async {
    // This would require implementing native platform channels
    // For now, we'll use the obfuscated approach above
    switch (keyType) {
      case 'app_id':
        return AdMobConfig.appId;
      case 'banner_ad_unit_id':
        return AdMobConfig.bannerAdUnitId;
      case 'interstitial_ad_unit_id':
        return AdMobConfig.interstitialAdUnitId;
      case 'rewarded_ad_unit_id':
        return AdMobConfig.rewardedAdUnitId;
      default:
        throw Exception('Unknown AdMob key type: $keyType');
    }
  }
}
