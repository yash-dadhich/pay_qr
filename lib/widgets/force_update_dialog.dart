import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/firebase_service.dart';

/// 🚨 Force Update Dialog
/// This dialog appears when Firebase Remote Config requires an app update
/// 
/// Memory Trick: Think of this as your "Emergency Broadcast System"
/// 
/// Enhanced Features:
/// - Update Now: Opens app store
/// - Skip for Now: Temporary bypass (if allowed)
/// - Remind Later: Sets reminder for later
/// - Platform-specific: Different behavior for Android/iOS
class ForceUpdateDialog extends StatelessWidget {
  const ForceUpdateDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // Prevent user from dismissing the dialog
      onWillPop: () async => false,
      child: Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 🚨 Warning Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(40),
                ),
                child: Icon(
                  Icons.warning_rounded,
                  size: 40,
                  color: Colors.red[600],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // 📱 Title
              Text(
                'Update Required',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[700],
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 16),
              
              // 📢 Message
              Obx(() => Text(
                FirebaseService.instance.updateMessage.value.isNotEmpty
                    ? FirebaseService.instance.updateMessage.value
                    : 'A new version of the app is required to continue.',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              )),
              
              const SizedBox(height: 20),
              
              // 🔢 Version Info
              Obx(() => FirebaseService.instance.minimumAppVersion.value.isNotEmpty
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Text(
                        'Minimum Version Required: ${FirebaseService.instance.minimumAppVersion.value}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  : const SizedBox.shrink()),
              
              const SizedBox(height: 24),
              
              // 🚀 Update Button (Primary Action)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => _openAppStore(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[600],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.system_update, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Update Now',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 12),
              
              // 🔄 Skip for Now Button (Secondary Action)
              Obx(() => FirebaseService.instance.isForceUpdateRequired.value
                  ? const SizedBox.shrink() // Hide if force update is truly required
                  : SizedBox(
                      width: double.infinity,
                      height: 45,
                      child: OutlinedButton(
                        onPressed: () => _skipForNow(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue[600],
                          side: BorderSide(color: Colors.blue[300]!),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.schedule, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Skip for Now',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )),
              
              const SizedBox(height: 8),
              
              // ⏰ Remind Later Button (Tertiary Action)
              Obx(() => FirebaseService.instance.isForceUpdateRequired.value
                  ? const SizedBox.shrink() // Hide if force update is truly required
                  : SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: TextButton(
                        onPressed: () => _remindLater(),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey[600],
                        ),
                        child: Text(
                          'Remind me later',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    )),
              
              const SizedBox(height: 12),
              
              // ℹ️ Info Text
              Text(
                'You cannot use the app until you update',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// 🚀 Open App Store/Play Store
  /// This launches the appropriate store for the user's platform
  Future<void> _openAppStore() async {
    try {
      // Track update button click
      await trackEvent('force_update_button_clicked');
      
      // Get platform-specific store URL from Firebase
      String url = FirebaseService.instance.platformStoreUrl;
      
      // Fallback URLs if Firebase doesn't have them
      if (url.isEmpty) {
        url = GetPlatform.isIOS
            ? 'https://apps.apple.com/app/your-app-id' // Replace with your iOS App Store ID
            : 'https://play.google.com/store/apps/details?id=com.sylionixtech.payqr'; // Your Android package name
      }
      
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        );
      } else {
        // Fallback: show snackbar with manual instructions
        Get.snackbar(
          'Update Required',
          'Please visit your app store to update the app',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red[100],
          colorText: Colors.red[800],
        );
      }
    } catch (e) {
      // Report error to Crashlytics
      await reportError(e, StackTrace.current);
      
      Get.snackbar(
        'Error',
        'Failed to open app store. Please update manually.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red[100],
        colorText: Colors.red[800],
      );
    }
  }
  
  /// 🔄 Skip Update for Now
  /// Allows user to temporarily bypass update (if not truly forced)
  void _skipForNow() {
    // Track skip action
    trackEvent('force_update_skipped');
    
    // Close dialog and continue with app
    Get.back();
    
    // Show reminder that update is still needed
    Get.snackbar(
      'Update Reminder',
      'Please update the app when convenient for the best experience.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.blue[100],
      colorText: Colors.blue[800],
      duration: const Duration(seconds: 4),
    );
  }
  
  /// ⏰ Remind Later
  /// Sets a reminder for later update
  void _remindLater() {
    // Track remind later action
    trackEvent('force_update_remind_later');
    
    // Close dialog and continue with app
    Get.back();
    
    // Show reminder that update is still needed
    Get.snackbar(
      'Update Reminder',
      'We\'ll remind you to update the app later.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.orange[100],
      colorText: Colors.orange[800],
      duration: const Duration(seconds: 4),
    );
    
    // TODO: Implement actual reminder system (local notification, etc.)
    // This could set a timer to show the update dialog again in 24 hours
  }
}
