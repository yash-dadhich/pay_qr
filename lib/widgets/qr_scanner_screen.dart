import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';

const _accent = Color(0xFFC8922A);
const _primary = Color(0xFF1A1A2E);

/// Result returned after a successful scan
class UpiScanResult {
  final String upiId;
  final String name;
  UpiScanResult({required this.upiId, required this.name});
}

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  MobileScannerController? _ctrl;
  bool _processed = false;
  bool _torchOn = false;
  String? _error;
  bool _permissionDenied = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    // Request camera permission first
    final status = await Permission.camera.request();
    if (!mounted) return;

    if (status.isGranted) {
      _ctrl = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        facing: CameraFacing.back,
      );
      setState(() => _loading = false);
    } else if (status.isPermanentlyDenied) {
      setState(() {
        _permissionDenied = true;
        _loading = false;
      });
    } else {
      setState(() {
        _permissionDenied = true;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  /// Parse UPI deep link or raw UPI ID from scanned QR code
  UpiScanResult? _parseUpiQr(String raw) {
    try {
      final cleanRaw = raw.trim();
      if (cleanRaw.isEmpty) return null;

      // 1. Check if it's a UPI URI or HTTP/HTTPS redirection URL containing a 'pa' parameter
      if (cleanRaw.toLowerCase().startsWith('upi://') ||
          cleanRaw.toLowerCase().startsWith('http://') ||
          cleanRaw.toLowerCase().startsWith('https://')) {
        final uri = Uri.parse(cleanRaw);
        final pa = uri.queryParameters['pa'];
        final pn = uri.queryParameters['pn'];
        if (pa != null && pa.trim().isNotEmpty) {
          final cleanPa = pa.trim();
          if (cleanPa.contains('@')) {
            return UpiScanResult(
              upiId: cleanPa,
              name: (pn != null && pn.trim().isNotEmpty) ? Uri.decodeComponent(pn.trim()) : cleanPa,
            );
          }
        }
      }

      // 2. Check if the scanned text is a direct raw UPI ID (e.g., name@bank)
      if (cleanRaw.contains('@') && !cleanRaw.contains(' ') && !cleanRaw.contains('/') && !cleanRaw.contains('?')) {
        final parts = cleanRaw.split('@');
        if (parts.length == 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
          return UpiScanResult(
            upiId: cleanRaw,
            name: cleanRaw,
          );
        }
      }
    } catch (_) {}
    return null;
  }

  void _onDetect(BarcodeCapture capture) {
    if (_processed) return;
    final raw = capture.barcodes.firstOrNull?.rawValue ?? '';
    if (raw.isEmpty) return;

    final result = _parseUpiQr(raw);
    if (result != null) {
      _processed = true;
      _ctrl?.stop();
      Navigator.of(context).pop(result);
    } else {
      setState(() => _error = 'Not a valid UPI QR code. Try again.');
      Future.delayed(
          const Duration(seconds: 2), () => setState(() => _error = null));
    }
  }

  Future<void> _toggleTorch() async {
    if (_ctrl == null) return;
    await _ctrl!.toggleTorch();
    setState(() => _torchOn = !_torchOn);
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      setState(() => _loading = true);

      final isTempCtrl = _ctrl == null;
      final scannerCtrl = _ctrl ?? MobileScannerController();
      final barcode = await scannerCtrl.analyzeImage(image.path);

      if (isTempCtrl) {
        scannerCtrl.dispose();
      }

      if (barcode != null && barcode.barcodes.isNotEmpty) {
        final raw = barcode.barcodes.first.rawValue ?? '';
        if (raw.isNotEmpty) {
          final result = _parseUpiQr(raw);
          if (result != null) {
            if (mounted) {
              Navigator.of(context).pop(result);
            }
            return;
          }
        }
      }

      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'No valid UPI QR code found in image.';
        });
        Future.delayed(
            const Duration(seconds: 3), () => setState(() => _error = null));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Failed to read image. Please try again.';
        });
        Future.delayed(
            const Duration(seconds: 3), () => setState(() => _error = null));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : _permissionDenied
              ? Stack(
                  children: [
                    _PermissionDeniedView(onPickFromGallery: _pickImageFromGallery),
                    // Back button on top of permission denied view
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: _TopBtn(
                          icon: Icons.arrow_back_rounded,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ),
                  ],
                )
              : Stack(
                  children: [
                    // Camera feed
                    MobileScanner(
                      controller: _ctrl!,
                      onDetect: _onDetect,
                    ),

                    // Scan overlay with cutout
                    _ScanOverlay(),

                    // Top bar
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            _TopBtn(
                              icon: Icons.arrow_back_rounded,
                              onTap: () => Navigator.of(context).pop(),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Scan UPI QR',
                              style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white),
                            ),
                            const Spacer(),
                            _TopBtn(
                              icon: Icons.photo_library_rounded,
                              onTap: _pickImageFromGallery,
                            ),
                            const SizedBox(width: 8),
                            _TopBtn(
                              icon: _torchOn
                                  ? Icons.flashlight_off_rounded
                                  : Icons.flashlight_on_rounded,
                              onTap: _toggleTorch,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Bottom hint + error
                    Align(
                      alignment: const Alignment(0, 0.7),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Point camera at a UPI QR code',
                            style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: FontWeight.w500),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                  color: Colors.red[700],
                                  borderRadius: BorderRadius.circular(20)),
                              child: Text(_error!,
                                  style: GoogleFonts.poppins(
                                      fontSize: 13, color: Colors.white)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

// ─── Permission Denied View ───────────────────────────────────────────────────
class _PermissionDeniedView extends StatelessWidget {
  final VoidCallback onPickFromGallery;
  const _PermissionDeniedView({required this.onPickFromGallery});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.camera_alt_outlined,
                color: Colors.white54, size: 64),
            const SizedBox(height: 20),
            Text('Camera Permission Required',
                style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white),
                textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(
                'Please allow camera access to scan UPI QR codes.',
                style:
                    GoogleFonts.poppins(fontSize: 14, color: Colors.white60),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            // Choose from Gallery Button
            GestureDetector(
              onTap: onPickFromGallery,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.photo_library_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text('Choose from Gallery',
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                          border: Border.all(color: Colors.white24),
                          borderRadius: BorderRadius.circular(12)),
                      child: Text('Go Back',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                              color: Colors.white, fontSize: 14)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => openAppSettings(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                          color: _accent,
                          borderRadius: BorderRadius.circular(12)),
                      child: Text('Open Settings',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
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

// ─── Top icon button ──────────────────────────────────────────────────────────
class _TopBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _TopBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
            color: Colors.black45, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

// ─── Scan overlay with cutout ─────────────────────────────────────────────────
class _ScanOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    const cutout = 260.0;
    final top = (size.height - cutout) / 2 - 40;

    return Stack(
      children: [
        ColorFiltered(
          colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.55), BlendMode.srcOut),
          child: Stack(
            children: [
              Container(
                  decoration: const BoxDecoration(
                      color: Colors.black,
                      backgroundBlendMode: BlendMode.dstOut)),
              Positioned(
                left: (size.width - cutout) / 2,
                top: top,
                child: Container(
                  width: cutout,
                  height: cutout,
                  decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: (size.width - cutout) / 2,
          top: top,
          child: _CornerBorders(size: cutout),
        ),
      ],
    );
  }
}

class _CornerBorders extends StatelessWidget {
  final double size;
  const _CornerBorders({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CornerPainter(
            radius: 16, length: 32, thickness: 3, color: _accent),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final double radius, length, thickness;
  final Color color;
  const _CornerPainter(
      {required this.radius,
      required this.length,
      required this.thickness,
      required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final w = size.width;
    final h = size.height;
    const pi = 3.14159265358979;

    // Top-left
    canvas.drawLine(Offset(radius, 0), Offset(length, 0), p);
    canvas.drawLine(Offset(0, radius), Offset(0, length), p);
    canvas.drawArc(
        Rect.fromLTWH(0, 0, radius * 2, radius * 2), pi, pi / 2, false, p);
    // Top-right
    canvas.drawLine(Offset(w - length, 0), Offset(w - radius, 0), p);
    canvas.drawLine(Offset(w, radius), Offset(w, length), p);
    canvas.drawArc(Rect.fromLTWH(w - radius * 2, 0, radius * 2, radius * 2),
        -pi / 2, pi / 2, false, p);
    // Bottom-left
    canvas.drawLine(Offset(0, h - length), Offset(0, h - radius), p);
    canvas.drawLine(Offset(radius, h), Offset(length, h), p);
    canvas.drawArc(
        Rect.fromLTWH(0, h - radius * 2, radius * 2, radius * 2),
        pi / 2,
        pi / 2,
        false,
        p);
    // Bottom-right
    canvas.drawLine(Offset(w, h - length), Offset(w, h - radius), p);
    canvas.drawLine(Offset(w - length, h), Offset(w - radius, h), p);
    canvas.drawArc(
        Rect.fromLTWH(
            w - radius * 2, h - radius * 2, radius * 2, radius * 2),
        0,
        pi / 2,
        false,
        p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
