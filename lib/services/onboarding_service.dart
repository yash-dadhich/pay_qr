import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

/// Tracks which onboarding tours have been shown
class OnboardingService extends GetxService {
  static OnboardingService get instance => Get.find<OnboardingService>();

  final _box = GetStorage();

  static const _keyQuickQr = 'tour_quick_qr_done';
  static const _keyAddSheet = 'tour_add_sheet_done';
  static const _keyGroupSplit = 'tour_group_split_done';

  bool get shouldShowQuickQrTour => !(_box.read<bool>(_keyQuickQr) ?? false);
  bool get shouldShowAddSheetTour => !(_box.read<bool>(_keyAddSheet) ?? false);
  bool get shouldShowGroupSplitTour =>
      !(_box.read<bool>(_keyGroupSplit) ?? false);

  void markQuickQrDone() => _box.write(_keyQuickQr, true);
  void markAddSheetDone() => _box.write(_keyAddSheet, true);
  void markGroupSplitDone() => _box.write(_keyGroupSplit, true);

  /// Reset all tours (for testing)
  void resetAll() {
    _box.remove(_keyQuickQr);
    _box.remove(_keyAddSheet);
    _box.remove(_keyGroupSplit);
  }
}
