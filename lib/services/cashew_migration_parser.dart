/// Converts Cashew/app-SQL transaction exports into the current Poultry
/// Inventory transaction model.
///
/// This is the compatibility boundary for imported files. Legacy labels are
/// intentionally handled here rather than in the normal expense model/UI.
class CashewMigrationParser {
  static const _defaultAccount = 'Amzad Khan';

  /// Backward-compatible parser for callers that provide a JSON-like payload.
  static List<Map<String, dynamic>> parse(Map<String, dynamic> payload) {
    final raw = payload['records'];
    if (raw is! List) {
      throw const FormatException(
        'Cashew migration must contain a records array.',
      );
    }
    return parseRecords(
      raw.whereType<Map>().map(Map<String, dynamic>.from).toList(),
    );
  }

  static List<Map<String, dynamic>> parseRecords(
    List<Map<String, dynamic>> rawRecords,
  ) {
    return rawRecords.map(_parseRecord).where(_isValidRecord).toList();
  }

  static Map<String, dynamic> _parseRecord(Map<String, dynamic> rawRecord) {
    final item = Map<String, dynamic>.from(rawRecord);
    final transactionId = _text(item['transactionId'] ?? item['id']);
    final date = _text(item['date'] ?? item['dateCreated']);
    final sourceMain = _text(item['mainCategory']);
    // For app exports, `category` is the stored category and is therefore
    // authoritative. Raw Cashew SQLite rows use `originalCategory` because
    // they do not have the app's canonical `category` field yet.
    final sourceCategory = _text(item['category']).isNotEmpty
        ? _text(item['category'])
        : _text(item['originalCategory']);
    final sourceOriginalCategory = _text(item['originalCategory']).isNotEmpty
        ? _text(item['originalCategory'])
        : sourceCategory;

    final main = _normalizeMainCategory(sourceMain);
    final category = _normalizeSubcategory(
      main,
      sourceCategory,
      sourceMain: sourceMain,
    );

    final amount = _number(item['amount']).abs();
    final quantity = _number(item['quantity']);
    final sourceTransactionType = _text(item['transactionType']);
    final income = _bool(
      item['income'] ?? item['isIncome'] ?? sourceTransactionType,
    );
    final transactionType = _normalizeTransactionType(
      sourceCategory: sourceCategory,
      sourceTransactionType: sourceTransactionType,
      income: income,
    );
    final account = _text(item['account'] ?? item['wallet'] ?? item['walletName']);

    return <String, dynamic>{
      'transactionId': transactionId,
      'date': date,
      'mainCategory': main,
      'category': category,
      // Keep the source label for audit/history. The actual category used by
      // the application is always the canonical `category` field above.
      'originalCategory': sourceOriginalCategory,
      'account': account.isEmpty ? _defaultAccount : account,
      'description': _text(
        item['description'] ?? item['name'] ?? item['note'],
      ),
      if (_text(item['supplierId'] ?? item['supplier_id']).isNotEmpty)
        'supplierId': _text(item['supplierId'] ?? item['supplier_id']),
      if (_text(item['supplierName'] ?? item['supplier_name']).isNotEmpty)
        'supplierName': _text(item['supplierName'] ?? item['supplier_name']),
      'amount': amount,
      'unitPrice': _number(item['unitPrice']),
      'freightCharge': category == 'Egg' && transactionType == 'credit'
          ? 0.0
          : _number(item['freightCharge']),
      'pricingCalculated': item['pricingCalculated'] == true,
      'unit': _text(item['unit']).isEmpty ? 'rupees' : _text(item['unit']),
      'quantity': quantity,
      'income': transactionType == 'credit',
      'transactionType': transactionType,
      if (_text(item['source']).isNotEmpty) 'source': _text(item['source']),
    };
  }

  static bool _isValidRecord(Map<String, dynamic> record) =>
      (record['transactionId'] as String).isNotEmpty &&
      (record['date'] as String).isNotEmpty &&
      (record['amount'] as double) >= 0;

  static String _normalizeMainCategory(String source) {
    switch (_categoryKey(source)) {
      case 'layer bird':
        return 'Layer Bird';
      case 'chiks':
      case 'chicks':
        return 'Chiks';
      case 'renovation':
        return 'Renovation';
      case 'augar work':
        return 'Augar Work';
      case 'electricity':
        // Cashew can represent Electricity as a top-level category.
        return 'Layer Bird';
      // Some old exports may incorrectly promote Egg Sales to the top level.
      // Keep it in the valid financial hierarchy.
      case 'egg sales':
      case 'egg sale':
        return 'Layer Bird';
      default:
        throw FormatException('Unsupported Cashew main category: $source');
    }
  }

  static String _normalizeSubcategory(
    String mainCategory,
    String source, {
    String? sourceMain,
  }) {
    final lower = _categoryKey(source);
    final sourceMainKey = _categoryKey(sourceMain ?? mainCategory);

    if (sourceMainKey == 'electricity' && lower.isEmpty) {
      return 'Electricity';
    }

    switch (lower) {
      case 'layer feed':
      case 'feed':
        return 'Feed';
      case 'stone':
      case 'grit':
        return 'Grit';
      case 'health':
      case 'dr fee':
      case 'healthcare':
      case 'medical':
        return 'Medical';
      case 'vaccine':
        return 'Vaccine';
      case 'construction labor':
      case 'steel labor':
      case 'labor work':
      case 'labor':
        return 'Labor';
      case 'construction materials':
      case 'materials':
      case 'material':
        return 'Material';
      case 'egg sales':
      case 'egg sale':
      case 'egg':
        return 'Egg';
      case 'electricity':
        return 'Electricity';
      case 'tray':
        return 'Tray';
      case 'preparation':
        return 'Preparation';
      case 'water':
        return 'Water';
      case 'other expenses':
        return 'Other Expenses';
    }

    if (lower.isEmpty || lower == _categoryKey(mainCategory)) {
      return 'Other Expenses';
    }

    // Cashew exports may add emoji/decorative characters to a canonical label.
    const canonical = <String>[
      'Feed',
      'Medical',
      'Vaccine',
      'Tray',
      'Egg',
      'Electricity',
      'Grit',
      'Preparation',
      'Water',
      'Labor',
      'Material',
      'Other Expenses',
    ];
    for (final value in canonical) {
      if (_categoryKey(value) == lower) return value;
    }

    throw FormatException(
      'Unsupported Cashew subcategory "$source" for main category "$mainCategory".',
    );
  }

  static String _normalizeTransactionType({
    required String sourceCategory,
    required String sourceTransactionType,
    required bool income,
  }) {
    // Egg Sales is a semantic source category, not a stored subcategory.
    // Always import it as an Egg credit even if an old export incorrectly
    // stored its income flag/transaction type as expense.
    final sourceKey = _categoryKey(sourceCategory);
    if (sourceKey == 'egg sales' || sourceKey == 'egg sale') {
      return 'credit';
    }

    if (sourceTransactionType.trim().isNotEmpty) {
      final key = _categoryKey(sourceTransactionType);
      if (key == 'credit' || key == 'income') return 'credit';
      if (key == 'expense' || key == 'debit') return 'expense';
    }
    return income ? 'credit' : 'expense';
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
    return text == 'true' ||
        text == '1' ||
        text == 'income' ||
        text == 'credit';
  }

  static String _categoryKey(String value) => value
      .replaceAll(RegExp(r'[^A-Za-z0-9]+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ')
      .toLowerCase();
}
