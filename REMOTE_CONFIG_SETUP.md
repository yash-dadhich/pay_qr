# 🎛️ **Enhanced Remote Config Setup Guide**

## **🎯 What We've Built**

Your Pay QR app now has a **comprehensive Remote Config system** that supports:

- ✅ **Platform-specific version management** (Android/iOS)
- ✅ **Flexible force update options** (Update/Skip/Remind)
- ✅ **Feature flags** for gradual rollouts
- ✅ **Maintenance mode** for app control
- ✅ **Advanced analytics** tracking

---

## **📱 Complete JSON for Copy-Paste**

Here's the **complete JSON** you can copy and paste into Firebase Console:

```json
{
  "force_update_required": false,
  "maintenance_mode": false,
  "android_force_update_required": false,
  "android_minimum_version_code": 1,
  "android_current_version_code": 1,
  "android_update_message": "Android: Please update Pay QR to continue using the app.",
  "android_store_url": "https://play.google.com/store/apps/details?id=com.sylionixtech.payqr",
  "ios_force_update_required": false,
  "ios_minimum_version_code": 1,
  "ios_current_version_code": 1,
  "ios_update_message": "iOS: Please update Pay QR to continue using the app.",
  "ios_store_url": "https://apps.apple.com/app/your-app-id",
  "new_ui_enabled": false,
  "beta_features": false,
  "max_upi_count": 10,
  "qr_quality": "high",
  "enable_ads": true,
  "enable_rewards": true
}
```

---

## **🔑 Complete Parameter Key List for Firebase Console**

### ** Global Settings (2 parameters):**
| **Parameter Key** | **Value** | **Description** |
|-------------------|-----------|-----------------|
| `force_update_required` | `false` | Global force update for all platforms |
| `maintenance_mode` | `false` | Puts app in maintenance mode |

### **🤖 Android-Specific Settings (5 parameters):**
| **Parameter Key** | **Value** | **Description** |
|-------------------|-----------|-----------------|
| `android_force_update_required` | `false` | Force update for Android users only |
| `android_minimum_version_code` | `1` | Minimum Android app version code required |
| `android_current_version_code` | `1` | Current Android app version code available |
| `android_update_message` | `Android: Please update Pay QR to continue using the app.` | Update message for Android users |
| `android_store_url` | `https://play.google.com/store/apps/details?id=com.sylionixtech.payqr` | Google Play Store URL |

### **🍎 iOS-Specific Settings (5 parameters):**
| **Parameter Key** | **Value** | **Description** |
|-------------------|-----------|-----------------|
| `ios_force_update_required` | `false` | Force update for iOS users only |
| `ios_minimum_version_code` | `1` | Minimum iOS app version code required |
| `ios_current_version_code` | `1` | Current iOS app version code available |
| `ios_update_message` | `iOS: Please update Pay QR to continue using the app.` | Update message for iOS users |
| `ios_store_url` | `https://apps.apple.com/app/your-app-id` | App Store URL |

### **🚀 Feature Flags (6 parameters):**
| **Parameter Key** | **Value** | **Description** |
|-------------------|-----------|-----------------|
| `new_ui_enabled` | `false` | Enables new UI design |
| `beta_features` | `false` | Enables beta features |
| `max_upi_count` | `10` | Maximum UPI IDs user can save |
| `qr_quality` | `high` | QR code quality (low/medium/high/ultra) |
| `enable_ads` | `true` | Enables advertisement display |
| `enable_rewards` | `true` | Enables reward system |

---

## **🎛️ Firebase Console Setup**

### **Step 1: Go to Remote Config**
1. **Firebase Console** → Your Project
2. **Left sidebar** → **Remote Config**
3. **Click "Get started"**

### **Step 2: Add All Parameters**
1. **Click "Add parameter"** for each parameter above
2. **Copy-paste** the exact keys and values
3. **Add descriptions** for each parameter
4. **Set default values** as shown above

### **Android Settings:**
- `android_force_update_required`: Force update for Android users only
- `android_minimum_version_code`: Minimum Android app version code required (integer)
- `android_current_version_code`: Current Android app version code available (integer)
- `android_update_message`: Update message shown to Android users
- `android_store_url`: Google Play Store URL for Android

### **iOS Settings:**
- `ios_force_update_required`: Force update for iOS users only
- `ios_minimum_version_code`: Minimum iOS app version code required (integer)
- `ios_current_version_code`: Current iOS app version code available (integer)
- `ios_update_message`: Update message shown to iOS users
- `ios_store_url`: App Store URL for iOS

### **Step 3: Test Force Update**
1. **Set `android_force_update_required` to `true`**
2. **Set `ios_force_update_required` to `true`**
3. **Click "Publish changes"**
4. **Wait 1-2 minutes** for propagation

---

