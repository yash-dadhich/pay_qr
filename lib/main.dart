import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:upi_payment_qrcode_generator/upi_payment_qrcode_generator.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:lottie/lottie.dart';
import 'services/firebase_service.dart';
import 'widgets/force_update_dialog.dart';
import 'widgets/maintenance_mode_screen.dart';
import 'widgets/qr_scanner_screen.dart';

// ─── Theme ────────────────────────────────────────────────────────────────────
const _bg = Color(0xFFF5F0EB);
const _card = Colors.white;
const _primary = Color(0xFF1A1A2E);   // near-black for text / appbar
const _accent = Color(0xFFC8922A);    // gold / amber accent
const _textSub = Color(0xFF888888);
const _divider = Color(0xFFE8E0D8);

// ─── Entry point ──────────────────────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  final firebaseService = Get.put(FirebaseService());
  await firebaseService.initialize();
  await GetStorage.init();

  runApp(const MyApp());
}

// ─── App ──────────────────────────────────────────────────────────────────────
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Pay QR',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: _bg,
        fontFamily: GoogleFonts.poppins().fontFamily,
        colorScheme: ColorScheme.light(
          primary: _primary,
          secondary: _accent,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

// ─── Splash ───────────────────────────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    _startAnimation();
  }

  void _startAnimation() async {
    _ctrl.forward();
    await Future.delayed(const Duration(seconds: 3));
    final svc = Get.find<FirebaseService>();
    if (svc.isMaintenanceMode) {
      Get.off(() => const MaintenanceModeScreen());
    } else if (svc.isForceUpdateRequired.value) {
      Get.dialog(const ForceUpdateDialog(), barrierDismissible: false);
    } else {
      Get.off(() => const HomeScreen());
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Lottie.asset(
        'assets/splash_animation.json',
        controller: _ctrl,
        onLoaded: (c) => _ctrl.duration = c.duration,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      ),
    );
  }
}

// ─── Controller ───────────────────────────────────────────────────────────────
class UpiController extends GetxController {
  final box = GetStorage();
  final screenshotController = ScreenshotController();
  final upiIds = <Map<String, String>>[].obs;
  final selectedUpi = Rxn<Map<String, String>>();
  final amount = 0.0.obs;
  final split = 1.obs;

  final amountController = TextEditingController();
  final splitController = TextEditingController(text: '1');

  @override
  void onInit() {
    super.onInit();
    final stored = box.read<List<dynamic>>('upiIds');
    if (stored != null) {
      upiIds.assignAll(stored.map((e) => Map<String, String>.from(e)));
    }
    final selected = box.read<Map<String, dynamic>>('selectedUpi');
    if (selected != null) {
      selectedUpi.value = selected.map((k, v) => MapEntry(k, v.toString()));
    }
    amountController.addListener(
        () => amount.value = double.tryParse(amountController.text) ?? 0.0);
    splitController.addListener(
        () => split.value = int.tryParse(splitController.text) ?? 1);
  }

  void saveData() {
    box.write('upiIds', upiIds);
    box.write('selectedUpi', selectedUpi.value);
  }

  bool addNewUpi(String upiId, String name) {
    if (upiIds.any((e) => e['upiId'] == upiId)) {
      Get.snackbar('Warning', 'UPI ID already exists',
          backgroundColor: Colors.orange[100],
          colorText: Colors.orange[900],
          snackPosition: SnackPosition.BOTTOM);
      return false;
    }
    final entry = {'upiId': upiId, 'name': name};
    upiIds.add(entry);
    selectedUpi.value = entry;
    saveData();
    return true;
  }

  bool editUpi(Map<String, String> oldUpi, String newUpiId, String newName) {
    final idx = upiIds.indexOf(oldUpi);
    if (idx == -1) return false;
    if (newUpiId != oldUpi['upiId'] &&
        upiIds.any((e) => e['upiId'] == newUpiId)) {
      Get.snackbar('Warning', 'UPI ID already exists',
          backgroundColor: Colors.orange[100],
          colorText: Colors.orange[900],
          snackPosition: SnackPosition.BOTTOM);
      return false;
    }
    final updated = {'upiId': newUpiId, 'name': newName};
    upiIds[idx] = updated;
    if (selectedUpi.value == oldUpi) selectedUpi.value = updated;
    saveData();
    return true;
  }

