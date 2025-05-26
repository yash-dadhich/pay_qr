import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:upi_payment_qrcode_generator/upi_payment_qrcode_generator.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
  runApp(const MyApp());
}

// Theme Controller
class ThemeController extends GetxController {
  final isDarkMode = false.obs;

  ThemeController() {
    isDarkMode.value = GetStorage().read('isDarkMode') ?? false;
  }

  void toggleTheme() {
    isDarkMode.value = !isDarkMode.value;
    Get.changeThemeMode(isDarkMode.value ? ThemeMode.dark : ThemeMode.light);
    GetStorage().write('isDarkMode', isDarkMode.value);
  }
}

// UPI Controller
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

    amountController.addListener(() {
      final value = double.tryParse(amountController.text) ?? 0.0;
      amount.value = value;
    });

    splitController.addListener(() {
      final value = int.tryParse(splitController.text) ?? 1;
      split.value = value;
    });
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
    if (selectedUpi.value == upi) selectedUpi.value = null;
    saveData();
  }

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
}

// Main App
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.put(ThemeController());
    return Obx(() {
      return GetMaterialApp(
        title: 'Pay QR',
        themeMode: themeController.isDarkMode.value ? ThemeMode.dark : ThemeMode.light,
        theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
        darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
        debugShowCheckedModeBanner: false,
        home: const UpiQrGenerator(),
      );
    });
  }
}

// Main Screen
class UpiQrGenerator extends StatelessWidget {
  const UpiQrGenerator({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(UpiController());
    final themeController = Get.find<ThemeController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("UPI QR Generator"),
        actions: [
          Obx(() => Switch(
            value: themeController.isDarkMode.value,
            onChanged: (_) => themeController.toggleTheme(),
          )),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () async {
              final image = await c.screenshotController.capture();
              if (image != null) c.shareQr(image);
            },
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () async {
              final image = await c.screenshotController.capture();
              if (image != null) c.saveQr(image);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
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

          return Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(c.selectedUpi.value != null
                      ? "Selected: ${c.selectedUpi.value!['name']}"
                      : "No UPI selected"),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.expand_more),
                        onPressed: () => _showUpiSelector(context, c),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text("Add UPI"),
                        onPressed: () => _showAddUpiSheet(context, c),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (upiDetails != null)
                Screenshot(
                  controller: c.screenshotController,
                  child: Column(
                    children: [
                      const Text("Generated UPI QR Code",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: UPIPaymentQRCode(
                          upiDetails: upiDetails,
                          size: 200,
                          upiQRErrorCorrectLevel: UPIQRErrorCorrectLevel.low,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Amount per person: ₹${splitAmount.toStringAsFixed(2)} | Split: $split",
                        style: const TextStyle(fontSize: 16),
                      ),
                      Text("Pay to: ${c.selectedUpi.value!['upiId']}",
                          style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: c.amountController,
                      decoration: const InputDecoration(
                        labelText: "Enter Total Amount",
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: TextField(
                      controller: c.splitController,
                      decoration: const InputDecoration(
                        labelText: "Split Count",
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
            ],
          );
        }),
      ),
    );
  }

  void _showAddUpiSheet(BuildContext context, UpiController c) {
    final upiController = TextEditingController();
    final nameController = TextEditingController();

    final isDark = Get.isDarkMode;
    final backgroundColor = isDark ? Colors.grey[850] : Colors.grey[200];
    final textColor = isDark ? Colors.white : Colors.black87;
    final fillColor = isDark ? Colors.grey[800] : Colors.white;

    Get.bottomSheet(
      Theme(
        data: Get.theme.copyWith(
          bottomSheetTheme: BottomSheetThemeData(
            backgroundColor: backgroundColor,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            fillColor: fillColor,
            filled: true,
          ),
          textTheme: TextTheme(
            titleLarge: TextStyle(color: textColor),
            bodyMedium: TextStyle(color: textColor),
          ),
        ),
        child: Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Add UPI ID",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor)),
              const SizedBox(height: 10),
              TextField(
                controller: upiController,
                decoration: InputDecoration(
                  labelText: 'Enter UPI ID',
                  border: const OutlineInputBorder(),
                  fillColor: fillColor,
                  filled: true,
                ),
                style: TextStyle(color: textColor),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Enter Name / Bank',
                  border: const OutlineInputBorder(),
                  fillColor: fillColor,
                  filled: true,
                ),
                style: TextStyle(color: textColor),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  final upi = upiController.text.trim();
                  final name = nameController.text.trim();
                  if (upi.isNotEmpty && name.isNotEmpty) {
                    c.addNewUpi(upi, name);
                    Get.back();
                  }
                },
                child: const Text("Add"),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  void _showUpiSelector(BuildContext context, UpiController c) {
    final isDark = Get.isDarkMode;
    final backgroundColor = isDark ? Colors.grey[850] : Colors.grey[200];
    final textColor = isDark ? Colors.white : Colors.black87;

    Get.bottomSheet(
      Theme(
        data: Get.theme.copyWith(
          bottomSheetTheme: BottomSheetThemeData(
            backgroundColor: backgroundColor,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
          ),
          textTheme: TextTheme(
            titleLarge: TextStyle(color: textColor),
            bodyMedium: TextStyle(color: textColor),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Select UPI ID",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor)),
              const SizedBox(height: 10),
              Obx(() => Column(
                children: c.upiIds
                    .map((upi) => ListTile(
                  title: Text(upi['name'] ?? '',
                      style: TextStyle(color: textColor)),
                  subtitle: Text(upi['upiId'] ?? '',
                      style: TextStyle(color: textColor)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => c.deleteUpi(upi),
                  ),
                  onTap: () {
                    c.selectedUpi.value = upi;
                    c.saveData();
                    Get.back();
                  },
                ))
                    .toList(),
              )),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }
}
