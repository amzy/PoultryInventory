import 'package:sqlite3/common.dart';

/// Reads the Cashew SQLite export directly. Cashew uses a `.sql` extension
/// for this file, but the file itself is a SQLite database.
class CashewSqliteQueries {
  static List<Map<String, dynamic>> readTransactions(CommonDatabase db) {
    final wallets = <String, String>{};
    for (final row in db.select('SELECT wallet_pk, name FROM wallets')) {
      wallets[row['wallet_pk']?.toString() ?? ''] = row['name']?.toString() ?? '';
    }

    final categories = <String, Map<String, dynamic>>{};
    for (final row in db.select('''
      SELECT category_pk, name, main_category_pk, income
      FROM categories
    ''')) {
      categories[row['category_pk']?.toString() ?? ''] = {
        'name': row['name']?.toString() ?? '',
        'mainCategoryPk': row['main_category_pk']?.toString(),
        'income': row['income'],
      };
    }

    String text(dynamic value) => value?.toString().trim() ?? '';
    double number(dynamic value) => value is num ? value.toDouble() : double.tryParse(text(value)) ?? 0;

    String dateFromEpoch(dynamic value) {
      final seconds = value is num ? value.toInt() : int.tryParse(text(value)) ?? 0;
      return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true)
          .toIso8601String()
          .substring(0, 10);
    }

    final records = <Map<String, dynamic>>[];
    for (final row in db.select('''
      SELECT transaction_pk, name, amount, note, category_fk, sub_category_fk,
             wallet_fk, date_created, income
      FROM transactions
      ORDER BY date_created
    ''')) {
      final main = categories[text(row['category_fk'])];
      final sub = categories[text(row['sub_category_fk'])];
      final mainName = text(main?['name']).isEmpty ? 'Cashew' : text(main?['name']);
      final originalCategory = text(sub?['name']).isEmpty ? mainName : text(sub?['name']);

      records.add({
        'transactionId': text(row['transaction_pk']),
        'date': dateFromEpoch(row['date_created']),
        'mainCategory': mainName,
        'originalCategory': originalCategory,
        'account': wallets[text(row['wallet_fk'])] ?? 'Unassigned',
        'description': [text(row['name']), text(row['note'])].where((e) => e.isNotEmpty).join(' • '),
        // Cashew stores expenses as negative amounts. Firestore stores the
        // positive amount and transactionType tells us whether it is expense/credit.
        'amount': number(row['amount']).abs(),
        'unit': 'rupees',
        'quantity': 0.0,
        'income': row['income'] == true || row['income'] == 1 || row['income']?.toString() == '1',
      });
    }

    return records;
  }
}