  void deleteUpi(Map<String, String> upi) {
    Get.dialog(
      _ConfirmDialog(
        title: 'Delete UPI ID',
        message:
            'Remove "${upi['name']}" (${upi['upiId']})?\nThis cannot be undone.',
        confirmLabel: 'Delete',
        confirmColor: Colors.red,
        onConfirm: () {
          upiIds.remove(upi);
          if (selectedUpi.value == upi) {
            selectedUpi.value = upiIds.isNotEmpty ? upiIds.first : null;
            if (upiIds.isEmpty && (Get.isBottomSheetOpen ?? false)) {
              Get.back(); // close sheet
            }
          }
          saveData();
        },
      ),
    );
  }

  void clearAllUpiIds() {
    Get.dialog(
      _ConfirmDialog(
        title: 'Clear All UPI IDs',
        message: 'This will remove all saved UPI IDs. Are you sure?',
        confirmLabel: 'Clear All',
        confirmColor: Colors.red,
        onConfirm: () {
          upiIds.clear();
          selectedUpi.value = null;
          saveData();
          if (Get.isBottomSheetOpen ?? false) Get.back();
        },
      ),
    );
  }

  void setQuickAmount(double val) {
    amountController.text = val.toStringAsFixed(val == val.roundToDouble() ? 0 : 2);
  }

  bool get canAct => selectedUpi.value != null;

  Future<void> shareQr(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/pay_qr.png');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)], text: 'Scan to pay via UPI');
  }

  Future<String?> saveQr(Uint8List bytes) async {
    try {
      // Android 10+ (API 29+): no permission needed for Downloads folder
      // Android 13+ (API 33+): WRITE_EXTERNAL_STORAGE is removed entirely
      // Just write directly — this works on all modern Android versions
      final downloadsDir = Directory('/storage/emulated/0/Download');
      if (!await downloadsDir.exists()) {
        // Fallback to app external storage if Downloads isn't accessible
        final extDir = await getExternalStorageDirectory();
        if (extDir == null) return null;
        final fallback = Directory('${extDir.path}/PayQR');
        await fallback.create(recursive: true);
        final fileName = 'PayQR_${DateTime.now().millisecondsSinceEpoch}.png';
        await File('${fallback.path}/$fileName').writeAsBytes(bytes);
        return '${fallback.path}/$fileName';
      }
      final fileName = 'PayQR_${DateTime.now().millisecondsSinceEpoch}.png';
      await File('${downloadsDir.path}/$fileName').writeAsBytes(bytes);
      return '${downloadsDir.path}/$fileName';
    } catch (e) {
      return null;
    }
  }
}

// ─── Home Screen ──────────────────────────────────────────────────────────────
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(UpiController());
    final fmt =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _AppBar(c: c),
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Obx(() {
                  final amt = c.amount.value;
                  final sp = c.split.value;
                  final perPerson = sp > 0 ? amt / sp : amt;
                  final upiDetails = c.selectedUpi.value != null
                      ? UPIDetails(
                          upiID: c.selectedUpi.value!['upiId']!,
                          payeeName:
                              c.selectedUpi.value!['name'] ?? 'Receiver',
                          amount: perPerson,
                          transactionNote: 'Split payment',
                        )
                      : null;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // UPI selector row
                      _UpiSelectorRow(c: c),
                      const SizedBox(height: 16),

                      // QR card
                      _QrCard(
                          c: c,
                          upiDetails: upiDetails,
                          amt: amt,
                          sp: sp,
                          perPerson: perPerson,
                          fmt: fmt),
                      const SizedBox(height: 20),

                      // Amount + Split inputs side by side
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: _InputCard(
                              label: 'Total Amount',
                              labelColor: _primary,
                              icon: Icons.currency_rupee_rounded,
                              child: TextField(
                                controller: c.amountController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  hintText: '0',
                                  hintStyle: TextStyle(color: _divider),
                                  contentPadding: EdgeInsets.zero,
                                  isDense: true,
                                ),
                                cursorColor: _accent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: _InputCard(
                              label: 'Split',
                              labelColor: _accent,
                              icon: Icons.group_rounded,
                              child: TextField(
                                controller: c.splitController,
                                keyboardType: TextInputType.number,
                                style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  hintText: '1',
                                  hintStyle: TextStyle(color: _divider),
                                  contentPadding: EdgeInsets.zero,
                                  isDense: true,
                                ),
                                cursorColor: _accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Quick amount chips
                      _QuickAmounts(c: c),
                      const SizedBox(height: 24),
                    ],
                  );
                }),
              ),
            ),
            // Footer pinned at bottom
            const _AppFooter(),
          ],
        ),
      ),
    );
  }
}

