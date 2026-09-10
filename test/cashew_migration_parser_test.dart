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

  test('maps top-level Electricity into Layer Bird / Electricity', () {
    final records = CashewMigrationParser.parse({
      'records': [
        {
          'transactionId': 'electricity-1',
          'date': '2026-06-03',
          'mainCategory': 'Electricity',
          'category': 'Electricity',
          'amount': 1053,
          'account': 'Amzad Khan',
          'description': 'Satteled two month bill',
        },
      ],
    });

    expect(records.single['mainCategory'], 'Layer Bird');
    expect(records.single['category'], 'Electricity');
    expect(records.single['originalCategory'], 'Electricity');
  });

  test('maps a top-level work category without a subcategory to Other Expenses', () {
    final records = CashewMigrationParser.parse({
      'records': [
        {
          'transactionId': '3',
          'date': '2026-02-01',
          'mainCategory': 'Augar Work',
          'category': 'Augar Work',
          'amount': 500,
          'account': 'Amzad Khan',
        },
      ],
    });

    expect(records.single['mainCategory'], 'Augar Work');
    expect(records.single['category'], 'Other Expenses');
    expect(records.single['originalCategory'], 'Augar Work');
  });

  test('normalizes Cashew subcategory emojis to canonical names', () {
    final records = CashewMigrationParser.parse({
      'records': [
        {
          'transactionId': 'water-emoji',
          'date': '2026-02-03',
          'mainCategory': 'Chiks 🐥',
          'category': 'Water 💦',
          'amount': 125,
          'account': 'Amzad Khan',
        },
        {
          'transactionId': 'feed-emoji',
          'date': '2026-02-04',
          'mainCategory': 'Layer Bird',
          'category': 'Feed 🌾',
          'amount': 250,
          'account': 'Sarfaraj Khan',
        },
      ],
    });

    expect(records[0]['category'], 'Water');
    expect(records[0]['originalCategory'], 'Water 💦');
    expect(records[1]['category'], 'Feed');
    expect(records[1]['originalCategory'], 'Feed 🌾');
  });

  test('maps income to credit and preserves account', () {
    final records = CashewMigrationParser.parse({
      'records': [
        {
          'transactionId': 'income-1',
          'date': '2026-02-01',
          'mainCategory': 'Layer Bird',
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

  test('converts legacy Egg_Sales into Egg credit', () {
    final records = CashewMigrationParser.parse({
      'records': [
        {
          'transactionId': 'legacy-egg-sale',
          'date': '2026-09-01',
          'mainCategory': 'Layer Bird',
          'category': 'Egg_Sales',
          'amount': 3000,
          'freightCharge': 700,
          'transactionType': 'expense',
          'account': 'Amzad Khan',
        },
      ],
    });

    expect(records.single['category'], 'Egg');
    expect(records.single['originalCategory'], 'Egg_Sales');
    expect(records.single['transactionType'], 'credit');
    expect(records.single['income'], true);
    expect(records.single['freightCharge'], 0.0);
  });

  test('converts legacy Materials into Material', () {
    final records = CashewMigrationParser.parse({
      'records': [
        {
          'transactionId': 'legacy-material',
          'date': '2026-09-02',
          'mainCategory': 'Renovation',
          'category': 'Materials',
          'amount': 1500,
          'account': 'Amzad Khan',
        },
        {
          'transactionId': 'canonical-material',
          'date': '2026-09-03',
          'mainCategory': 'Renovation',
          'category': 'Material',
          'amount': 500,
          'account': 'Amzad Khan',
        },
      ],
    });

    expect(records[0]['category'], 'Material');
    expect(records[0]['originalCategory'], 'Materials');
    expect(records[1]['category'], 'Material');
  });

}
