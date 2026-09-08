import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ExpenseSalesLog {
  final String? id;
  final DateTime date;
  /// Broad grouping, similar to Cashew's main category.
  final String mainCategory;
  /// Detail/category. Imported Cashew records keep their original category here.
  final String category;
  final String description;
  final double amount;
  final String unit;
  final double quantity;

  ExpenseSalesLog({
    this.id,
    required this.date,
    this.mainCategory = 'Poultry',
    required this.category,
    required this.description,
    required this.amount,
    required this.unit,
    required this.quantity,
  });

  factory ExpenseSalesLog.fromFirestore(Map<String, dynamic> data, {String? id}) {
    final raw = data['date'];
    final date = raw is Timestamp ? raw.toDate() : DateTime.parse(data['dateKey'] as String);
    double d(dynamic v) => (v as num?)?.toDouble() ?? 0;
    return ExpenseSalesLog(
      id: id,
      date: date,
      mainCategory: data['mainCategory']?.toString().trim().isNotEmpty == true
          ? data['mainCategory'].toString()
          : 'Poultry',
      category: data['category']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      amount: d(data['amount']),
      unit: data['unit']?.toString() ?? '',
      quantity: d(data['quantity']),
    );
  }

  Map<String, dynamic> toFirestore({bool includeCreatedAt = true}) => {
    'date': Timestamp.fromDate(date),
    'dateKey': DateFormat('yyyy-MM-dd').format(date),
    'mainCategory': mainCategory.trim().isEmpty ? 'Poultry' : mainCategory.trim(),
    'category': category,
    'description': description,
    'amount': amount,
    'unit': unit,
    'quantity': quantity,
    if (includeCreatedAt) 'createdAt': FieldValue.serverTimestamp(),
  };

  ExpenseSalesLog copyWith({
    String? id,
    DateTime? date,
    String? mainCategory,
    String? category,
    String? description,
    double? amount,
    String? unit,
    double? quantity,
  }) => ExpenseSalesLog(
    id: id ?? this.id,
    date: date ?? this.date,
    mainCategory: mainCategory ?? this.mainCategory,
    category: category ?? this.category,
    description: description ?? this.description,
    amount: amount ?? this.amount,
    unit: unit ?? this.unit,
    quantity: quantity ?? this.quantity,
  );

  List<dynamic> toExcelRow() => [
    DateFormat('yyyy-MM-dd').format(date),
    mainCategory,
    category,
    description,
    amount,
    unit,
    quantity,
  ];
}
