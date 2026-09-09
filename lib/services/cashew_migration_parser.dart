import 'expense_category_config.dart';

/// Converts a Cashew migration payload into the app's stable transaction shape.
///
/// Keep this parser as the only place where source-specific Cashew field names
/// and category mappings are interpreted. Future Cashew migrations can keep
/// using the same payload shape without changing Firestore or dashboard code.
class CashewMigrationParser {
  static List<Map<String, dynamic>> parse(Map<String, dynamic> payload) {
    final raw = payload['records'];
    if (raw is! List) {
      throw const FormatException('Cashew migration must contain a records array.');
    }

    return raw.whereType<Map>().map((rawRecord) {
      final item = Map<String, dynamic>.from(rawRecord);
      final transactionId = _text(item['transactionId'] ?? item['id']);
      final date = _text(item['date'] ?? item['dateCreated']);
      final main = _text(item['mainCategory']).isEmpty ? 'Cashew' : _text(item['mainCategory']);
      final original = _text(item['originalCategory']).isNotEmpty
          ? _text(item['originalCategory'])
          : _text(item['category']);
      final normalized = ExpenseCategoryConfig.normalizeImportedSubcategory(main, original);
      final amount = _number(item['amount']);
      final quantity = _number(item['quantity']);
      final income = _bool(item['income'] ?? item['isIncome'] ?? item['type'] == 'income');
      final account = _text(item['account'] ?? item['wallet'] ?? item['walletName']);

      return <String, dynamic>{
        'transactionId': transactionId,
        'date': date,
        'mainCategory': main,
        'category': normalized,
        'originalCategory': original,
        'account': account.isEmpty ? ExpenseCategoryConfig.accounts.first : account,
        'description': _text(item['description'] ?? item['name'] ?? item['note']),
        'amount': amount,
        'unit': _text(item['unit']).isEmpty ? 'rupees' : _text(item['unit']),
        'quantity': quantity,
        'income': income,
        'transactionType': income ? 'credit' : 'expense',
      };
    }).where((r) => (r['transactionId'] as String).isNotEmpty &&
        (r['date'] as String).isNotEmpty &&
        (r['amount'] as double) >= 0).toList();
  }

  static String _text(dynamic value) => value?.toString().trim() ?? '';

  static double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(_text(value)) ?? 0;
  }

  static bool _bool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = _text(value).toLowerCase();
    return text == 'true' || text == '1' || text == 'income' || text == 'credit';
  }
}
