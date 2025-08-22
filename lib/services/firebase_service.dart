import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:convert'; // Added for json.decode
import 'logging_service.dart';

/// 🏠 Firebase Service - Your Smart Home Controller
/// 
/// Memory Palace Technique:
/// - Core = Power Switch (everything needs power)
/// - Analytics = Security Camera (watches everything)
/// - Crashlytics = Fire Alarm (alerts when something breaks)
/// - Remote Config = Smart Thermostat (changes settings remotely)
class FirebaseService extends GetxService {
  // Singleton pattern - only one instance exists
  static FirebaseService get instance => Get.find<FirebaseService>();
  
  // Firebase instances
  late FirebaseAnalytics _analytics;
  late FirebaseCrashlytics _crashlytics;
  late FirebaseRemoteConfig _remoteConfig;
  
  // Observable variables for Remote Config
  final RxBool isForceUpdateRequired = false.obs;
  final RxString minimumAppVersion = ''.obs;
  final RxString updateMessage = ''.obs;
  
  // Platform-specific information
  Map<String, dynamic> _platformInfo = {};
  
  /// 🔑 Initialize Firebase (Power On)
  /// This is like turning on the main power switch
  Future<void> initialize() async {
    try {
      // 1. Initialize Firebase Core (Power Switch)
      await Firebase.initializeApp();
      logSuccess('Firebase Core initialized - Power is ON!');
      
      // 2. Initialize Analytics (Security Camera)
      _analytics = FirebaseAnalytics.instance;
      logSuccess('Firebase Analytics initialized - Camera is watching!');
      
      // 3. Initialize Crashlytics (Fire Alarm)
      _crashlytics = FirebaseCrashlytics.instance;
      // Enable crash reporting in debug mode for testing
      await _crashlytics.setCrashlyticsCollectionEnabled(true);
      logSuccess('Firebase Crashlytics initialized - Alarm system ready!');
      
      // 4. Initialize Remote Config (Smart Thermostat)
      _remoteConfig = FirebaseRemoteConfig.instance;
      await _initializeRemoteConfig();
      logSuccess('Firebase Remote Config initialized - Thermostat ready!');
      
      // 5. Check for force update
      await _checkForceUpdate();
      
    } catch (e) {
      logError('Firebase initialization failed', e, StackTrace.current);
      // Report error to Crashlytics
      _crashlytics.recordError(e, StackTrace.current);
    }
  }
  
  /// 📊 Track User Event (Security Camera Recording)
  /// Use this to track what users do in your app
  Future<void> trackEvent({
    required String name,
    Map<String, dynamic>? parameters,
  }) async {
    try {
      await _analytics.logEvent(
        name: name,
        parameters: parameters?.cast<String, Object>(),
      );
      logAnalytics('Event: $name ${parameters ?? ''}');
    } catch (e) {
      logError('Analytics tracking failed', e, StackTrace.current);
      _crashlytics.recordError(e, StackTrace.current);
    }
  }
  
  /// 🚨 Report Error (Fire Alarm)
  /// Use this to report any errors or exceptions
  Future<void> reportError(
    dynamic error,
    StackTrace? stackTrace, {
    String? reason,
  }) async {
    try {
      await _crashlytics.recordError(
        error,
        stackTrace,
        reason: reason,
      );
      logInfo('Error reported to Crashlytics: $error');
    } catch (e) {
      logError('Error reporting failed', e, StackTrace.current);
    }
  }
  