// ─── App Bar ──────────────────────────────────────────────────────────────────
class _AppBar extends StatelessWidget {
  final UpiController c;
  const _AppBar({required this.c});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
      child: Row(
        children: [
          // Logo dot + name
          Container(
            width: 10,
            height: 10,
            decoration:
                const BoxDecoration(color: _accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pay QR',
                  style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: _primary)),
              Text('SECURE UPI GENERATOR',
                  style: GoogleFonts.poppins(
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      color: _textSub,
                      letterSpacing: 1.2)),
            ],
          ),
          const Spacer(),
          // Share button
          Obx(() => _IconBtn(
                icon: Icons.ios_share_rounded,
                enabled: c.canAct,
                onTap: () async {
                  final img = await c.screenshotController.capture();
                  if (img != null) {
                    trackEvent('qr_shared', {
                      'upi_name': c.selectedUpi.value?['name'],
                      'amount': c.amount.value.toString(),
                    });
                    await c.shareQr(img);
                  }
                },
              )),
          const SizedBox(width: 4),
          // Save button
          Obx(() => _IconBtn(
                icon: Icons.download_rounded,
                enabled: c.canAct,
                onTap: () async {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Row(
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Saving to Downloads...'),
                        ],
                      ),
                      backgroundColor: Colors.blue[700],
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  final img = await c.screenshotController.capture();
                  if (img != null) {
                    trackEvent('qr_saved', {
                      'upi_name': c.selectedUpi.value?['name'],
                      'amount': c.amount.value.toString(),
                    });
                    final fileName = await c.saveQr(img);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).clearSnackBars();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          fileName != null
                              ? '✓ Saved to Downloads'
                              : '✗ Save failed. Check storage permission.',
                        ),
                        backgroundColor: fileName != null
                            ? Colors.green[700]
                            : Colors.red[700],
                        duration: const Duration(seconds: 3),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              )),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _IconBtn(
      {required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: enabled ? _card : _bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _divider),
        ),
        child: Icon(icon,
            size: 18, color: enabled ? _primary : _divider),
      ),
    );
  }
}

// ─── UPI Selector Row ─────────────────────────────────────────────────────────
class _UpiSelectorRow extends StatelessWidget {
  final UpiController c;
  const _UpiSelectorRow({required this.c});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _showUpiSelector(context, c),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PAY TO ACCOUNT',
                      style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: _textSub,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Obx(() => Text(
                              c.selectedUpi.value?['upiId'] ??
                                  'Select UPI ID',
                              style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: c.selectedUpi.value != null
                                      ? _primary
                                      : _textSub),
                              overflow: TextOverflow.ellipsis,
                            )),
                      ),
                      const Icon(Icons.keyboard_arrow_down_rounded,
                          color: _textSub, size: 20),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Add UPI button
        GestureDetector(
          onTap: () => _showAddUpiSheet(context, c),
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _accent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
          ),
        ),
      ],
    );
  }
}

// ─── QR Card ──────────────────────────────────────────────────────────────────
class _QrCard extends StatelessWidget {
  final UpiController c;
  final UPIDetails? upiDetails;
  final double amt, perPerson;
  final int sp;
  final NumberFormat fmt;

  const _QrCard({
    required this.c,
    required this.upiDetails,
    required this.amt,
    required this.sp,
    required this.perPerson,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: upiDetails != null ? _ActiveQr(c: c, upiDetails: upiDetails!, amt: amt, sp: sp, perPerson: perPerson, fmt: fmt)
                                : const _EmptyQr(),
    );
  }
}

