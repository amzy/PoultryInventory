import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ExpenseSalesLog {
  final String? id;
  final DateTime date;
  /// Broad phase/group, similar to a Cashew main category.
  final String mainCategory;
  /// Current editable subcategory within the main category.
  final String category;
  /// Original Cashew category, retained so imported history is never lost.
  final String originalCategory;
  /// Person/account that paid or received this transaction.
  final String account;
  final String description;
  final double amount;
  final String unit;
  final double quantity;
  /// 'expense' or 'credit'. Credits are income/received transactions.
  final String transactionType;

  ExpenseSalesLog({
    this.id,
    required this.date,
    this.mainCategory = 'Poultry',
    required this.category,
    String? originalCategory,
    this.account = 'Amzad Khan',
    required this.description,
    required this.amount,
    required this.unit,
    required this.quantity,
    String? transactionType,
  }) : transactionType = transactionType ?? (category == 'Egg_Sales' ? 'credit' : 'expense'),
       originalCategory = originalCategory ?? category;

  factory ExpenseSalesLog.fromFirestore(Map<String, dynamic> data, {String? id}) {
    final raw = data['date'];
    final date = raw is Timestamp ? raw.toDate() : DateTime.parse(data['dateKey'] as String);
    double d(dynamic v) => (v as num?)?.toDouble() ?? 0;
    final category = data['category']?.toString() ?? '';
    return ExpenseSalesLog(
      id: id,
      date: date,
      mainCategory: data['mainCategory']?.toString().trim().isNotEmpty == true
          ? data['mainCategory'].toString()
          : 'Poultry',
      category: category,
      originalCategory: data['originalCategory']?.toString().trim().isNotEmpty == true
          ? data['originalCategory'].toString()
          : category,
      account: data['account']?.toString().trim().isNotEmpty == true
          ? data['account'].toString()
          : 'Amzad Khan',
      description: data['description']?.toString() ?? '',
      amount: d(data['amount']),
      unit: data['unit']?.toString() ?? '',
      quantity: d(data['quantity']),
      transactionType: data['transactionType']?.toString().trim().isNotEmpty == true
          ? data['transactionType'].toString()
          : (category == 'Egg_Sales' ? 'credit' : 'expense'),
    );
  }

  Map<String, dynamic> toFirestore({bool includeCreatedAt = true}) => {
    'date': Timestamp.fromDate(date),
    'dateKey': DateFormat('yyyy-MM-dd').format(date),
    'mainCategory': mainCategory.trim().isEmpty ? 'Poultry' : mainCategory.trim(),
    'category': category.trim(),
    'originalCategory': originalCategory.trim().isEmpty ? category.trim() : originalCategory.trim(),
    'account': account.trim().isEmpty ? 'Amzad Khan' : account.trim(),
    'description': description,
    'amount': amount,
    'unit': unit,
    'quantity': quantity,
    'transactionType': transactionType,
    if (includeCreatedAt) 'createdAt': FieldValue.serverTimestamp(),
  };

  ExpenseSalesLog copyWith({
    String? id,
    DateTime? date,
    String? mainCategory,
    String? category,
    String? originalCategory,
    String? account,
    String? description,
    double? amount,
    String? unit,
    double? quantity,
    String? transactionType,
  }) => ExpenseSalesLog(
    id: id ?? this.id,
    date: date ?? this.date,
    mainCategory: mainCategory ?? this.mainCategory,
    category: category ?? this.category,
    originalCategory: originalCategory ?? this.originalCategory,
    account: account ?? this.account,
    description: description ?? this.description,
    amount: amount ?? this.amount,
    unit: unit ?? this.unit,
    quantity: quantity ?? this.quantity,
    transactionType: transactionType ?? this.transactionType,
  );

  List<dynamic> toExcelRow() => [
    DateFormat('yyyy-MM-dd').format(date),
    mainCategory,
    category,
    originalCategory,
    account,
    description,
    amount,
    unit,
    quantity,
    transactionType,
  ];
}
