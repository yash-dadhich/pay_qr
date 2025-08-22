import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:upi_payment_qrcode_generator/upi_payment_qrcode_generator.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:lottie/lottie.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'services/firebase_service.dart';
import 'services/logging_service.dart';
import 'services/secure_admob_service.dart';
import 'widgets/force_update_dialog.dart';
import 'widgets/maintenance_mode_screen.dart';

// TODO: Replace 'assets/splash_animation.json' with your actual Lottie file path
// Place your Lottie file in the assets folder and update the path below
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase first (Power Switch)
  final firebaseService = Get.put(FirebaseService());
  await firebaseService.initialize();
  
  // Initialize other services
  await GetStorage.init();
  
  // Set test device IDs here
  // await MobileAds.instance.updateRequestConfiguration(
  //   RequestConfiguration(testDeviceIds: ['ca-app-pub-3940256099942544/5224354917']),
  // );
  MobileAds.instance.initialize(); // Initialize Google Mobile Ads SDK
  
  runApp(const MyApp());
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _startAnimation();
  }

  void _startAnimation() async {
    // Start Lottie animation
    _animationController.forward();
    
    // Wait for animation to complete
    await Future.delayed(const Duration(seconds: 3));
    
    logDebug('Splash animation completed, checking Firebase...');
    
    // Check for maintenance mode first
    final firebaseService = Get.find<FirebaseService>();
    
    logDebug('Checking maintenance mode...');
    logDebug('isMaintenanceMode: ${firebaseService.isMaintenanceMode}');
    
    if (firebaseService.isMaintenanceMode) {
      logDebug('Maintenance mode active, showing maintenance screen');
      // Show maintenance mode screen
      Get.off(() => const MaintenanceModeScreen());
    } else {
      logDebug('No maintenance mode, checking force update...');
      logDebug('isForceUpdateRequired: ${firebaseService.isForceUpdateRequired.value}');
      
      if (firebaseService.isForceUpdateRequired.value) {
        logDebug('Force update required, showing dialog');
        // Show force update dialog
        Get.dialog(
          const ForceUpdateDialog(),
          barrierDismissible: false,
        );
      } else {
        logDebug('No force update required, continuing to main app');
        // Navigate to main app
        Get.off(() => const UpiQrGenerator());
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Lottie.asset(
        'assets/splash_animation.json',
        controller: _animationController,
        onLoaded: (composition) {
          _animationController.duration = composition.duration;
        },
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      ),
    );
  }
}

class UpiController extends GetxController {
  final box = GetStorage();
  final screenshotController = ScreenshotController();
  final upiIds = <Map<String, String>>[].obs;
  final selectedUpi = Rxn<Map<String, String>>();
  final amount = 0.0.obs;
  final split = 1.obs;

  final amountController = TextEditingController();
  final splitController = TextEditingController(text: '1');

  // Rewarded Ad
  RewardedAd? rewardedAd;
  var isAdReady = false.obs;

  @override
  void onInit() {
    super.onInit();

    final stored = box.read<List<dynamic>>('upiIds');
    if (stored != null) upiIds.assignAll(stored.map((e) => Map<String, String>.from(e)));

    final selected = box.read<Map<String, dynamic>>('selectedUpi');
    if (selected != null) selectedUpi.value = selected.map((k, v) => MapEntry(k, v.toString()));

    amountController.addListener(() {
      amount.value = double.tryParse(amountController.text) ?? 0.0;
    });

    splitController.addListener(() {
      split.value = int.tryParse(splitController.text) ?? 1;
    });

    _loadRewardedAd();
  }

  void saveData() {
    box.write('upiIds', upiIds);
    box.write('selectedUpi', selectedUpi.value);
  }

  void addNewUpi(String upiId, String name) {
    if (upiIds.any((e) => e['upiId'] == upiId)) {
      Get.snackbar("Warning", "UPI ID already exists");
      return;
    }
    final newUpi = {'upiId': upiId, 'name': name};
    upiIds.add(newUpi);
    selectedUpi.value = newUpi;
    saveData();
  }

  void deleteUpi(Map<String, String> upi) {
    upiIds.remove(upi);
    if (selectedUpi.value == upi) {
      selectedUpi.value = null;
      // If this was the last UPI, close the dialog
      if (upiIds.isEmpty) {
        Get.back();
      }
    }
    saveData();
  }

  void clearAllUpiIds() {
    upiIds.clear();
    selectedUpi.value = null;
    saveData();
    // Close any open dialogs
    if (Get.isBottomSheetOpen ?? false) {
      Get.back();
    }
  }

  bool get canShareOrSave => selectedUpi.value != null;

