# 🚀 Logging System Setup

## Overview
The Pay QR app now has a centralized logging system that ensures **debug logs only appear in debug builds** and **production logs are clean**.

## 🔍 How It Works

### Debug Mode (Development)
- **All logs are visible** including debug, info, warning, error, and critical messages
- **Detailed debugging information** is available for developers
- **Stack traces** are shown for errors

### Release Mode (Production)
- **Only essential logs are visible**: info, warning, error, and critical
- **Debug logs are hidden** - users won't see internal debugging information
- **Stack traces are hidden** for security
- **Clean console output** for end users

## 📱 Logging Functions

### Debug Logging (Debug Mode Only)
```dart
logDebug('This will only show in debug builds');
logFirebase('Firebase-specific debug info');
logAnalytics('Analytics debug info');
logProcess('Process flow debug info');
```

### Always Visible Logging
```dart
logInfo('General information - always visible');
logWarning('Warning messages - always visible');
logError('Error messages - always visible');
logCritical('Critical errors - always visible');
logSuccess('Success messages - always visible');
```

## 🎯 Usage Examples

### Before (Old System)
```dart
print('🔍 DEBUG: Starting process...'); // Always visible!
print('❌ Error: Something failed');    // Always visible!
```

### After (New System)
```dart
logDebug('Starting process...');        // Only in debug mode
logError('Something failed');           // Always visible
```

## 🔧 Implementation

The logging system uses Flutter's `kDebugMode` constant to determine the build mode:

```dart
void debug(String message) {
  if (kDebugMode) {
    print('🔍 DEBUG: $message');
  }
  // In release mode, nothing is printed
}
```

## ✅ Benefits

1. **Clean Production Logs** - End users won't see debug information
2. **Better Security** - Sensitive debug info is hidden in production
3. **Consistent Formatting** - All logs follow the same pattern
4. **Easy to Maintain** - Centralized logging configuration
5. **Performance** - No unnecessary string operations in release mode

## 🧪 Testing

Use the test button (bug icon) in the app bar to verify logging behavior:

- **Debug Build**: All message types will appear in console
- **Release Build**: Only info, warning, error, and critical messages will appear

## 📋 Migration Guide

To update existing code:

1. **Replace `print()` with appropriate logging function**
2. **Use `logDebug()` for debug-only information**
3. **Use `logInfo()`, `logWarning()`, `logError()` for always-visible logs**
4. **Import the logging service**: `import 'services/logging_service.dart';`

## 🚨 Important Notes

- **Never use `print()` directly** - always use the logging service
- **Debug logs are completely hidden** in release builds
- **Error logs are always visible** for production debugging
- **Stack traces only show in debug mode** for security
