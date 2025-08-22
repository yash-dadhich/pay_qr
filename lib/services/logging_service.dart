import 'package:flutter/foundation.dart';

/// 🚀 Centralized Logging Service
/// This service ensures that debug logs only appear in debug builds
/// and provides consistent logging throughout the app
class LoggingService {
  static final LoggingService _instance = LoggingService._internal();
  factory LoggingService() => _instance;
  LoggingService._internal();

  /// 🔍 Debug logging - only shows in debug builds
  void debug(String message) {
    if (kDebugMode) {
      print('🔍 DEBUG: $message');
    }
  }

  /// ✅ Info logging - shows in both debug and release
  void info(String message) {
    print('ℹ️ INFO: $message');
  }

  /// ⚠️ Warning logging - shows in both debug and release
  void warning(String message) {
    print('⚠️ WARNING: $message');
  }

  /// ❌ Error logging - shows in both debug and release
  void error(String message, [dynamic error, StackTrace? stackTrace]) {
    if (error != null) {
      print('❌ ERROR: $message - $error');
      if (stackTrace != null && kDebugMode) {
        print('📚 Stack Trace: $stackTrace');
      }
    } else {
      print('❌ ERROR: $message');
    }
  }

  /// 🚨 Critical error logging - always shows
  void critical(String message, [dynamic error, StackTrace? stackTrace]) {
    print('🚨 CRITICAL: $message');
    if (error != null) {
      print('🚨 Error Details: $error');
    }
    if (stackTrace != null) {
      print('🚨 Stack Trace: $stackTrace');
    }
  }

  /// 📱 Firebase-specific logging - only in debug mode
  void firebase(String message) {
    if (kDebugMode) {
      print('🔥 FIREBASE: $message');
    }
  }

  /// 📊 Analytics logging - only in debug mode
  void analytics(String message) {
    if (kDebugMode) {
      print('📊 ANALYTICS: $message');
    }
  }

  /// 🎯 Success logging - shows in both modes
  void success(String message) {
    print('✅ SUCCESS: $message');
  }

  /// 🔄 Process logging - only in debug mode
  void process(String message) {
    if (kDebugMode) {
      print('🔄 PROCESS: $message');
    }
  }
}

/// 🚀 Quick access to logging service
final logger = LoggingService();

/// 🔍 Quick debug logging function
void logDebug(String message) => logger.debug(message);

/// ℹ️ Quick info logging function
void logInfo(String message) => logger.info(message);

/// ⚠️ Quick warning logging function
void logWarning(String message) => logger.warning(message);

/// ❌ Quick error logging function
void logError(String message, [dynamic error, StackTrace? stackTrace]) => 
    logger.error(message, error, stackTrace);

/// 🚨 Quick critical logging function
void logCritical(String message, [dynamic error, StackTrace? stackTrace]) => 
    logger.critical(message, error, stackTrace);

/// 🔥 Quick Firebase logging function
void logFirebase(String message) => logger.firebase(message);

/// 📊 Quick analytics logging function
void logAnalytics(String message) => logger.analytics(message);

/// ✅ Quick success logging function
void logSuccess(String message) => logger.success(message);

/// 🔄 Quick process logging function
void logProcess(String message) => logger.process(message);
