class Expense {
  final String id;
  final String title;
  final String description;
  final double amount;
  final String payer;
  final List<String> splitWith;
  final DateTime createdAt;

  Expense({
    required this.id,
    required this.title,
    required this.description,
    required this.amount,
    required this.payer,
    required this.splitWith,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'amount': amount,
        'payer': payer,
        'splitWith': splitWith,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] ?? '',
        amount: (json['amount'] as num).toDouble(),
        payer: json['payer'] as String,
        splitWith: List<String>.from(json['splitWith'] ?? []),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class Trip {
  final String id;
  final String name;
  final List<String> members;
  final List<Expense> expenses;
  final DateTime createdAt;

  Trip({
    required this.id,
    required this.name,
    required this.members,
    required this.expenses,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'members': members,
        'expenses': expenses.map((e) => e.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'] as String,
      name: json['name'] as String,
      members: List<String>.from(json['members'] ?? []),
      expenses: (json['expenses'] as List<dynamic>?)
              ?.map((e) => Expense.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
