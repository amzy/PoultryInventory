import 'expense_category_config.dart';

/// Normalizes records read directly from Cashew's SQLite database.
///
/// The SQLite import format is intentionally no longer required by the UI.
/// This parser remains a small normalization layer so category mappings are
/// applied consistently to every direct SQLite import.
class CashewMigrationParser {
  /// Backward-compatible parser for tests/legacy callers. The Settings UI no
  /// longer accepts JSON; it reads the SQLite export directly.
  static List<Map<String, dynamic>> parse(Map<String, dynamic> payload) {
    final raw = payload['records'];
    if (raw is! List) {
      throw const FormatException('Cashew migration must contain a records array.');
    }
    return parseRecords(raw.whereType<Map>().map(Map<String, dynamic>.from).toList());
  }

  static List<Map<String, dynamic>> parseRecords(List<Map<String, dynamic>> rawRecords) {
    return rawRecords.map((rawRecord) {
      final item = Map<String, dynamic>.from(rawRecord);
      final transactionId = _text(item['transactionId'] ?? item['id']);
      final date = _text(item['date'] ?? item['dateCreated']);
      final main = _text(item['mainCategory']).isEmpty ? 'Cashew' : _text(item['mainCategory']);
      final original = _text(item['originalCategory']).isNotEmpty
          ? _text(item['originalCategory'])
          : _text(item['category']);
      final normalized = ExpenseCategoryConfig.normalizeImportedSubcategory(main, original);
      final amount = _number(item['amount']).abs();
      final quantity = _number(item['quantity']);
      final income = _bool(item['income'] ?? item['isIncome'] ?? item['transactionType']);
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
    }).where((r) =>
        (r['transactionId'] as String).isNotEmpty &&
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