  /// 🎛️ Initialize Remote Config (Smart Thermostat Setup)
  /// This sets up your remote control system
  Future<void> _initializeRemoteConfig() async {
    try {
      // Set default values (fallback settings)
      // Firebase Remote Config only supports: bool, int, double, String
      await _remoteConfig.setDefaults({
        // Global settings
        'force_update_required': false,
        'maintenance_mode': false,
        'maintenance_message': 'We\'re currently performing some maintenance on Pay QR to improve your experience.',
        
        // Android-specific settings
        'android_force_update_required': false,
        'android_minimum_version_code': 1,  // Use versionCode (integer)
        'android_current_version_code': 1,  // Use versionCode (integer)
        'android_update_message': 'Android: Please update Pay QR to continue using the app.',
        'android_store_url': 'https://play.google.com/store/apps/details?id=com.sylionixtech.payqr',
        
        // iOS-specific settings
        'ios_force_update_required': false,
        'ios_minimum_version_code': 1,  // Use versionCode (integer)
        'ios_current_version_code': 1,  // Use versionCode (integer)
        'ios_update_message': 'iOS: Please update Pay QR to continue using the app.',
        'ios_store_url': 'https://apps.apple.com/app/your-app-id',
        
        // Feature flags
        'new_ui_enabled': false,
        'beta_features': false,
        'max_upi_count': 10,
        'qr_quality': 'high',
        'enable_ads': true,
        'enable_rewards': true,
      });
      
      // Set fetch timeout
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ));
      
