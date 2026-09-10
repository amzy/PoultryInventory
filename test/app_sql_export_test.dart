import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:poultry_inventory/models/expense_sales_log.dart';
import 'package:poultry_inventory/services/app_sql_export.dart';
import 'package:poultry_inventory/services/app_sqlite_queries.dart';

void main() {
  test('app financial SQL export can be imported back', () {
    final source = [
      ExpenseSalesLog(
        id: '2026-09-09_123',
        date: DateTime(2026, 9, 9),
        mainCategory: 'Layer Bird',
        category: 'Feed',
        originalCategory: 'Layer Feed',
        account: 'Amzad Khan',
        description: "Farmer's feed",
        amount: 12500.50,
        unit: 'rupees',
        quantity: 0,
        transactionType: 'expense',
        feedItems: const [
          {'name': 'LCC (Starter)', 'quantity': 4.0, 'pricePerBag': 2500.0, 'bagWeightKg': 50, 'total': 10000.0},
        ],
      ),
      ExpenseSalesLog(
        id: 'cashew_42',
        date: DateTime(2026, 9, 8),
        mainCategory: 'Layer Bird',
        category: 'Egg',
        originalCategory: 'Egg',
        account: 'Sarfaraj Khan',
        description: 'Egg sale',
        amount: 3000,
        unit: 'rupees',
        quantity: 0,
        transactionType: 'credit',
      ),
    ];

    final sql = AppSqlExport.buildExpenseSql(source);
    expect(AppSqlExport.isAppSql(sql), isTrue);

    final db = sqlite3.openInMemory();
    try {
      db.execute(sql);
      final imported = AppSqliteQueries.readTransactions(db);
      expect(imported, hasLength(2));
      expect(imported[0]['account'], 'Sarfaraj Khan');
      expect(imported[0]['transactionType'], 'credit');
      expect(imported[1]['description'], "Farmer's feed");
      expect(imported[1]['amount'], 12500.50);
      expect(imported[1]['source'], 'poultry_inventory_export');
      expect(imported[1]['feedItems'], isA<List<Map<String, dynamic>>>());
      expect(imported[1]['feedItems'], hasLength(1));
    } finally {
      db.dispose();
    }
  });
}
