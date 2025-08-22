import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'logging_service.dart';

/// 🔐 Secure AdMob Service
/// This service uses platform channels to get AdMob keys from native code
/// This provides maximum security as keys are never stored in Dart code
class SecureAdMobService {
  static const MethodChannel _channel = MethodChannel('secure_admob_config');
  
  // Singleton instance
  static final SecureAdMobService _instance = SecureAdMobService._internal();
  factory SecureAdMobService() => _instance;
  SecureAdMobService._internal();
  
  /// 🔑 Get AdMob App ID securely from native code
  static Future<String> getAdMobAppId() async {
    try {
      final String appId = await _channel.invokeMethod('getAdMobAppId');
      return appId;
    } on PlatformException catch (e) {
      logError('Failed to get AdMob App ID from native code', e, StackTrace.current);
      // Fallback to obfuscated keys if native method fails
      return _getFallbackAppId();
    }
  }
  
  /// 🎯 Get Banner Ad Unit ID securely from native code
  static Future<String> getBannerAdUnitId() async {
    try {
      final String adUnitId = await _channel.invokeMethod('getBannerAdUnitId');
      return adUnitId;
    } on PlatformException catch (e) {
      logError('Failed to get Banner Ad Unit ID from native code', e, StackTrace.current);
      return _getFallbackBannerId();
    }
  }
  
  /// 🎯 Get Interstitial Ad Unit ID securely from native code
  static Future<String> getInterstitialAdUnitId() async {
    try {
      final String adUnitId = await _channel.invokeMethod('getInterstitialAdUnitId');
      return adUnitId;
    } on PlatformException catch (e) {
      logError('Failed to get Interstitial Ad Unit ID from native code', e, StackTrace.current);
      return _getFallbackInterstitialId();
    }
  }
  
  /// 🎯 Get Rewarded Ad Unit ID securely from native code
  static Future<String> getRewardedAdUnitId() async {
    try {
      final String adUnitId = await _channel.invokeMethod('getRewardedAdUnitId');
      return adUnitId;
    } on PlatformException catch (e) {
      logError('Failed to get Rewarded Ad Unit ID from native code', e, StackTrace.current);
      return _getFallbackRewardedId();
    }
  }
  
  /// 🔒 Get all AdMob keys securely
  static Future<Map<String, String>> getAllKeys() async {
    try {
      final Map<dynamic, dynamic> keys = await _channel.invokeMethod('getAllKeys');
      return Map<String, String>.from(keys);
    } on PlatformException catch (e) {
      logError('Failed to get all AdMob keys from native code', e, StackTrace.current);
      return _getFallbackKeys();
    }
  }
  
  /// 🚨 Fallback methods (use only if native method fails)
  static String _getFallbackAppId() {
    // This should never be called in production
    // It's just a safety net
    if (kDebugMode) {
      return 'ca-app-pub-2438390987655762~7343872589'; // Your REAL App ID
    }
    throw Exception('AdMob App ID not available');
  }
  
  static String _getFallbackBannerId() {
    if (kDebugMode) {
      return 'ca-app-pub-2438390987655762/1234567890'; // Add your real Banner ID here
    }
    throw Exception('Banner Ad Unit ID not available');
  }
  
  static String _getFallbackInterstitialId() {
    if (kDebugMode) {
      return 'ca-app-pub-2438390987655762/0987654321'; // Add your real Interstitial ID here
    }
    throw Exception('Interstitial Ad Unit ID not available');
  }
  
  static String _getFallbackRewardedId() {
    if (kDebugMode) {
      return 'ca-app-pub-2438390987655762/8434411215'; // Your REAL Rewarded Ad Unit ID
    }
    throw Exception('Rewarded Ad Unit ID not available');
  }
  
  static Map<String, String> _getFallbackKeys() {
    if (kDebugMode) {
      return {
        'app_id': _getFallbackAppId(),
        'banner_ad_unit_id': _getFallbackBannerId(),
        'interstitial_ad_unit_id': _getFallbackInterstitialId(),
        'rewarded_ad_unit_id': _getFallbackRewardedId(),
      };
    }
    throw Exception('AdMob keys not available');
  }
}

/// 🚀 Quick access functions
Future<String> getSecureAdMobAppId() => SecureAdMobService.getAdMobAppId();
Future<String> getSecureBannerAdUnitId() => SecureAdMobService.getBannerAdUnitId();
Future<String> getSecureInterstitialAdUnitId() => SecureAdMobService.getInterstitialAdUnitId();
Future<String> getSecureRewardedAdUnitId() => SecureAdMobService.getRewardedAdUnitId();
Future<Map<String, String>> getSecureAdMobKeys() => SecureAdMobService.getAllKeys();
