import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import '../services/firebase_service.dart';
import '../main.dart'; // Import to access UpiQrGenerator

/// 🚧 Maintenance Mode Screen
/// This screen appears when Firebase Remote Config sets maintenance_mode to true
/// 
/// Memory Trick: Think of this as your "Under Construction" sign
/// 
/// Features:
/// - Shows maintenance message
/// - Prevents app access
/// - Auto-refreshes to check if maintenance is over
/// - Professional maintenance UI
class MaintenanceModeScreen extends StatefulWidget {
  const MaintenanceModeScreen({super.key});

  @override
  State<MaintenanceModeScreen> createState() => _MaintenanceModeScreenState();
}

class _MaintenanceModeScreenState extends State<MaintenanceModeScreen> {
  @override
  void initState() {
    super.initState();
    // Start auto-refresh to check if maintenance is over
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    // Check every 30 seconds if maintenance is over
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted) {
        _checkMaintenanceStatus();
      }
    });
  }

  Future<void> _checkMaintenanceStatus() async {
    try {
      // Refresh Remote Config
      await FirebaseService.instance.refreshRemoteConfig();
      
      // Check if maintenance mode is still active
      if (!FirebaseService.instance.isMaintenanceMode) {
        // Maintenance is over, navigate back to app
        Get.offAll(() => const UpiQrGenerator());
      } else {
        // Still in maintenance, schedule next check
        _startAutoRefresh();
      }
    } catch (e) {
      // If error, schedule next check
      _startAutoRefresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.orange[50],
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 🚧 Maintenance Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(60),
                ),
                child: Icon(
                  Icons.construction,
                  size: 60,
                  color: Colors.orange[700],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // 🚧 Title
              Text(
                'Under Maintenance',
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[800],
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 16),
              
              // 📢 Message
              Obx(() => Text(
                FirebaseService.instance.maintenanceMessage,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              )),
              
              const SizedBox(height: 24),
              
              // ⏰ Estimated Time
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.schedule, color: Colors.blue[600], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Estimated time: 15-30 minutes',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // 🔄 Refresh Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () => _checkMaintenanceStatus(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[600],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  icon: const Icon(Icons.refresh, size: 20),
                  label: Text(
                    'Check Again',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // ℹ️ Info Text
              Text(
                'We\'ll automatically check for you every 30 seconds',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 24),
              
              // 🎨 Optional: Lottie Animation
              SizedBox(
                height: 100,
                child: Lottie.asset(
                  'assets/splash_animation.json',
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
