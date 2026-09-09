import 'package:sqlite3/common.dart';

import 'app_sql_export.dart';

/// Reads the portable SQL export produced by Poultry Inventory itself.
class AppSqliteQueries {
  static List<Map<String, dynamic>> readTransactions(CommonDatabase db) {
    final records = <Map<String, dynamic>>[];
    dynamic rows;
    try {
      rows = db.select('''
        SELECT transaction_id, date, main_category, category, original_category,
               account, description, amount, unit_price, freight_charge, pricing_calculated, unit, quantity, transaction_type
        FROM ${AppSqlExport.tableName}
        ORDER BY date, transaction_id
      ''');
    } catch (_) {
      // Backward compatibility with V1 app-generated SQL exports.
      rows = db.select('''
        SELECT transaction_id, date, main_category, category, original_category,
               account, description, amount, unit, quantity, transaction_type
        FROM ${AppSqlExport.tableName}
        ORDER BY date, transaction_id
      ''');
    }
    for (final row in rows) {
      final quantity = row['quantity'] is num ? (row['quantity'] as num).toDouble() : 0.0;
      final amount = row['amount'] is num ? (row['amount'] as num).toDouble() : 0.0;
      final unitPrice = row['unit_price'] is num ? (row['unit_price'] as num).toDouble() : (quantity > 0 ? amount / quantity : 0.0);
      records.add({
        'transactionId': row['transaction_id']?.toString() ?? '',
        'date': row['date']?.toString() ?? '',
        'mainCategory': row['main_category']?.toString() ?? '',
        'category': row['category']?.toString() ?? '',
        'originalCategory': row['original_category']?.toString() ?? '',
        'account': row['account']?.toString() ?? '',
        'description': row['description']?.toString() ?? '',
        'amount': amount,
        'unitPrice': unitPrice,
        'freightCharge': row['freight_charge'] is num ? (row['freight_charge'] as num).toDouble() : 0.0,
        'pricingCalculated': row['pricing_calculated'] is num ? (row['pricing_calculated'] as num) != 0 : false,
        'unit': row['unit']?.toString() ?? 'rupees',
        'quantity': quantity,
        'income': row['transaction_type']?.toString() == 'credit',
        'transactionType': row['transaction_type']?.toString() ?? 'expense',
        'source': 'poultry_inventory_export',
      });
    }
    return records;
  }
}
