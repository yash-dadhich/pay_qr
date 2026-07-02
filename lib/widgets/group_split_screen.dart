import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../models/trip.dart';
import '../services/expense_controller.dart';
import '../services/onboarding_service.dart';
import '../main.dart';

class GroupSplitScreen extends StatefulWidget {
  const GroupSplitScreen({super.key});

  @override
  State<GroupSplitScreen> createState() => _GroupSplitScreenState();
}

class _GroupSplitScreenState extends State<GroupSplitScreen> {
  final _keyCreateBtn = GlobalKey();
  final _keyTripCard = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startTourIfNeeded());
  }

  void _startTourIfNeeded() {
    if (!OnboardingService.instance.shouldShowGroupSplitTour) return;
    // Only show when this tab is actually visible
    final expCtrl = Get.find<ExpenseController>();
    if (expCtrl.currentTab.value != 1) {
      // Wait for user to switch to this tab, then show
      ever(expCtrl.currentTab, (int tab) {
        if (tab == 1 && OnboardingService.instance.shouldShowGroupSplitTour) {
          // Small delay so the tab transition finishes
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) _showGroupSplitTour();
          });
        }
      });
      return;
    }
    _showGroupSplitTour();
  }

  void _showGroupSplitTour() {
    final accent = Theme.of(context).colorScheme.secondary;
    final primary = Theme.of(context).colorScheme.primary;
    final expCtrl = Get.find<ExpenseController>();

    final targets = [
      TargetFocus(
        identify: 'create_trip',
        keyTarget: _keyCreateBtn,
        shape: ShapeLightFocus.Circle,
        radius: 12,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (ctx, ctrl) => _GroupTourTooltip(
              title: 'Create a Trip',
              body: 'Going on a group trip? Tap here to create one — Goa, dinner, office party, anything.',
              accent: accent,
              onNext: ctrl.next,
              onSkip: ctrl.skip,
            ),
          ),
        ],
      ),
      if (expCtrl.trips.isNotEmpty)
        TargetFocus(
          identify: 'trip_card',
          keyTarget: _keyTripCard,
          shape: ShapeLightFocus.RRect,
          radius: 14,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (ctx, ctrl) => _GroupTourTooltip(
                title: 'Open a Trip',
                body: 'Tap a trip to add expenses, view balances, and settle dues.',
                accent: accent,
                onNext: ctrl.next,
                onSkip: ctrl.skip,
              ),
            ),
          ],
        ),
    ];

    TutorialCoachMark(
      targets: targets,
      colorShadow: primary,
      opacityShadow: 0.85,
      textSkip: 'SKIP',
      paddingFocus: 12,
      onFinish: () => OnboardingService.instance.markGroupSplitDone(),
      onSkip: () {
        OnboardingService.instance.markGroupSplitDone();
        return true;
      },
    ).show(context: context);
  }

  @override
  Widget build(BuildContext context) {
    final expCtrl = Get.find<ExpenseController>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    final accentColor = theme.colorScheme.secondary;
    final cardColor = theme.cardColor;
    final dividerColor = theme.dividerColor;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Group Splits',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: primaryColor),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            key: _keyCreateBtn,
            icon: Icon(Icons.add_circle_outline_rounded, color: accentColor, size: 28),
            onPressed: () => _showCreateTripSheet(context, expCtrl),
          ),
        ],
      ),
      body: Obx(() {
        if (expCtrl.trips.isEmpty) {
          return _buildEmptyState(context, expCtrl);
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: expCtrl.trips.length,
          itemBuilder: (context, index) {
            final trip = expCtrl.trips[index];
            final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
            final totalSpent = trip.expenses.fold<double>(0.0, (sum, item) => sum + item.amount);

            final card = Card(
              key: index == 0 ? _keyTripCard : null,
              elevation: 0,
              color: cardColor,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: dividerColor, width: 1),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  expCtrl.selectTrip(trip);
                  Get.to(() => const TripDetailScreen());
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              trip.name,
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: primaryColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.people_rounded, size: 16, color: accentColor),
                          const SizedBox(width: 6),
                          Text(
                            '${trip.members.length} members: ${trip.members.take(3).join(', ')}${trip.members.length > 3 ? '...' : ''}',
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Expenses',
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                          ),
                          Text(
                            fmt.format(totalSpent),
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: accentColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );

            return Dismissible(
              key: Key(trip.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  color: Colors.red[700],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.delete_rounded, color: Colors.white, size: 28),
              ),
              confirmDismiss: (direction) async {
                return await Get.dialog<bool>(
                  AlertDialog(
                    title: Text('Delete Trip', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    content: Text('Are you sure you want to delete "${trip.name}"? This will remove all associated expenses.', style: GoogleFonts.poppins()),
                    actions: [
                      TextButton(
                        onPressed: () => Get.back(result: false),
                        child: Text('Cancel', style: TextStyle(color: primaryColor)),
                      ),
                      TextButton(
                        onPressed: () => Get.back(result: true),
                        child: const Text('Delete', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
              onDismissed: (direction) {
                expCtrl.deleteTrip(trip.id);
                Get.snackbar(
                  'Deleted',
                  'Trip "${trip.name}" deleted successfully.',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: isDark ? const Color(0xFF1E1E30) : Colors.white,
                  colorText: primaryColor,
                );
              },
              child: card,
            );
          },
        );
      }),
    );
  }

  Widget _buildEmptyState(BuildContext context, ExpenseController expCtrl) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final accentColor = theme.colorScheme.secondary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.flight_takeoff_rounded,
                size: 72,
                color: accentColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Track Trip Expenses',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: primaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Going for a group trip? Log expenses, split shares instantly, and track who owes whom with optimized settle routes.',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _showCreateTripSheet(context, expCtrl),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text(
                'Create First Trip',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateTripSheet(BuildContext context, ExpenseController expCtrl) {
    final nameCtrl = TextEditingController();
    final memberCtrl = TextEditingController();
    final members = <String>[].obs;
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final accentColor = theme.colorScheme.secondary;
    final cardColor = theme.cardColor;
    final dividerColor = theme.dividerColor;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: dividerColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Create New Trip',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Trip Name',
                    hintText: 'e.g., Goa Trip 2026',
                    labelStyle: TextStyle(color: primaryColor),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: accentColor, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: dividerColor),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  cursorColor: accentColor,
                ),
                const SizedBox(height: 20),
                Text(
                  'Add Members',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: memberCtrl,
                        decoration: InputDecoration(
                          hintText: 'Enter member name',
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: accentColor, width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: dividerColor),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        cursorColor: accentColor,
                        onSubmitted: (val) {
                          if (val.trim().isNotEmpty) {
                            members.add(val.trim());
                            memberCtrl.clear();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        if (memberCtrl.text.trim().isNotEmpty) {
                          members.add(memberCtrl.text.trim());
                          memberCtrl.clear();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: accentColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.add_rounded, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Obx(() => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: members.map((name) {
                    return Chip(
                      label: Text(name, style: GoogleFonts.poppins(fontSize: 12)),
                      deleteIcon: const Icon(Icons.close, size: 14),
                      onDeleted: () => members.remove(name),
                      backgroundColor: accentColor.withValues(alpha: 0.1),
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    );
                  }).toList(),
                )),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      if (nameCtrl.text.trim().isEmpty) {
                        Get.snackbar('Error', 'Please enter a trip name',
                            backgroundColor: Colors.red[100], colorText: Colors.red[900]);
                        return;
                      }
                      if (members.isEmpty) {
                        Get.snackbar('Error', 'Please add at least one member',
                            backgroundColor: Colors.red[100], colorText: Colors.red[900]);
                        return;
                      }
                      expCtrl.createTrip(nameCtrl.text, members);
                      Get.back();
                      Get.to(() => const TripDetailScreen());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: theme.scaffoldBackgroundColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Create Trip',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class TripDetailScreen extends StatelessWidget {
  const TripDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final expCtrl = Get.find<ExpenseController>();
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final accentColor = theme.colorScheme.secondary;

    return Obx(() {
      final trip = expCtrl.activeTrip.value;
      if (trip == null) {
        return Scaffold(
          body: Center(
            child: Text('No active trip', style: GoogleFonts.poppins()),
          ),
        );
      }

      final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
      final totalSpent = trip.expenses.fold<double>(0.0, (sum, item) => sum + item.amount);

      return DefaultTabController(
        length: 3,
        child: Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: primaryColor),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              trip.name,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: primaryColor, fontSize: 18),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryColor, primaryColor.withValues(alpha: 0.85)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TOTAL EXPENDITURE',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: accentColor,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        fmt.format(totalSpent),
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.people_rounded, size: 16, color: accentColor),
                          const SizedBox(width: 6),
                          Text(
                            '${trip.members.length} members  •  ${trip.expenses.length} expenses',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              TabBar(
                labelColor: accentColor,
                unselectedLabelColor: Colors.grey,
                indicatorColor: accentColor,
                labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                tabs: const [
                  Tab(text: 'Expenses'),
                  Tab(text: 'Balances'),
                  Tab(text: 'Settle Dues'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildExpensesTab(context, expCtrl, trip, fmt),
                    _buildBalancesTab(context, expCtrl, trip, fmt),
                    _buildSettlementsTab(context, expCtrl, trip, fmt),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildExpensesTab(
    BuildContext context,
    ExpenseController expCtrl,
    Trip trip,
    NumberFormat fmt,
  ) {
    final theme = Theme.of(context);
    final cardColor = theme.cardColor;
    final dividerColor = theme.dividerColor;
    final primaryColor = theme.colorScheme.primary;
    final accentColor = theme.colorScheme.secondary;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: trip.expenses.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.receipt_long_rounded, size: 64, color: accentColor.withValues(alpha: 0.5)),
                    const SizedBox(height: 16),
                    Text(
                      'No Expenses Yet',
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: primaryColor),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Log trip expenses like meals, hotels, or cabs here.',
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: trip.expenses.length,
              itemBuilder: (context, index) {
                final expense = trip.expenses[index];
                return Dismissible(
                  key: Key(expense.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: Colors.red[700],
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.delete_rounded, color: Colors.white, size: 24),
                  ),
                  confirmDismiss: (direction) async {
                    return await Get.dialog<bool>(
                      AlertDialog(
                        title: Text('Delete Expense', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                        content: Text('Are you sure you want to delete "${expense.title}"?', style: GoogleFonts.poppins()),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: Text('Cancel', style: TextStyle(color: primaryColor)),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Delete', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                  },
                  onDismissed: (direction) {
                    expCtrl.deleteExpense(expense.id);
                  },
                  child: Card(
                    elevation: 0,
                    color: cardColor,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: dividerColor, width: 1),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.shopping_bag_outlined, color: accentColor, size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  expense.title,
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: primaryColor, fontSize: 14),
                                ),
                                if (expense.description.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    expense.description,
                                    style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Text(
                                  'Paid by ${expense.payer} • Split with ${expense.splitWith.length} ppl',
                                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            fmt.format(expense.amount),
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: primaryColor, fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddExpenseSheet(context, expCtrl, trip),
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }

  Widget _buildBalancesTab(
    BuildContext context,
    ExpenseController expCtrl,
    Trip trip,
    NumberFormat fmt,
  ) {
    final theme = Theme.of(context);
    final cardColor = theme.cardColor;
    final dividerColor = theme.dividerColor;
    final primaryColor = theme.colorScheme.primary;
    final balances = expCtrl.getMemberBalances(trip);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: balances.length,
      itemBuilder: (context, index) {
        final bal = balances[index];
        final isOwed = bal.netBalance >= 0;
        final balanceColor = isOwed ? Colors.green[600] : Colors.red[600];
        final balancePrefix = isOwed ? '+' : '';

        return Card(
          elevation: 0,
          color: cardColor,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: dividerColor, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bal.name,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: primaryColor, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Paid: ${fmt.format(bal.paid)}  •  Share: ${fmt.format(bal.share)}',
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                Text(
                  '$balancePrefix${fmt.format(bal.netBalance)}',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    color: balanceColor,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSettlementsTab(
    BuildContext context,
    ExpenseController expCtrl,
    Trip trip,
    NumberFormat fmt,
  ) {
    final theme = Theme.of(context);
    final cardColor = theme.cardColor;
    final dividerColor = theme.dividerColor;
    final primaryColor = theme.colorScheme.primary;
    final accentColor = theme.colorScheme.secondary;
    final settlements = expCtrl.getSettlements(trip);

    if (settlements.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_outline_rounded, size: 64, color: Colors.green[500]),
              const SizedBox(height: 16),
              Text(
                'Everything Settled Up!',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: primaryColor),
              ),
              const SizedBox(height: 8),
              Text(
                'No pending balances or payouts to settle.',
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: settlements.length,
      itemBuilder: (context, index) {
        final set = settlements[index];
        return Card(
          elevation: 0,
          color: cardColor,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: dividerColor, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.poppins(color: primaryColor, fontSize: 13),
                      children: [
                        TextSpan(text: set.from, style: const TextStyle(fontWeight: FontWeight.bold)),
                        const TextSpan(text: ' owes '),
                        TextSpan(text: set.to, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      fmt.format(set.amount),
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: primaryColor, fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    ElevatedButton(
                      onPressed: () => _handleSettlePayment(context, expCtrl, set.to, set.amount),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Pay QR',
                        style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleSettlePayment(
    BuildContext context,
    ExpenseController expCtrl,
    String receiverName,
    double amount,
  ) {
    final upiCtrl = Get.find<UpiController>();
    
    // Check if receiverName matches one of our stored UPI IDs
    final match = upiCtrl.upiIds.firstWhereOrNull(
      (u) => u['name']?.trim().toLowerCase() == receiverName.trim().toLowerCase()
    );

    if (match != null) {
      // Pre-fill and switch tab to Quick QR
      upiCtrl.selectedUpi.value = match;
      upiCtrl.amountController.text = amount.toStringAsFixed(2);
      upiCtrl.splitController.text = '1';
      expCtrl.currentTab.value = 0; // Switch to Quick QR tab
      Navigator.of(context).pop(); // Pop TripDetailScreen
      Get.snackbar(
        'UPI QR Generated',
        'Pre-filled $receiverName\'s UPI ID with amount ₹$amount',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green[700],
        colorText: Colors.white,
      );
    } else {
      // Prompt user to enter receiver's UPI ID to complete payment
      final upiInputCtrl = TextEditingController();
      final theme = Theme.of(context);
      final primaryColor = theme.colorScheme.primary;
      final accentColor = theme.colorScheme.secondary;

      Get.dialog(
        AlertDialog(
          title: Text(
            'UPI QR Setup',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter UPI ID for $receiverName to generate QR:',
                style: GoogleFonts.poppins(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: upiInputCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'UPI ID',
                  hintText: 'e.g., name@okaxis',
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: accentColor, width: 2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: theme.dividerColor),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                cursorColor: accentColor,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(), // Pop Setup dialog
              child: Text('Cancel', style: TextStyle(color: primaryColor)),
            ),
            TextButton(
              onPressed: () {
                final idStr = upiInputCtrl.text.trim();
                if (idStr.isEmpty || !idStr.contains('@')) {
                  Get.snackbar('Error', 'Please enter a valid UPI ID',
                      backgroundColor: Colors.red[100], colorText: Colors.red[900]);
                  return;
                }
                
                // Add to stored UPI IDs
                upiCtrl.addNewUpi(idStr, receiverName);
                
                // Fetch the new match
                final newMatch = upiCtrl.upiIds.firstWhere((u) => u['upiId'] == idStr);
                upiCtrl.selectedUpi.value = newMatch;
                upiCtrl.amountController.text = amount.toStringAsFixed(2);
                upiCtrl.splitController.text = '1';
                expCtrl.currentTab.value = 0; // Switch to Quick QR tab
                
                Navigator.of(context).pop(); // Pop Setup dialog
                Navigator.of(context).pop(); // Pop TripDetailScreen
                Get.snackbar(
                  'UPI QR Generated',
                  'Saved UPI ID and pre-filled ₹$amount',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.green[700],
                  colorText: Colors.white,
                );
              },
              child: Text('Generate QR', style: TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }
  }

  void _showAddExpenseSheet(BuildContext context, ExpenseController expCtrl, Trip trip) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final selectedPayer = trip.members.first.obs;
    final splitWith = <String>[].obs..addAll(trip.members);

    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final accentColor = theme.colorScheme.secondary;
    final cardColor = theme.cardColor;
    final dividerColor = theme.dividerColor;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: dividerColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Add Expense',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    labelText: 'Expense Name',
                    hintText: 'e.g., Dinner at beach',
                    labelStyle: TextStyle(color: primaryColor),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: accentColor, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: dividerColor),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  cursorColor: accentColor,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Amount',
                          hintText: '0.00',
                          prefixText: '₹ ',
                          labelStyle: TextStyle(color: primaryColor),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: accentColor, width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: dividerColor),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        cursorColor: accentColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: Obx(() => DropdownButtonFormField<String>(
                            value: selectedPayer.value,
                            decoration: InputDecoration(
                              labelText: 'Paid By',
                              labelStyle: TextStyle(color: primaryColor),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: accentColor, width: 2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: dividerColor),
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            items: trip.members.map((name) {
                              return DropdownMenuItem(
                                value: name,
                                child: Text(name, style: GoogleFonts.poppins(fontSize: 14)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) selectedPayer.value = val;
                            },
                          )),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: descCtrl,
                  decoration: InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'e.g., drinks and seafood',
                    labelStyle: TextStyle(color: primaryColor),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: accentColor, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: dividerColor),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  cursorColor: accentColor,
                ),
                const SizedBox(height: 20),
                Text(
                  'Split With',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Obx(() => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: trip.members.map((name) {
                    final isChecked = splitWith.contains(name);
                    return FilterChip(
                      label: Text(name, style: GoogleFonts.poppins(fontSize: 12)),
                      selected: isChecked,
                      selectedColor: accentColor.withValues(alpha: 0.2),
                      checkmarkColor: accentColor,
                      onSelected: (checked) {
                        if (checked) {
                          splitWith.add(name);
                        } else {
                          if (splitWith.length > 1) {
                            splitWith.remove(name);
                          } else {
                            Get.snackbar('Error', 'Split must include at least 1 person',
                                backgroundColor: Colors.orange[100], colorText: Colors.orange[900]);
                          }
                        }
                      },
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    );
                  }).toList(),
                )),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      final title = titleCtrl.text.trim();
                      final amtVal = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                      
                      if (title.isEmpty) {
                        Get.snackbar('Error', 'Please enter a name for the expense',
                            backgroundColor: Colors.red[100], colorText: Colors.red[900]);
                        return;
                      }
                      if (amtVal <= 0) {
                        Get.snackbar('Error', 'Please enter a valid amount',
                            backgroundColor: Colors.red[100], colorText: Colors.red[900]);
                        return;
                      }

                      expCtrl.addExpense(
                        title: title,
                        description: descCtrl.text,
                        amount: amtVal,
                        payer: selectedPayer.value,
                        splitWith: splitWith.toList(),
                      );
                      
                      Get.back(); // close bottom sheet
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: theme.scaffoldBackgroundColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Add Expense',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Group Split Tour Tooltip ─────────────────────────────────────────────────
class _GroupTourTooltip extends StatelessWidget {
  final String title;
  final String body;
  final Color accent;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _GroupTourTooltip({
    required this.title,
    required this.body,
    required this.accent,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 20,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1A2E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text(
              body,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xFF888888),
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: onSkip,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  child: Text(
                    'Skip',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: const Color(0xFF888888),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onNext,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Next →',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
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