  Future<void> shareQr(Uint8List imageBytes) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/upi_qr.png');
    await file.writeAsBytes(imageBytes);
    await Share.shareXFiles([XFile(file.path)], text: 'Scan to pay via UPI');
  }

  Future<void> saveQr(Uint8List imageBytes) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/upi_qr_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(imageBytes);
    Get.snackbar("Saved", "Saved to: ${file.path}");
  }

  void _loadRewardedAd() async {
    // Get AdMob key securely from native code
    final adUnitId = await getSecureRewardedAdUnitId();
    
    RewardedAd.load(
        adUnitId: adUnitId, // Secure AdMob key
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          rewardedAd = ad;
          isAdReady.value = true;

          rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              isAdReady.value = false;
              rewardedAd?.dispose();
              _loadRewardedAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              isAdReady.value = false;
              rewardedAd?.dispose();
              _loadRewardedAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          isAdReady.value = false;
          rewardedAd = null;
          logError('RewardedAd failed to load', error, StackTrace.current);
          // Retry loading after some delay or logic if needed
        },
      ),
    );
  }

  void showRewardedAd(VoidCallback onRewardEarned) {
    if (isAdReady.value && rewardedAd != null) {
      rewardedAd!.show(onUserEarnedReward: (ad, reward) {
        onRewardEarned();
      });
    } else {
      Get.snackbar("Ad Not Ready", "Please try again later.");
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Pay QR',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        textTheme: const TextTheme(bodyMedium: TextStyle(fontSize: 16, color: Colors.black)),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[700],
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.blue[50],
          labelStyle: const TextStyle(color: Colors.black),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blue[700],
          foregroundColor: Colors.white,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

class UpiQrGenerator extends StatefulWidget {
  const UpiQrGenerator({super.key});

  @override
  State<UpiQrGenerator> createState() => _UpiQrGeneratorState();
}

class _UpiQrGeneratorState extends State<UpiQrGenerator> {
  @override
  void initState() {
    super.initState();
    // Track screen view for analytics
    WidgetsBinding.instance.addPostFrameCallback((_) {
      trackScreen('UPI QR Generator');
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = Get.put(UpiController());
    final formatCurrency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Pay QR",
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        actions: [
          // Test button for Firebase status
          // IconButton(
          //   icon: const Icon(Icons.bug_report, color: Colors.white),
          //   onPressed: () => _testFirebaseStatus(c),
          //   tooltip: "Test Firebase Status",
          // ),
          // Test button for logging system
          // IconButton(
          //   icon: const Icon(Icons.bug_report, color: Colors.white),
          //   onPressed: () => _testLoggingSystem(),
          //   tooltip: "Test Logging System",
          // ),
          Obx(() => IconButton(
            icon: Icon(
              Icons.share,
              color: c.canShareOrSave ? Colors.white : Colors.white.withOpacity(0.3),
            ),
            onPressed: c.canShareOrSave ? () async {
              // Show rewarded ad before sharing
              c.showRewardedAd(() async {
                final image = await c.screenshotController.capture();
                if (image != null) {
                  // Track share action for analytics
                  trackEvent('qr_shared', {
                    'upi_name': c.selectedUpi.value?['name'],
                    'amount': c.amount.value.toString(),
                    'split': c.split.value.toString(),
                  });
                  
                  await c.shareQr(image);
                }
              });
            } : null,
            tooltip: c.canShareOrSave ? "Share QR Code" : "Select a UPI ID to share",
          )),
          Obx(() => IconButton(
            icon: Icon(
              Icons.save,
              color: c.canShareOrSave ? Colors.white : Colors.white.withOpacity(0.3),
            ),
            onPressed: c.canShareOrSave ? () async {
              // Show rewarded ad before saving
              c.showRewardedAd(() async {
                final image = await c.screenshotController.capture();
                if (image != null) {
                  // Track save action for analytics
                  trackEvent('qr_saved', {
                    'upi_name': c.selectedUpi.value?['name'],
                    'amount': c.amount.value.toString(),
                    'split': c.split.value.toString(),
                  });
                  
                  await c.saveQr(image);
                }
              });
            } : null,
            tooltip: c.canShareOrSave ? "Save QR Code" : "Select a UPI ID to save",
          )),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Obx(() {
          final amount = c.amount.value;
          final split = c.split.value;
          final splitAmount = split > 0 ? amount / split : amount;
          final upiDetails = c.selectedUpi.value != null
              ? UPIDetails(
            upiID: c.selectedUpi.value!['upiId']!,
            payeeName: c.selectedUpi.value!['name'] ?? "Receiver",
            amount: splitAmount,
            transactionNote: "Split payment",
          )
              : null;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap:  () => _showUpiSelector(context, c),
                        child: Container(
                          padding: EdgeInsets.only(left: 8,),
                          decoration: BoxDecoration(
                            color: Colors.white, // background (optional)
                            borderRadius: BorderRadius.circular(12), // rounded corners
                            border: Border.all(
                              color: Colors.blue[700]!, // stroke color
                              width: 2,           // stroke width
                            ),),
                          // constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width *.48) ,
                          child: Row(
                            children: [
                              SizedBox(
                                width:MediaQuery.of(context).size.width *.40,
                                child: Text(
                                  c.selectedUpi.value != null
                                      ? "${c.selectedUpi.value!['name']}"
                                      : "No UPI selected",
                                  style: GoogleFonts.poppins(color: Colors.black87),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                        Spacer(),
                              IconButton(
                                icon: Icon(Icons.expand_more,color: Colors.blue[700]!,),
                                onPressed: () => _showUpiSelector(context, c),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4,),
                    ElevatedButton.icon(
                      style: ButtonStyle(
                        padding: MaterialStateProperty.all(
                          const EdgeInsets.symmetric(vertical: 4, horizontal: 12), // 👈 vertical = 4
                        ),
                      ),
                      icon: const Icon(Icons.add),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10.0),
                        child: Text(
                          "Add UPI",
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                      ),
                      onPressed: () => _showAddUpiSheet(context, c),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                upiDetails != null
                    ? Screenshot(
                  key: ValueKey(upiDetails.upiID + splitAmount.toString()),
                  controller: c.screenshotController,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Paying to:",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                              color: Colors.grey[700], fontSize: 12),
                        ),
                        Text(
                          c.selectedUpi.value!['upiId']!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                              color: Colors.blue[700], fontSize: 18,fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 14),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 700),
                          transitionBuilder:
                              (Widget child, Animation<double> animation) {
                            return FadeTransition(
                              opacity: CurvedAnimation(
                                  parent: animation, curve: Curves.easeInOut),
                              child: ScaleTransition(
                                scale: CurvedAnimation(
                                    parent: animation, curve: Curves.easeInOut),
                                child: child,
                              ),
                            );
                          },
                          child: UPIPaymentQRCode(
                            upiDetails: upiDetails,
                            size: 240,
                            upiQRErrorCorrectLevel: UPIQRErrorCorrectLevel.low,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text("Scan the QR to pay",
                            style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black)),
                        const SizedBox(height: 6),
                        Text(
                          formatCurrency.format(splitAmount),
                          style: GoogleFonts.poppins(
                              color: Colors.blue[700],
                              fontSize: 28,
                              fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Text(
                              "Total: $amount",
                              style: GoogleFonts.poppins(
                                  color: Colors.black,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700),
                            ),
                            Text(
                              "Splits: $split",
                              style: GoogleFonts.poppins(
                                  color: Colors.black,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )
                    : Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey[300]!, width: 2),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 240,
                              height: 240,
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey[300]!, width: 1),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.qr_code_scanner_outlined,
                                    size: 80,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    "No UPI Selected",
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "Select a UPI ID to generate QR code",
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.grey[500],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Disabled functions info
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.orange[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.orange[200]!, width: 1),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.orange[600],
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "Share & Save functions are disabled until you select a UPI ID",
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        color: Colors.orange[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              "Amount: ${formatCurrency.format(amount)}",
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                            if (split > 1) ...[
                              const SizedBox(height: 8),
                              Text(
                                "Split into: $split parts",
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Per person: ${formatCurrency.format(splitAmount)}",
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.blue[700],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          textSelectionTheme: TextSelectionThemeData(
                            cursorColor: Colors.blue[700],         // 👈 blinking line
                            selectionColor: Colors.blue[700]?.withOpacity(0.3), // 👈 background of selected text
                            selectionHandleColor: Colors.blue[700], // 👈 the draggable handle color
                          ),
                        ),
                        child: TextField(
                          controller: c.amountController,
                          keyboardType: TextInputType.number,
                          style: GoogleFonts.poppins(),
                          cursorColor: Colors.blue[700],

                          decoration: InputDecoration(
                            labelText: "Total Amount",
                            labelStyle: GoogleFonts.poppins(color: Colors.grey), // default
                            floatingLabelStyle: GoogleFonts.poppins(color: Colors.blue[700]), // when focused
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey[500]!, width: 1.5), // default color
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.blue[700]!, width: 2.0), // when selected
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child:
                      Theme(
                        data: Theme.of(context).copyWith(
                          textSelectionTheme: TextSelectionThemeData(
                            cursorColor: Colors.blue[700],         // 👈 blinking line
                            selectionColor: Colors.blue[700]?.withOpacity(0.3), // 👈 background of selected text
                            selectionHandleColor: Colors.blue[700], // 👈 the draggable handle color
                          ),
                        ),
                        child: TextField(
                        controller: c.splitController,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.poppins(),
                        decoration: InputDecoration(
                          labelText: "Split",
                          labelStyle: GoogleFonts.poppins(color: Colors.grey), // default
                          floatingLabelStyle: GoogleFonts.poppins(color: Colors.blue[700]),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey[500]!, width: 1.5), // default color
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.blue[700]!, width: 2.0), // when selected
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      )),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  void _showUpiSelector(BuildContext context, UpiController c) {
    Get.bottomSheet(
      Container(
        color: Colors.white,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with Clear All button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Select UPI ID",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (c.upiIds.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        Get.dialog(
                          AlertDialog(
                            title: Text(
                              "Clear All UPI IDs",
                              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                            ),
                            content: Text(
                              "Are you sure you want to delete all saved UPI IDs? This action cannot be undone.",
                              style: GoogleFonts.poppins(),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Get.back(),
                                child: Text(
                                  "Cancel",
                                  style: GoogleFonts.poppins(color: Colors.grey),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Get.back();
                                  c.clearAllUpiIds();
                                },
                                child: Text(
                                  "Clear All",
                                  style: GoogleFonts.poppins(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Text(
                        "Clear All",
                        style: GoogleFonts.poppins(color: Colors.red),
                      ),
                    ),
                ],
              ),
            ),
            // UPI List or Empty State
            Expanded(
              child: Obx(() {
                if (c.upiIds.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey[300]!, width: 1),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.account_balance_wallet_outlined,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Empty",
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "No UPI IDs saved",
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Add a new UPI ID to get started",
                          style: GoogleFonts.poppins(
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () {
                            Get.back();
                            _showAddUpiSheet(context, c);
                          },
                          child: Text(
                            "Add UPI ID",
                            style: GoogleFonts.poppins(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                return ListView(
                  shrinkWrap: true,
                  children: c.upiIds
                      .map((upi) => ListTile(
                    title: Text(
                      upi['name'] ?? "",
                      style: GoogleFonts.poppins(color: Colors.black),
                    ),
                    subtitle: Text(
                      upi['upiId'] ?? "",
                      style: GoogleFonts.poppins(color: Colors.black),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => c.deleteUpi(upi),
                    ),
                    onTap: () {
                      c.selectedUpi.value = upi;
                      c.saveData();
                      
                      // Track UPI selection for analytics
                      trackEvent('upi_selected', {
                        'upi_name': upi['name'],
                        'upi_id': upi['upiId'],
                      });
                      
                      Get.back();
                    },
                  ))
                      .toList(),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddUpiSheet(BuildContext context, UpiController c) {
    final upiIdController = TextEditingController();
    final nameController = TextEditingController();

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius:
          BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Add UPI ID",
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Theme(
              data: Theme.of(context).copyWith(
                textSelectionTheme: TextSelectionThemeData(
                  cursorColor: Colors.blue[700],         // 👈 blinking line
                  selectionColor: Colors.blue[700]?.withOpacity(0.3), // 👈 background of selected text
                  selectionHandleColor: Colors.blue[700], // 👈 the draggable handle color
                ),
              ),
              child:TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: "Name / Bank",
                labelStyle: GoogleFonts.poppins(color: Colors.grey), // default
                floatingLabelStyle: GoogleFonts.poppins(color: Colors.blue[700]),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey[500]!, width: 1.5), // default color
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue[700]!, width: 2.0), // when selected
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),),
            const SizedBox(height: 12),
        Theme(
          data: Theme.of(context).copyWith(
            textSelectionTheme: TextSelectionThemeData(
              cursorColor: Colors.blue[700],         // 👈 blinking line
              selectionColor: Colors.blue[700]?.withOpacity(0.3), // 👈 background of selected text
              selectionHandleColor: Colors.blue[700], // 👈 the draggable handle color
            ),
          ),
          child: TextField(
              controller: upiIdController,
              decoration: InputDecoration(
                labelText: "UPI ID",
                labelStyle: GoogleFonts.poppins(color: Colors.grey), // default
                floatingLabelStyle: GoogleFonts.poppins(color: Colors.blue[700]),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey[500]!, width: 1.5), // default color
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue[700]!, width: 2.0), // when selected
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
          ),),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final upiId = upiIdController.text.trim();
                final name = nameController.text.trim();
                if (upiId.isEmpty || name.isEmpty) {
                  Get.snackbar("Error", "Please enter all fields");
                  return;
                }
                
                // Track UPI addition for analytics
                trackEvent('upi_added', {
                  'upi_name': name,
                  'upi_id': upiId,
                });
                
                c.addNewUpi(upiId, name);
                Get.back();
              },
              child: const Text("Add"),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }



  void _testLoggingSystem() {
    logDebug('This is a debug message.');
    logInfo('This is an info message.');
    logWarning('This is a warning message.');
    logError('This is an error message.');
    logCritical('This is a critical message.');

    Get.snackbar(
      "Logging Test",
      "Debug, Info, Warning, Error, Critical messages have been logged. Check console.",
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.blue[100],
      colorText: Colors.blue[800],
    );
  }
}

