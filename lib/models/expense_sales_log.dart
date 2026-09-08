import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ExpenseSalesLog {
  final DateTime date;
  final String category; // Medical, Feed, Grit, Electricity, Tray, Other_Expenses, Egg_Sales
  final String description;
  final double amount;
  final String unit; // kg, L, eggs, units, etc
  final double quantity;

  ExpenseSalesLog({
    required this.date,
    required this.category,
    required this.description,
    required this.amount,
    required this.unit,
    required this.quantity,
  });

  factory ExpenseSalesLog.fromExcelRow(List<dynamic> row) {
    // Helper to parse double safely
    double parseDouble(dynamic val) {
      if (val == null) return 0.0;
      if (val is double) return val;
      if (val is int) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 0.0;
      return 0.0;
    }

    // Date parsing can be tricky from Excel
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is DateTime) return val;
      if (val is String) {
        try {
          return DateFormat('yyyy-MM-dd').parse(val);
        } catch (_) {
          return DateTime.now();
        }
      }
      return DateTime.now();
    }

    return ExpenseSalesLog(
      date: parseDate(row[0]),
      category: row[1]?.toString() ?? '',
      description: row[2]?.toString() ?? '',
      amount: parseDouble(row[3]),
      unit: row[4]?.toString() ?? '',
      quantity: parseDouble(row[5]),
    );
  }


  factory ExpenseSalesLog.fromFirestore(Map<String, dynamic> data) {
    final raw = data['date'];
    final date = raw is Timestamp ? raw.toDate() : DateTime.parse(data['dateKey'] as String);
    double d(dynamic v) => (v as num?)?.toDouble() ?? 0;
    return ExpenseSalesLog(date: date, category: data['category']?.toString() ?? '', description: data['description']?.toString() ?? '', amount: d(data['amount']), unit: data['unit']?.toString() ?? '', quantity: d(data['quantity']));
  }

  Map<String, dynamic> toFirestore() => {
    'date': Timestamp.fromDate(date), 'dateKey': DateFormat('yyyy-MM-dd').format(date), 'category': category,
    'description': description, 'amount': amount, 'unit': unit, 'quantity': quantity, 'createdAt': FieldValue.serverTimestamp(),
  };

  List<dynamic> toExcelRow() {
    return [
      DateFormat('yyyy-MM-dd').format(date),
      category,
      description,
      amount,
      unit,
      quantity,
    ];
  }
}