class _EmptyQr extends StatelessWidget {
  const _EmptyQr();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
                color: _bg, shape: BoxShape.circle),
            child: const Icon(Icons.qr_code_2_rounded,
                size: 40, color: _divider),
          ),
          const SizedBox(height: 20),
          Text('Ready to generate',
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: _primary)),
          const SizedBox(height: 6),
          Text('Enter an amount below to create\nyour personal UPI QR code',
              style:
                  GoogleFonts.poppins(fontSize: 13, color: _textSub),
              textAlign: TextAlign.center),
          const SizedBox(height: 28),
          const Divider(color: _divider, height: 1),
          const SizedBox(height: 16),
          _InfoRow(label: 'PAYEE ID', value: 'Select a UPI ID'),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _AmountTile(label: 'TOTAL', value: '₹0'),
              // const SizedBox(width: 16),
              _AmountTile(label: 'PER PERSON', value: '₹0',alignRight: true),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ActiveQr extends StatelessWidget {
  final UpiController c;
  final UPIDetails upiDetails;
  final double amt, perPerson;
  final int sp;
  final NumberFormat fmt;

  const _ActiveQr({
    required this.c,
    required this.upiDetails,
    required this.amt,
    required this.sp,
    required this.perPerson,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Screenshot(
        key: ValueKey(upiDetails.upiID + perPerson.toString()),
        controller: c.screenshotController,
        child: Column(
          children: [
            // QR code with logo overlay at center
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  UPIPaymentQRCode(
                    key: ValueKey(upiDetails.upiID + perPerson.toString()),
                    upiDetails: upiDetails,
                    size: 220,
                    upiQRErrorCorrectLevel: UPIQRErrorCorrectLevel.high,
                  ),
                  // Logo at center of QR
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 4,
                        )
                      ],
                    ),
                    padding: const EdgeInsets.all(4),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.asset(
                        'assets/ic_launcher.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.qr_code_2_rounded,
                          color: _accent,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Divider(color: _divider, height: 1),
            const SizedBox(height: 14),
            _InfoRow(
                label: 'PAYEE ID',
                value: upiDetails.upiID,
                valueColor: _primary,
                bold: true,
                copyable: true),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _AmountTile(
                    label: 'TOTAL',
                    value: fmt.format(amt),
                    valueColor: _primary),
                const SizedBox(width: 16),
                _AmountTile(
                    label: 'PER PERSON',
                    value: fmt.format(perPerson),
                    valueColor: _accent,
                    alignRight: true),
              ],
            ),
            const SizedBox(height: 16),
            // Pay Now button
            GestureDetector(
              onTap: () => _launchUpiPayment(
                context: context,
                upiId: upiDetails.upiID,
                name: upiDetails.payeeName,
                amount: perPerson,
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.payment_rounded,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Pay Now',
                      style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  final bool bold;
  final bool copyable;
  const _InfoRow(
      {required this.label,
      required this.value,
      this.valueColor,
      this.bold = false,
      this.copyable = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: 11,
                color: _textSub,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w500)),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(value,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                      color: valueColor ?? _textSub)),
            ),
            if (copyable) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: value));
                  Get.snackbar('Copied', 'UPI ID copied to clipboard',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.green[100],
                      colorText: Colors.green[900],
                      duration: const Duration(seconds: 2));
                },
                child: const Icon(Icons.copy_rounded,
                    size: 15, color: _textSub),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _AmountTile extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  final bool alignRight;
  const _AmountTile(
      {required this.label, required this.value, this.valueColor, this.alignRight = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment:
            alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: _textSub,
                  letterSpacing: 0.6)),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: valueColor ?? _primary)),
        ],
      ),
    );
  }
}

// ─── Input Card ───────────────────────────────────────────────────────────────
class _InputCard extends StatelessWidget {
  final String label;
  final Color? labelColor;
  final IconData icon;
  final Widget child;

  const _InputCard({
    required this.label,
    required this.icon,
    required this.child,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.4,
                  color: labelColor ?? _primary)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, color: _accent, size: 18),
              const SizedBox(width: 6),
              Expanded(child: child),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Quick Amount Chips ───────────────────────────────────────────────────────
class _QuickAmounts extends StatelessWidget {
  final UpiController c;
  const _QuickAmounts({required this.c});

