import 'package:sqlite3/common.dart';

import 'app_sql_export.dart';

/// Reads the portable SQL export produced by Poultry Inventory itself.
class AppSqliteQueries {
  static List<Map<String, dynamic>> readTransactions(CommonDatabase db) {
    final records = <Map<String, dynamic>>[];
    for (final row in db.select('''
      SELECT transaction_id, date, main_category, category, original_category,
             account, description, amount, unit, quantity, transaction_type
      FROM ${AppSqlExport.tableName}
      ORDER BY date, transaction_id
    ''')) {
      records.add({
        'transactionId': row['transaction_id']?.toString() ?? '',
        'date': row['date']?.toString() ?? '',
        'mainCategory': row['main_category']?.toString() ?? '',
        'category': row['category']?.toString() ?? '',
        'originalCategory': row['original_category']?.toString() ?? '',
        'account': row['account']?.toString() ?? '',
        'description': row['description']?.toString() ?? '',
        'amount': row['amount'] is num ? (row['amount'] as num).toDouble() : 0.0,
        'unit': row['unit']?.toString() ?? 'rupees',
        'quantity': row['quantity'] is num ? (row['quantity'] as num).toDouble() : 0.0,
        'income': row['transaction_type']?.toString() == 'credit',
        'transactionType': row['transaction_type']?.toString() ?? 'expense',
        'source': 'poultry_inventory_export',
      });
    }
    return records;
  }
}