      // Fetch and activate config
      await _remoteConfig.fetchAndActivate();
      logSuccess('Remote Config loaded successfully!');
      
    } catch (e) {
      logError('Remote Config initialization failed', e, StackTrace.current);
      _crashlytics.recordError(e, StackTrace.current);
    }
  }
  
  /// 🔄 Check for Force Update (Emergency Broadcast)
  /// This checks if users must update their app based on platform and version code
  Future<void> _checkForceUpdate() async {
    try {
      logDebug('Starting force update check...');
      
      // Get platform-specific settings
      final isAndroid = GetPlatform.isAndroid;
      final isIOS = GetPlatform.isIOS;
      
      logDebug('Platform detected - Android: $isAndroid, iOS: $isIOS');
      
      // Get current app version code from package info
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersionCode = int.tryParse(packageInfo.buildNumber) ?? 1;
      
      logDebug('Current app version code: $currentVersionCode');
      
      // Get the JSON string from Remote Config
      final jsonString = _remoteConfig.getString('force_update_required');
      logDebug('Raw JSON string: $jsonString');
      
      // Parse the JSON string
      Map<String, dynamic> configData = {};
      try {
        configData = json.decode(jsonString);
        logDebug('Parsed JSON successfully');
      } catch (e) {
        logError('Failed to parse JSON', e, StackTrace.current);
        return;
      }
      
      // Extract values from parsed JSON
      bool forceUpdate = false;
      int minVersionCode = 1;
      String message = '';
      String storeUrl = '';
      
      if (isAndroid) {
        forceUpdate = configData['android_force_update_required'] ?? false;
        minVersionCode = configData['android_minimum_version_code'] ?? 1;
        message = configData['android_update_message'] ?? 'Please update your app.';
        storeUrl = configData['android_store_url'] ?? '';
        
        logDebug('Android values from JSON:');
        logDebug('  - android_force_update_required: $forceUpdate');
        logDebug('  - android_minimum_version_code: $minVersionCode');
        logDebug('  - android_update_message: $message');
      } else if (isIOS) {
        forceUpdate = configData['ios_force_update_required'] ?? false;
        minVersionCode = configData['ios_minimum_version_code'] ?? 1;
        message = configData['ios_update_message'] ?? 'Please update your app.';
        storeUrl = configData['ios_store_url'] ?? '';
        
        logDebug('iOS values from JSON:');
        logDebug('  - ios_force_update_required: $forceUpdate');
        logDebug('  - ios_minimum_version_code: $minVersionCode');
        logDebug('  - ios_update_message: $message');
      }
      
      logDebug('Final values:');
      logDebug('  - forceUpdate: $forceUpdate');
      logDebug('  - minVersionCode: $minVersionCode');
      logDebug('  - currentVersionCode: $currentVersionCode');
      
      // Check if current version is below minimum required version
      final needsUpdate = currentVersionCode < minVersionCode;
      final shouldForceUpdate = forceUpdate && needsUpdate;
      
      logDebug('Logic results:');
      logDebug('  - needsUpdate: $needsUpdate ($currentVersionCode < $minVersionCode)');
      logDebug('  - shouldForceUpdate: $shouldForceUpdate ($forceUpdate && $needsUpdate)');
      
      // Update observable variables
      isForceUpdateRequired.value = shouldForceUpdate;
      minimumAppVersion.value = minVersionCode.toString();
      updateMessage.value = message;
      
      logDebug('Observable variables updated:');
      logDebug('  - isForceUpdateRequired.value: ${isForceUpdateRequired.value}');
      logDebug('  - minimumAppVersion.value: ${minimumAppVersion.value}');
      logDebug('  - updateMessage.value: ${updateMessage.value}');
      
      // Store platform info for later use
      _platformInfo = {
        'is_android': isAndroid,
        'is_ios': isIOS,
        'force_update': shouldForceUpdate,
        'current_version_code': currentVersionCode,
        'min_version_code': minVersionCode,
        'needs_update': needsUpdate,
        'message': message,
        'store_url': storeUrl,
      };
      
      if (shouldForceUpdate) {
        logWarning('FORCE UPDATE REQUIRED!');
        logInfo('Platform: ${isAndroid ? "Android" : "iOS"}');
        logInfo('Current Version Code: $currentVersionCode');
        logInfo('Minimum Required: $minVersionCode');
        logInfo('Message: $message');
        
        // Track force update check
        await trackEvent(
          name: 'force_update_required',
          parameters: {
            'platform': isAndroid ? 'android' : 'ios',
            'current_version_code': currentVersionCode,
            'minimum_version_code': minVersionCode,
            'message': message,
          },
        );
      } else if (needsUpdate) {
        logWarning('Update available but not forced');
        logInfo('Platform: ${isAndroid ? "Android" : "iOS"}');
        logInfo('Current Version Code: $currentVersionCode');
        logInfo('Recommended Version: $minVersionCode');
      } else {
        logSuccess('App is up to date');
        logInfo('Platform: ${isAndroid ? "Android" : "iOS"}');
        logInfo('Current Version Code: $currentVersionCode');
      }
      
    } catch (e) {
      logError('Force update check failed', e, StackTrace.current);
      _crashlytics.recordError(e, StackTrace.current);
    }
  }
  
  /// 🔍 Debug: Show all Remote Config values
  /// This helps troubleshoot configuration issues
  Map<String, dynamic> get debugRemoteConfigValues {
    try {
      final allKeys = _remoteConfig.getAll();
      final values = <String, dynamic>{};
      
      for (final entry in allKeys.entries) {
        values[entry.key] = entry.value.asString();
      }
      
      logDebug('All Remote Config values:');
      values.forEach((key, value) {
        logDebug('  - $key: $value');
      });
      
      return values;
    } catch (e) {
      logError('Failed to get debug values', e, StackTrace.current);
      return {};
    }
  }

  /// 🔍 Manual Force Update Check
  /// Call this to manually check force update status
  Future<void> manualForceUpdateCheck() async {
    logDebug('Manual force update check requested...');
    await _checkForceUpdate();
  }

  /// 🔍 Check Firebase Project Status
  /// This helps verify if Firebase is properly connected
  Future<void> checkFirebaseStatus() async {
    try {
      logDebug('Checking Firebase project status...');
      
      // Check if Remote Config is initialized
      logDebug('Remote Config initialized: true');
      
      // Check current settings
      final settings = _remoteConfig.settings;
      logDebug('Current settings:');
      logDebug('  - fetchTimeout: ${settings.fetchTimeout}');
      logDebug('  - minimumFetchInterval: ${settings.minimumFetchInterval}');
      
      // Check if we have any values at all
      final allKeys = _remoteConfig.getAll();
      logDebug('Total Remote Config keys: ${allKeys.length}');
      
      if (allKeys.isEmpty) {
        logCritical('No Remote Config keys found!');
        logCritical('This means Firebase is not loading any values!');
        logCritical('Possible causes:');
        logCritical('  1. Wrong google-services.json file');
        logCritical('  2. Firebase project not connected');
        logCritical('  3. Remote Config not published');
        logCritical('  4. App not added to Firebase project');
      } else {
        logSuccess('Remote Config has ${allKeys.length} keys');
        logDebug('First few keys:');
        int count = 0;
        for (final entry in allKeys.entries) {
          if (count < 5) {
            logDebug('  - ${entry.key}: ${entry.value.asString()}');
            count++;
          } else {
            break;
          }
        }
      }
      
    } catch (e) {
      logError('Firebase status check failed', e, StackTrace.current);
      _crashlytics.recordError(e, StackTrace.current);
    }
  }

  /// 🔄 Refresh Remote Config (Manual Refresh)
  /// This fetches the latest values from Firebase and activates them
  Future<void> refreshRemoteConfig() async {
    try {
      logProcess('Starting manual Remote Config refresh...');
      
      // Clear any cached values first
      await _remoteConfig.setDefaults({});
      
      // Set fetch timeout to 10 seconds
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: Duration.zero, // Force immediate fetch
      ));
      
      logProcess('Fetching latest Remote Config...');
      
      // Fetch and activate
      await _remoteConfig.fetchAndActivate();
      
      logSuccess('Remote Config refreshed successfully!');
      
      // Check force update again
      await _checkForceUpdate();
      
    } catch (e) {
      logError('Remote Config refresh failed', e, StackTrace.current);
      _crashlytics.recordError(e, StackTrace.current);
    }
  }

  /// 🚀 Nuclear Refresh - Complete Cache Clear
  /// This completely resets Remote Config and forces fresh fetch
  Future<void> nuclearRefresh() async {
    try {
      logProcess('Starting NUCLEAR refresh...');
      
      // Clear all defaults
      await _remoteConfig.setDefaults({});
      
      // Reset to factory settings
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 15),
        minimumFetchInterval: Duration.zero,
      ));
      
      logProcess('Fetching fresh Remote Config...');
      
      // Force fetch
      await _remoteConfig.fetch();
      // logDebug('Fetch result: $fetchResult');
      
      // Activate
      final activateResult = await _remoteConfig.activate();
      logDebug('Activate result: $activateResult');
      
      logSuccess('NUCLEAR refresh completed!');
      
      // Show all current values
      final allKeys = _remoteConfig.getAll();
      logDebug('All keys after refresh:');
      allKeys.forEach((key, value) {
        logDebug('  - $key: ${value.asString()}');
      });
      
      // Check force update again
      await _checkForceUpdate();
      
    } catch (e) {
      logError('Nuclear refresh failed', e, StackTrace.current);
      _crashlytics.recordError(e, StackTrace.current);
    }
  }

  /// 💥 COMPLETE RESET - Nuclear Option
  /// This completely destroys and rebuilds Remote Config
  Future<void> completeReset() async {
    try {
      logProcess('Starting COMPLETE RESET...');
      
      // Clear ALL defaults
      await _remoteConfig.setDefaults({});
      
      // Reset settings to maximum fetch
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 30),
        minimumFetchInterval: Duration.zero,
      ));
      
      logProcess('Fetching with maximum timeout...');
      
      // Force fetch with maximum timeout
      await _remoteConfig.fetch();
      logDebug('Fetch completed');
      
      // Activate immediately
      final activateResult = await _remoteConfig.activate();
      logDebug('Activate result: $activateResult');
      
      logSuccess('COMPLETE RESET finished!');
      
      // Show ALL current values
      final allKeys = _remoteConfig.getAll();
      logDebug('ALL keys after complete reset:');
      if (allKeys.isEmpty) {
        logCritical('NO KEYS FOUND! This means Firebase is not loading values!');
      } else {
        allKeys.forEach((key, value) {
          logDebug('  - $key: ${value.asString()}');
        });
      }
      
      // Check force update again
      await _checkForceUpdate();
      
    } catch (e) {
      logError('Complete reset failed', e, StackTrace.current);
      _crashlytics.recordError(e, StackTrace.current);
    }
  }
  
  /// 🎯 Get Remote Config Value (Read Thermostat Setting)
  /// Use this to get any remote configuration value
  T getRemoteValue<T>(String key, {T? defaultValue}) {
    try {
      if (T == bool) {
        return _remoteConfig.getBool(key) as T;
      } else if (T == String) {
        return _remoteConfig.getString(key) as T;
      } else if (T == int) {
        return _remoteConfig.getInt(key) as T;
      } else if (T == double) {
        return _remoteConfig.getDouble(key) as T;
      }
      throw Exception('Unsupported type: $T');
    } catch (e) {
      logError('Failed to get remote value for $key', e, StackTrace.current);
      _crashlytics.recordError(e, StackTrace.current);
      return defaultValue as T;
    }
  }
  
  /// 🚀 Quick Access to Feature Flags
  bool get isNewUiEnabled => getRemoteValue<bool>('new_ui_enabled', defaultValue: false);
  bool get isBetaFeaturesEnabled => getRemoteValue<bool>('beta_features', defaultValue: false);
  bool get isMaintenanceMode => getRemoteValue<bool>('maintenance_mode', defaultValue: false);
  String get maintenanceMessage => getRemoteValue<String>('maintenance_message', defaultValue: 'We\'re currently performing some maintenance on Pay QR to improve your experience.');
  int get maxUpiCount => getRemoteValue<int>('max_upi_count', defaultValue: 10);
  String get qrQuality => getRemoteValue<String>('qr_quality', defaultValue: 'high');
  bool get enableAds => getRemoteValue<bool>('enable_ads', defaultValue: true);
  bool get enableRewards => getRemoteValue<bool>('enable_rewards', defaultValue: true);
  
  /// 📱 Platform-Specific Information
  bool get isAndroid => _platformInfo['is_android'] ?? false;
  bool get isIOS => _platformInfo['is_ios'] ?? false;
  String get platformStoreUrl => _platformInfo['store_url'] ?? '';
  String get platformMinVersion => _platformInfo['min_version'] ?? '';
  
  /// 🔧 Advanced Feature Controls
  bool get shouldShowNewUI => isNewUiEnabled && !isMaintenanceMode;
  bool get shouldShowAds => enableAds && !isMaintenanceMode;
  bool get shouldShowRewards => enableRewards && !isMaintenanceMode;
  
  /// 📱 Track Screen View (Camera Pan)
  /// Use this to track which screens users visit
  Future<void> trackScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    try {
      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: screenClass,
      );
      logAnalytics('Screen View: $screenName');
    } catch (e) {
      logError('Screen tracking failed', e, StackTrace.current);
      _crashlytics.recordError(e, StackTrace.current);
    }
  }
  
  /// 👤 Set User Properties (Camera Settings)
  /// Use this to identify users and their characteristics
  Future<void> setUserProperties({
    String? userId,
    String? userType,
    String? subscription,
  }) async {
    try {
      if (userId != null) {
        await _analytics.setUserId(id: userId);
      }
      if (userType != null) {
        await _analytics.setUserProperty(name: 'user_type', value: userType);
      }
      if (subscription != null) {
        await _analytics.setUserProperty(name: 'subscription', value: subscription);
      }
      logAnalytics('User properties set: $userId, $userType, $subscription');
    } catch (e) {
      logError('User properties failed', e, StackTrace.current);
      _crashlytics.recordError(e, StackTrace.current);
    }
  }
  
  /// 🧹 Cleanup (Power Off)
  /// Call this when you're done with Firebase
  Future<void> dispose() async {
    try {
      // Close Remote Config
      // await _remoteConfig.dispose(); // This line was removed as per the edit hint
      logInfo('Firebase service cleaned up');
    } catch (e) {
      logError('Firebase cleanup failed', e, StackTrace.current);
    }
  }
}

/// 🚀 Quick Access Functions (Shortcuts)
/// These make it easy to use Firebase anywhere in your app

/// Track an event quickly
Future<void> trackEvent(String name, [Map<String, dynamic>? params]) async {
  await FirebaseService.instance.trackEvent(name: name, parameters: params);
}

/// Track screen view quickly
Future<void> trackScreen(String screenName) async {
  await FirebaseService.instance.trackScreenView(screenName: screenName);
}

/// Report error quickly
Future<void> reportError(dynamic error, [StackTrace? stackTrace]) async {
  await FirebaseService.instance.reportError(error, stackTrace);
}

/// Check if force update is required
bool get isForceUpdateRequired => FirebaseService.instance.isForceUpdateRequired.value;

/// Get force update message
String get forceUpdateMessage => FirebaseService.instance.updateMessage.value;
