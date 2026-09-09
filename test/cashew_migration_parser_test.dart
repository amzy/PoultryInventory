import 'package:flutter_test/flutter_test.dart';
import 'package:poultry_inventory/services/cashew_migration_parser.dart';

void main() {
  test('normalizes configured Cashew subcategories and preserves source fields', () {
    final records = CashewMigrationParser.parse({
      'records': [
        {
          'transactionId': '1',
          'date': '2026-01-01',
          'mainCategory': 'Layer Bird',
          'category': 'Layer Feed',
          'amount': 100,
          'account': 'Amzad Khan',
          'description': 'Feed purchase',
        },
        {
          'transactionId': '2',
          'date': '2026-01-02',
          'mainCategory': 'Renovation',
          'category': 'Construction Labor',
          'amount': 200,
          'account': 'Sarfaraj Khan',
        },
      ],
    });

    expect(records[0]['category'], 'Feed');
    expect(records[0]['originalCategory'], 'Layer Feed');
    expect(records[0]['mainCategory'], 'Layer Bird');
    expect(records[0]['transactionType'], 'expense');
    expect(records[1]['category'], 'Labor');
    expect(records[1]['originalCategory'], 'Construction Labor');
  });

  test('maps income to credit and preserves account', () {
    final records = CashewMigrationParser.parse({
      'records': [
        {
          'transactionId': 'income-1',
          'date': '2026-02-01',
          'mainCategory': 'Income',
          'category': 'Egg',
          'amount': 500,
          'income': true,
          'account': 'Amzad Khan',
        },
      ],
    });

    expect(records.single['transactionType'], 'credit');
    expect(records.single['income'], true);
    expect(records.single['account'], 'Amzad Khan');
  });
}
