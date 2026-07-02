import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../models/trip.dart';

class Settlement {
  final String from;
  final String to;
  final double amount;

  Settlement({required this.from, required this.to, required this.amount});
}

class MemberBalance {
  final String name;
  final double paid;
  final double share;
  final double netBalance;

  MemberBalance({
    required this.name,
    required this.paid,
    required this.share,
    required this.netBalance,
  });
}

class ExpenseController extends GetxController {
  final box = GetStorage();
  final trips = <Trip>[].obs;
  final activeTrip = Rxn<Trip>();
  final currentTab = 0.obs;

  @override
  void onInit() {
    super.onInit();
    loadTrips();
  }

  void loadTrips() {
    final stored = box.read<List<dynamic>>('trips');
    if (stored != null) {
      trips.assignAll(stored.map((e) => Trip.fromJson(Map<String, dynamic>.from(e))));
    }
    final activeId = box.read<String>('activeTripId');
    if (activeId != null) {
      activeTrip.value = trips.firstWhereOrNull((t) => t.id == activeId);
    }
  }

  void saveTrips() {
    box.write('trips', trips.map((t) => t.toJson()).toList());
    if (activeTrip.value != null) {
      box.write('activeTripId', activeTrip.value!.id);
    } else {
      box.remove('activeTripId');
    }
  }

  void createTrip(String name, List<String> members) {
    final cleanMembers = members.map((m) => m.trim()).where((m) => m.isNotEmpty).toList();
    if (cleanMembers.isEmpty) return;
    
    final newTrip = Trip(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.trim().isNotEmpty ? name.trim() : 'Trip ${trips.length + 1}',
      members: cleanMembers,
      expenses: [],
      createdAt: DateTime.now(),
    );
    trips.add(newTrip);
    activeTrip.value = newTrip;
    saveTrips();
  }

  void deleteTrip(String tripId) {
    trips.removeWhere((t) => t.id == tripId);
    if (activeTrip.value?.id == tripId) {
      activeTrip.value = trips.isNotEmpty ? trips.first : null;
    }
    saveTrips();
  }

  void selectTrip(Trip trip) {
    activeTrip.value = trip;
    saveTrips();
  }

  void addExpense({
    required String title,
    required String description,
    required double amount,
    required String payer,
    required List<String> splitWith,
  }) {
    if (activeTrip.value == null) return;
    final trip = activeTrip.value!;
    
    final newExpense = Expense(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title.trim().isNotEmpty ? title.trim() : 'Expense',
      description: description.trim(),
      amount: amount,
      payer: payer,
      splitWith: splitWith.isEmpty ? List<String>.from(trip.members) : splitWith,
      createdAt: DateTime.now(),
    );

    final updatedExpenses = List<Expense>.from(trip.expenses)..add(newExpense);
    final updatedTrip = Trip(
      id: trip.id,
      name: trip.name,
      members: trip.members,
      expenses: updatedExpenses,
      createdAt: trip.createdAt,
    );

    final idx = trips.indexWhere((t) => t.id == trip.id);
    if (idx != -1) {
      trips[idx] = updatedTrip;
      activeTrip.value = updatedTrip;
      saveTrips();
    }
  }

  void deleteExpense(String expenseId) {
    if (activeTrip.value == null) return;
    final trip = activeTrip.value!;
    
    final updatedExpenses = List<Expense>.from(trip.expenses)..removeWhere((e) => e.id == expenseId);
    final updatedTrip = Trip(
      id: trip.id,
      name: trip.name,
      members: trip.members,
      expenses: updatedExpenses,
      createdAt: trip.createdAt,
    );

    final idx = trips.indexWhere((t) => t.id == trip.id);
    if (idx != -1) {
      trips[idx] = updatedTrip;
      activeTrip.value = updatedTrip;
      saveTrips();
    }
  }

  // Splits & Balances Calculations
  List<MemberBalance> getMemberBalances(Trip trip) {
    final paidMap = <String, double>{};
    final shareMap = <String, double>{};
    
    for (final member in trip.members) {
      paidMap[member] = 0.0;
      shareMap[member] = 0.0;
    }

    for (final expense in trip.expenses) {
      paidMap[expense.payer] = (paidMap[expense.payer] ?? 0.0) + expense.amount;
      if (expense.splitWith.isNotEmpty) {
        final splitAmt = expense.amount / expense.splitWith.length;
        for (final member in expense.splitWith) {
          shareMap[member] = (shareMap[member] ?? 0.0) + splitAmt;
        }
      }
    }

    return trip.members.map((member) {
      final paid = paidMap[member] ?? 0.0;
      final share = shareMap[member] ?? 0.0;
      final netBalance = paid - share;
      return MemberBalance(
        name: member,
        paid: paid,
        share: share,
        netBalance: netBalance,
      );
    }).toList();
  }

  List<Settlement> getSettlements(Trip trip) {
    final balances = getMemberBalances(trip);
    
    // We separate into debtors (netBalance < 0) and creditors (netBalance > 0)
    final debtors = balances
        .where((b) => b.netBalance < -0.01)
        .map((b) => _TempBalance(b.name, b.netBalance))
        .toList();
    final creditors = balances
        .where((b) => b.netBalance > 0.01)
        .map((b) => _TempBalance(b.name, b.netBalance))
        .toList();

    // Sort descending by absolute values
    debtors.sort((a, b) => a.balance.compareTo(b.balance)); // most negative first
    creditors.sort((a, b) => b.balance.compareTo(a.balance)); // most positive first

    final settlements = <Settlement>[];
    
    int dIdx = 0;
    int cIdx = 0;

    while (dIdx < debtors.length && cIdx < creditors.length) {
      final debtor = debtors[dIdx];
      final creditor = creditors[cIdx];

      final debtAmount = -debtor.balance;
      final creditAmount = creditor.balance;

      if (debtAmount < 0.01) {
        dIdx++;
        continue;
      }
      if (creditAmount < 0.01) {
        cIdx++;
        continue;
      }

      final settleAmt = debtAmount < creditAmount ? debtAmount : creditAmount;
      settlements.add(Settlement(
        from: debtor.name,
        to: creditor.name,
        amount: settleAmt,
      ));

      debtor.balance += settleAmt;
      creditor.balance -= settleAmt;

      if (debtor.balance.abs() < 0.01) {
        dIdx++;
      }
      if (creditor.balance.abs() < 0.01) {
        cIdx++;
      }
    }

    return settlements;
  }
}

class _TempBalance {
  final String name;
  double balance;
  _TempBalance(this.name, this.balance);
}