## **🧪 Testing Scenarios**

### **Scenario 1: Android Force Update**
```json
{
  "android_force_update_required": true,
  "android_minimum_version": "1.1.0",
  "android_update_message": "🚨 Critical Android update required! New security features available."
}
```

**Expected Result**: Android users see force update dialog, iOS users continue normally.

### **Scenario 2: iOS Force Update**
```json
{
  "ios_force_update_required": true,
  "ios_minimum_version": "1.2.0",
  "ios_update_message": "🍎 iOS users: Update required for new features!"
}
```

**Expected Result**: iOS users see force update dialog, Android users continue normally.

### **Scenario 3: Global Force Update**
```json
{
  "force_update_required": true,
  "maintenance_mode": false
}
```

**Expected Result**: All users see force update dialog.

### **Scenario 4: Maintenance Mode**
```json
{
  "maintenance_mode": true,
  "force_update_required": false
}
```

**Expected Result**: App shows maintenance message, no force update.

---

## **🎯 Feature Flag Examples**

### **Gradual UI Rollout:**
```json
{
  "new_ui_enabled": true,
  "beta_features": false
}
```

### **Premium Features:**
```json
{
  "max_upi_count": 25,
  "qr_quality": "ultra",
  "enable_rewards": true
}
```

### **Ad Control:**
```json
{
  "enable_ads": false,
  "enable_rewards": false
}
```

---

## **📊 Analytics Events**

### **Force Update Events:**
- `force_update_required` - When update is needed
- `force_update_button_clicked` - User clicks update
- `force_update_skipped` - User skips update
- `force_update_remind_later` - User sets reminder

### **Feature Flag Events:**
- `feature_flag_changed` - When flags are updated
- `new_ui_enabled` - When new UI is activated
- `beta_features_enabled` - When beta features are turned on

---

## **🔧 Code Usage Examples**

### **Check Force Update:**
```dart
if (FirebaseService.instance.isForceUpdateRequired.value) {
  Get.dialog(const ForceUpdateDialog(), barrierDismissible: false);
}
```

### **Use Feature Flags:**
```dart
// Check if new UI is enabled
if (FirebaseService.instance.shouldShowNewUI) {
  // Show new UI
} else {
  // Show old UI
}

// Check UPI limit
final maxUpi = FirebaseService.instance.maxUpiCount;
if (userUpiCount >= maxUpi) {
  // Show upgrade message
}
```

### **Platform-Specific Logic:**
```dart
if (FirebaseService.instance.isAndroid) {
  // Android-specific code
} else if (FirebaseService.instance.isIOS) {
  // iOS-specific code
}
```

---

## **🚨 Force Update Dialog Options**

### **Update Now (Primary):**
- **Always visible** when update required
- **Opens app store** directly
- **Cannot be dismissed**

### **Skip for Now (Secondary):**
- **Only visible** when not truly forced
- **Temporary bypass** with reminder
- **Tracks skip action**

### **Remind Later (Tertiary):**
- **Only visible** when not truly forced
- **Sets reminder** for later
- **Tracks remind action**

---

## **📱 Platform Detection**

### **Automatic Detection:**
```dart
// Firebase service automatically detects platform
final isAndroid = FirebaseService.instance.isAndroid;
final isIOS = FirebaseService.instance.isIOS;
```

### **Platform-Specific URLs:**
```dart
// Gets correct store URL for platform
final storeUrl = FirebaseService.instance.platformStoreUrl;
```

---

## **🔄 Refreshing Remote Config**

### **Manual Refresh:**
```dart
await FirebaseService.instance.refreshRemoteConfig();
```

### **Automatic Refresh:**
- **App startup** - Always checks
- **Background fetch** - Every hour
- **Error recovery** - When config fails

---

## **✅ Testing Checklist**

### **Before Testing:**
- [ ] All parameters added to Firebase Console
- [ ] Values published and propagated
- [ ] App restarted after changes
- [ ] Console logs checked for Firebase status

### **Test Cases:**
- [ ] Android force update dialog
- [ ] iOS force update dialog
- [ ] Skip/Remind options (when not forced)
- [ ] Feature flags working
- [ ] Platform detection correct
- [ ] Store URLs opening correctly

---

## **🎉 What You Can Control Now**

1. **Force updates** for specific platforms
2. **Different messages** for Android vs iOS
3. **Feature rollouts** gradually
4. **App maintenance** mode
5. **User limits** and restrictions
6. **Quality settings** for features
7. **Ad and reward** controls

---

## **🚀 Next Steps**

1. **Set up Firebase Console** with all parameters
2. **Test force update** for each platform
3. **Experiment with feature flags**
4. **Monitor analytics** for user behavior
5. **Set up alerts** for critical updates

**You now have enterprise-grade app control! 🎛️✨**
