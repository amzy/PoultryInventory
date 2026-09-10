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
  /// Optional supplier selected for this transaction.
  final String? supplierId;
  /// Supplier name snapshot retained for historical reporting.
  final String? supplierName;
  final double amount;
  /// Unit price before freight for material purchases.
  final double unitPrice;
  /// Freight/transport charge added to the material purchase total.
  final double freightCharge;
  /// True when the amount is calculated from quantity, unit price and freight.
  final bool pricingCalculated;
  /// Line items used by Medical expenses. Each item contains name, price and quantity.
  final List<Map<String, dynamic>> medicalItems;
  /// Feed line items. Each item contains name, quantity (50 kg bags), pricePerBag and total.
  final List<Map<String, dynamic>> feedItems;
  final String? createdByUid;
  final String? createdByName;
  final DateTime? createdAt;
  final String? updatedByUid;
  final String? updatedByName;
  final DateTime? updatedAt;

  /// Net amount payable/received, including freight.
  double get netTotal => transactionType == 'credit' ? amount : amount + freightCharge;
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
    this.supplierId,
    this.supplierName,
    required this.amount,
    this.unitPrice = 0,
    this.freightCharge = 0,
    this.pricingCalculated = false,
    this.medicalItems = const [],
    this.feedItems = const [],
    this.createdByUid,
    this.createdByName,
    this.createdAt,
    this.updatedByUid,
    this.updatedByName,
    this.updatedAt,
    required this.unit,
    required this.quantity,
    String? transactionType,
  }) : transactionType = transactionType ?? 'expense',
       originalCategory = originalCategory ?? category;

  factory ExpenseSalesLog.fromFirestore(Map<String, dynamic> data, {String? id}) {
    final raw = data['date'];
    final date = raw is Timestamp ? raw.toDate() : DateTime.parse(data['dateKey'] as String);
    double d(dynamic v) => (v as num?)?.toDouble() ?? 0;
    DateTime? dt(dynamic v) => v is Timestamp ? v.toDate() : (v is DateTime ? v : null);
    final category = data['category']?.toString().trim() ?? '';
    final rawTransactionType = data['transactionType']?.toString().trim();
    final transactionType = (rawTransactionType?.isNotEmpty ?? false)
        ? rawTransactionType!
        : 'expense';
    final rawOriginalCategory = data['originalCategory']?.toString().trim();
    final originalCategory = (rawOriginalCategory?.isNotEmpty ?? false)
        ? rawOriginalCategory!
        : category;
    return ExpenseSalesLog(
      id: id,
      date: date,
      mainCategory: data['mainCategory']?.toString().trim().isNotEmpty == true
          ? data['mainCategory'].toString()
          : 'Layer Bird',
      category: category,
      originalCategory: originalCategory,
      account: data['account']?.toString().trim().isNotEmpty == true
          ? data['account'].toString()
          : 'Amzad Khan',
      description: data['description']?.toString() ?? '',
      supplierId: data['supplierId']?.toString(),
      supplierName: data['supplierName']?.toString(),
      amount: d(data['amount']),
      unitPrice: d(data['unitPrice']),
      freightCharge: d(data['freightCharge']),
      pricingCalculated: data['pricingCalculated'] == true,
      medicalItems: ((data['medicalItems'] as List?) ?? const []).map((item) => Map<String, dynamic>.from(item as Map)).toList(),
      feedItems: ((data['feedItems'] as List?) ?? const []).map((item) => Map<String, dynamic>.from(item as Map)).toList(),
      createdByUid: data['createdByUid']?.toString(),
      createdByName: data['createdByName']?.toString(),
      createdAt: dt(data['createdAt']),
      updatedByUid: data['updatedByUid']?.toString(),
      updatedByName: data['updatedByName']?.toString(),
      updatedAt: dt(data['updatedAt']),
      unit: data['unit']?.toString() ?? '',
      quantity: d(data['quantity']),
      transactionType: transactionType,
    );
  }

  Map<String, dynamic> toFirestore({bool includeCreatedAt = true}) {
    final data = <String, dynamic>{
      'date': Timestamp.fromDate(date),
      'dateKey': DateFormat('yyyy-MM-dd').format(date),
      'mainCategory': mainCategory.trim().isEmpty ? 'Layer Bird' : mainCategory.trim(),
      'category': category.trim(),
      'originalCategory': originalCategory.trim().isEmpty ? category.trim() : originalCategory.trim(),
      'account': account.trim().isEmpty ? 'Amzad Khan' : account.trim(),
      'description': description,
      if (supplierId != null && supplierId!.trim().isNotEmpty) 'supplierId': supplierId,
      if (supplierName != null && supplierName!.trim().isNotEmpty) 'supplierName': supplierName,
      'amount': amount,
      'unitPrice': unitPrice,
      'freightCharge': transactionType == 'credit' ? 0 : freightCharge,
      'pricingCalculated': pricingCalculated,
      'unit': unit,
      'quantity': quantity,
      'transactionType': transactionType,
    };
    if (medicalItems.isNotEmpty) data['medicalItems'] = medicalItems;
    if (feedItems.isNotEmpty) data['feedItems'] = feedItems;
    if (createdByUid != null) data['createdByUid'] = createdByUid;
    if (createdByName != null) data['createdByName'] = createdByName;
    if (createdAt != null) data['createdAt'] = Timestamp.fromDate(createdAt!);
    if (updatedByUid != null) data['updatedByUid'] = updatedByUid;
    if (updatedByName != null) data['updatedByName'] = updatedByName;
    if (updatedAt != null) data['updatedAt'] = Timestamp.fromDate(updatedAt!);
    if (includeCreatedAt) data['createdAt'] = FieldValue.serverTimestamp();
    return data;
  }


  ExpenseSalesLog copyWith({
    String? id,
    DateTime? date,
    String? mainCategory,
    String? category,
    String? originalCategory,
    String? account,
    String? description,
    String? supplierId,
    String? supplierName,
    double? amount,
    double? unitPrice,
    double? freightCharge,
    bool? pricingCalculated,
    List<Map<String, dynamic>>? medicalItems,
    List<Map<String, dynamic>>? feedItems,
    String? createdByUid,
    String? createdByName,
    DateTime? createdAt,
    String? updatedByUid,
    String? updatedByName,
    DateTime? updatedAt,
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
    supplierId: supplierId ?? this.supplierId,
    supplierName: supplierName ?? this.supplierName,
    amount: amount ?? this.amount,
    unitPrice: unitPrice ?? this.unitPrice,
    freightCharge: freightCharge ?? this.freightCharge,
    pricingCalculated: pricingCalculated ?? this.pricingCalculated,
    medicalItems: medicalItems ?? this.medicalItems,
    feedItems: feedItems ?? this.feedItems,
    createdByUid: createdByUid ?? this.createdByUid,
    createdByName: createdByName ?? this.createdByName,
    createdAt: createdAt ?? this.createdAt,
    updatedByUid: updatedByUid ?? this.updatedByUid,
    updatedByName: updatedByName ?? this.updatedByName,
    updatedAt: updatedAt ?? this.updatedAt,
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
    supplierName,
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