  static const amounts = [100.0, 500.0, 1000.0, 2000.0, 5000.0];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: amounts
            .map((a) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => c.setQuickAmount(a),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(color: _divider),
                      ),
                      child: Text(
                        '₹${NumberFormat('#,##,###').format(a.toInt())}',
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: _primary),
                      ),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

// ─── UPI Selector Bottom Sheet ────────────────────────────────────────────────
void _showUpiSelector(BuildContext context, UpiController c) {
  Get.bottomSheet(
    Container(
      decoration: const BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
                color: _divider, borderRadius: BorderRadius.circular(2)),
          ),
          // Header
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Select UPI ID',
                    style: GoogleFonts.poppins(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                GestureDetector(
                  onTap: () {
                    FocusScope.of(context).unfocus();
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                        color: _bg,
                        borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.close_rounded,
                        size: 18, color: _textSub),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: _divider, height: 1),
          // List
          Obx(() => ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: c.upiIds.length,
                separatorBuilder: (_, __) =>
                    const Divider(color: _divider, height: 1, indent: 20),
                itemBuilder: (_, i) {
                  final upi = c.upiIds[i];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 4),
                    leading: Obx(() {
                      final selected = c.selectedUpi.value == upi;
                      return GestureDetector(
                        onTap: () {
                          c.selectedUpi.value = upi;
                          c.saveData();
                          Get.back();
                        },
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected ? _accent : _divider,
                              width: 2,
                            ),
                            color: selected ? _accent : Colors.transparent,
                          ),
                          child: selected
                              ? const Icon(Icons.check,
                                  size: 12, color: Colors.white)
                              : null,
                        ),
                      );
                    }),
                    title: Text(upi['name'] ?? '',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: _primary)),
                    subtitle: Text(upi['upiId'] ?? '',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: _textSub)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Copy button
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(
                                ClipboardData(text: upi['upiId'] ?? ''));
                            Get.snackbar('Copied', 'UPI ID copied to clipboard',
                                snackPosition: SnackPosition.BOTTOM,
                                backgroundColor: Colors.green[100],
                                colorText: Colors.green[900],
                                duration: const Duration(seconds: 2));
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(8)),
                            child: Icon(Icons.copy_rounded,
                                size: 16, color: Colors.blue[400]),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Edit button
                        GestureDetector(
                          onTap: () =>
                              _showAddUpiSheet(context, c, editUpi: upi),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                                color: Colors.orange[50],
                                borderRadius: BorderRadius.circular(8)),
                            child: Icon(Icons.edit_outlined,
                                size: 16, color: Colors.orange[600]),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Delete button
                        GestureDetector(
                          onTap: () => c.deleteUpi(upi),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                                color: Colors.red[50],
                                borderRadius: BorderRadius.circular(8)),
                            child: Icon(Icons.delete_outline_rounded,
                                size: 16, color: Colors.red[400]),
                          ),
                        ),
                      ],
                    ),
                    onTap: () {
                      c.selectedUpi.value = upi;
                      c.saveData();
                      Get.back();
                    },
                  );
                },
              )),
          // Clear All
          Padding(
            padding: const EdgeInsets.all(16),
            child: GestureDetector(
              onTap: () => c.clearAllUpiIds(),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                    border: Border.all(color: _divider),
                    borderRadius: BorderRadius.circular(14)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.delete_sweep_rounded,
                        size: 18, color: _textSub),
                    const SizedBox(width: 8),
                    Text('Clear All',
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: _textSub,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    ),
    isScrollControlled: true,
  );
}

// ─── Add / Edit UPI Bottom Sheet ─────────────────────────────────────────────
void _showAddUpiSheet(BuildContext context, UpiController c,
    {Map<String, String>? editUpi}) {
  final upiCtrl =
      TextEditingController(text: editUpi != null ? editUpi['upiId'] : '');
  final nameCtrl =
      TextEditingController(text: editUpi != null ? editUpi['name'] : '');
  final isEdit = editUpi != null;
  Get.bottomSheet(
    Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: _divider,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            // Header
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    FocusScope.of(context).unfocus();
                    Navigator.of(context).pop();
                  },
                  child: const Icon(Icons.close_rounded,
                      color: _primary, size: 22),
                ),
                const SizedBox(width: 12),
                Text(isEdit ? 'Edit UPI ID' : 'Add UPI ID',
                    style: GoogleFonts.poppins(
                        fontSize: 18, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 24),
            // UPI ID field
            // UPI ID field + scan button
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _SheetField(
                    controller: upiCtrl,
                    hint: 'UPI ID (e.g., user@bank)',
                    prefixIcon: Icons.alternate_email_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () async {
                    final result = await Navigator.of(context).push<UpiScanResult>(
                      MaterialPageRoute(
                          builder: (_) => const QrScannerScreen()),
                    );
                    if (result != null) {
                      upiCtrl.text = result.upiId;
                      if (nameCtrl.text.isEmpty) {
                        nameCtrl.text = result.name;
                      }
                    }
                  },
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: _primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.qr_code_scanner_rounded,
                        color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Name field
            _SheetField(
              controller: nameCtrl,
              hint: 'Display Name (e.g., Personal, Business)',
              prefixIcon: Icons.person_outline_rounded,
            ),
            const SizedBox(height: 16),
            // Info box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(12)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 18, color: _accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Adding a UPI ID allows you to request and receive payments directly to your chosen bank account linked with this ID.',
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: _textSub, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Add / Save button
            GestureDetector(
              onTap: () {
                final upiId = upiCtrl.text.trim();
                final name = nameCtrl.text.trim();
                if (upiId.isEmpty || name.isEmpty) {
                  Get.snackbar('Missing Fields',
                      'Please fill in both fields.',
                      snackPosition: SnackPosition.BOTTOM);
                  return;
                }
                final success = isEdit
                    ? c.editUpi(editUpi, upiId, name)
                    : c.addNewUpi(upiId, name);
                if (success) {
                  FocusScope.of(context).unfocus();
                  Navigator.of(context).pop();
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                    color: _primary,
                    borderRadius: BorderRadius.circular(14)),
                child: Text(isEdit ? 'Save Changes' : 'Add UPI ID',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    ),
    isScrollControlled: true,
  );
}

class _SheetField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData prefixIcon;

  const _SheetField({
    required this.controller,
    required this.hint,
    required this.prefixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: _divider),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        style: GoogleFonts.poppins(fontSize: 14, color: _primary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              GoogleFonts.poppins(fontSize: 14, color: _textSub),
          prefixIcon:
              Icon(prefixIcon, color: _textSub, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 14),
        ),
        cursorColor: _accent,
      ),
    );
  }
}

