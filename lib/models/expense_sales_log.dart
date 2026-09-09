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
  /// Unit price before freight for material purchases.
  final double unitPrice;
  /// Freight/transport charge added to the material purchase total.
  final double freightCharge;
  /// True when the amount is calculated from quantity, unit price and freight.
  final bool pricingCalculated;
  /// Line items used by Medical expenses. Each item contains name, price and quantity.
  final List<Map<String, dynamic>> medicalItems;

  /// Net amount payable/received, including freight.
  double get netTotal => amount + freightCharge;
  final String unit;
  final double quantity;
  /// 'expense' or 'credit'. Credits are income/received transactions.
  final String transactionType;

  ExpenseSalesLog({
    this.id,
    required this.date,
    this.mainCategory = 'Layer Bird',
    required this.category,
    String? originalCategory,
    this.account = 'Amzad Khan',
    required this.description,
    required this.amount,
    this.unitPrice = 0,
    this.freightCharge = 0,
    this.pricingCalculated = false,
    this.medicalItems = const [],
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
          : 'Layer Bird',
      category: category,
      originalCategory: data['originalCategory']?.toString().trim().isNotEmpty == true
          ? data['originalCategory'].toString()
          : category,
      account: data['account']?.toString().trim().isNotEmpty == true
          ? data['account'].toString()
          : 'Amzad Khan',
      description: data['description']?.toString() ?? '',
      amount: d(data['amount']),
      unitPrice: d(data['unitPrice']),
      freightCharge: d(data['freightCharge']),
      pricingCalculated: data['pricingCalculated'] == true,
      medicalItems: ((data['medicalItems'] as List?) ?? const []).map((item) => Map<String, dynamic>.from(item as Map)).toList(),
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
    'mainCategory': mainCategory.trim().isEmpty ? 'Layer Bird' : mainCategory.trim(),
    'category': category.trim(),
    'originalCategory': originalCategory.trim().isEmpty ? category.trim() : originalCategory.trim(),
    'account': account.trim().isEmpty ? 'Amzad Khan' : account.trim(),
    'description': description,
    'amount': amount,
    'unitPrice': unitPrice,
    'freightCharge': freightCharge,
    'pricingCalculated': pricingCalculated,
    if (medicalItems.isNotEmpty) 'medicalItems': medicalItems,
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
    double? unitPrice,
    double? freightCharge,
    bool? pricingCalculated,
    List<Map<String, dynamic>>? medicalItems,
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
    unitPrice: unitPrice ?? this.unitPrice,
    freightCharge: freightCharge ?? this.freightCharge,
    pricingCalculated: pricingCalculated ?? this.pricingCalculated,
    medicalItems: medicalItems ?? this.medicalItems,
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
    unitPrice,
    freightCharge,
    pricingCalculated,
    medicalItems,
    unit,
    quantity,
    transactionType,
  ];
}
