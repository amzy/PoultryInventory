import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poultry_inventory/models/expense_sales_log.dart';

void main() {
  group('ExpenseSalesLog', () {
    test('calculates net total as amount plus freight', () {
      final record = ExpenseSalesLog(
        date: DateTime(2026, 9, 10),
        category: 'Feed',
        description: 'Feed purchase',
        amount: 10000,
        unit: 'bag',
        quantity: 4,
        freightCharge: 700,
      );
      expect(record.netTotal, 10700);
    });

    test('preserves Medical dynamic line items', () {
      final record = ExpenseSalesLog(
        date: DateTime(2026, 9, 10),
        category: 'Medical',
        description: 'Medical purchase',
        amount: 800,
        unit: 'rupees',
        quantity: 0,
        medicalItems: [
          {'name': 'Vitamin', 'price': 250.0, 'quantity': 2.0, 'total': 500.0},
          {'name': 'Medicine', 'price': 100.0, 'quantity': 3.0, 'total': 300.0},
        ],
      );
      expect(record.toFirestore()['medicalItems'], isNotEmpty);
      expect(record.medicalItems, hasLength(2));
    });

    test('supports dynamic feed items and 50 kg bag pricing', () {
      final record = ExpenseSalesLog(
        date: DateTime(2026, 9, 10),
        category: 'Feed',
        description: 'Feed purchase',
        amount: 38000,
        freightCharge: 700,
        unit: '50 kg/bag',
        quantity: 15,
        feedItems: [
          {'name': 'LCC (Starter)', 'quantity': 10.0, 'pricePerBag': 2500.0, 'bagWeightKg': 50, 'total': 25000.0},
          {'name': 'LGC (Grower)', 'quantity': 5.0, 'pricePerBag': 2600.0, 'bagWeightKg': 50, 'total': 13000.0},
        ],
      );
      expect(record.feedItems, hasLength(2));
      expect(record.netTotal, 38700);
      expect(record.toFirestore()['feedItems'], isNotEmpty);
    });

    test('egg sales use Egg category and ignore freight', () {
      final record = ExpenseSalesLog(
        date: DateTime(2026, 9, 10),
        category: 'Egg',
        description: 'Egg sale',
        amount: 3000,
        freightCharge: 700,
        unit: 'tray',
        quantity: 10,
        transactionType: 'credit',
      );
      expect(record.netTotal, 3000);
      expect(record.toFirestore()['freightCharge'], 0);
      expect(record.toFirestore()['category'], 'Egg');
      expect(record.toFirestore()['transactionType'], 'credit');
    });

    test('reads a legacy-shaped record without optional fields', () {
      final sourceRecord = ExpenseSalesLog(
        date: DateTime(2026, 9, 9),
        category: 'Feed',
        description: 'Legacy feed',
        amount: 10000,
        unit: 'bag',
        quantity: 4,
        freightCharge: 700,
        transactionType: 'expense',
      );
      final legacy = Map.of(sourceRecord.toFirestore());
      legacy.remove('feedItems');
      legacy.remove('medicalItems');
      legacy.remove('createdByUid');
      legacy.remove('updatedByUid');
      legacy.remove('createdAt');
      legacy.remove('updatedAt');
      legacy['date'] = Timestamp.fromDate(DateTime(2026, 9, 9));

      final record = ExpenseSalesLog.fromFirestore(legacy, id: 'legacy-1');
      expect(record.id, 'legacy-1');
      expect(record.feedItems, isEmpty);
      expect(record.createdByUid, isNull);
      expect(record.netTotal, 10700);
    });

    test('does not write medicalItems when there are no medical items', () {
      final record = ExpenseSalesLog(
        date: DateTime(2026, 9, 10),
        category: 'Feed',
        description: 'Feed purchase',
        amount: 1000,
        unit: 'rupees',
        quantity: 0,
      );
      expect(record.toFirestore(), isNot(contains('medicalItems')));
    });

    test('round-trips optional medical items from Firestore data', () {
      final source = ExpenseSalesLog(
        date: DateTime(2026, 9, 10),
        category: 'Medical',
        description: 'Medicine',
        amount: 800,
        unit: 'rupees',
        quantity: 0,
        medicalItems: [
          {'name': 'Vitamin', 'price': 250, 'quantity': 2, 'total': 500},
        ],
      );
      final data = Map.of(source.toFirestore());
      final record = ExpenseSalesLog.fromFirestore(data, id: 'medical-1');
      expect(record.id, 'medical-1');
      expect(record.medicalItems, hasLength(1));
      expect(record.medicalItems.single['name'], 'Vitamin');
      expect(record.netTotal, 800);
    });
  });
}
