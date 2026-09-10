import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';

import 'app_sql_export.dart';
import 'app_sqlite_queries.dart';
import 'cashew_sqlite_queries.dart';

Future<List<Map<String, dynamic>>> parseCashewSqliteBytes(Uint8List bytes) async {
  if (_isSqlite(bytes)) {
    final file = File('${Directory.systemTemp.path}/cashew_import_${DateTime.now().microsecondsSinceEpoch}.db');
    try {
      await file.writeAsBytes(bytes, flush: true);
      final db = sqlite3.open(file.path, mode: OpenMode.readOnly);
      try {
        return CashewSqliteQueries.readTransactions(db);
      } finally {
        db.dispose();
      }
    } finally {
      try { await file.delete(); } catch (_) {}
    }
  }

  return _readSqlScript(bytes);
}

bool _isSqlite(Uint8List bytes) =>
    bytes.length >= 15 && String.fromCharCodes(bytes.sublist(0, 15)) == 'SQLite format 3';

List<Map<String, dynamic>> _readSqlScript(Uint8List bytes) {
  final text = utf8.decode(bytes, allowMalformed: false);
  if (!AppSqlExport.isAppSql(text)) {
    throw const FormatException(
      'Unsupported file. Select a Cashew SQLite export or a Poultry Inventory SQL export created from Settings.',
    );
  }

  final db = sqlite3.openInMemory();
  try {
    db.execute(text);
    return AppSqliteQueries.readTransactions(db);
  } finally {
    db.dispose();
  }
}