// ─── UPI Payment Launcher ─────────────────────────────────────────────────────
Future<void> _launchUpiPayment({
  required BuildContext context,
  required String upiId,
  required String name,
  required double amount,
}) async {
  final amountStr = amount > 0 ? amount.toStringAsFixed(2) : '0.00';

  // Build UPI deep link as a plain encoded URI string
  // Format: upi://pay?pa=<upi_id>&pn=<name>&am=<amount>&cu=INR
  final uriString =
      'upi://pay?pa=${Uri.encodeComponent(upiId)}'
      '&pn=${Uri.encodeComponent(name)}'
      '&am=$amountStr'
      '&cu=INR'
      '&tn=${Uri.encodeComponent('Payment via Pay QR')}';

  final uri = Uri.parse(uriString);

  try {
    // On Android 11+ canLaunchUrl needs the scheme declared in queries
    // Skip canLaunchUrl check and try directly — catches exception if no app
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
            'No UPI app found. Please install GPay, PhonePe or any UPI app.'),
        backgroundColor: Colors.orange[700],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

// ─── Confirmation Dialog ──────────────────────────────────────────────────────
class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final Color confirmColor;
  final VoidCallback onConfirm;

  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.confirmColor,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: confirmColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.warning_amber_rounded,
                  color: confirmColor, size: 28),
            ),
            const SizedBox(height: 16),
            // Title
            Text(title,
                style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _primary)),
            const SizedBox(height: 8),
            // Message
            Text(message,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 13, color: _textSub, height: 1.5)),
            const SizedBox(height: 24),
            // Buttons
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        border: Border.all(color: _divider),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('Cancel',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _textSub)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                      onConfirm();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        color: confirmColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(confirmLabel,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── App Footer ───────────────────────────────────────────────────────────────
class _AppFooter extends StatelessWidget {
  const _AppFooter();

  static const _storeUrl =
      'https://play.google.com/store/apps/details?id=com.sylionixtech.payqr';

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _shareApp() async {
    await SharePlus.instance.share(
      ShareParams(
        text:
            '💸 Pay QR — Split bills & generate UPI QR codes instantly!\n\nDownload now: $_storeUrl',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _divider, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Built with love
          RichText(
            text: TextSpan(
              style: GoogleFonts.poppins(fontSize: 12, color: _textSub),
              children: const [
                TextSpan(text: 'Built with '),
                TextSpan(text: '❤️', style: TextStyle(fontSize: 13)),
                TextSpan(text: ' by '),
                TextSpan(
                    text: 'Yashhh',
                    style: TextStyle(
                        color: _accent, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Rate & Share buttons
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _openUrl(
                      'market://details?id=com.sylionixtech.payqr'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _bg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _divider),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 16, color: _accent),
                        const SizedBox(width: 6),
                        Text('Rate App',
                            style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: _primary)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: _shareApp,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _bg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _divider),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.ios_share_rounded,
                            size: 16, color: _accent),
                        const SizedBox(width: 6),
                        Text('Share App',
                            style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: _primary)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
