import 'dart:io';
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';

import 'cashew_sqlite_queries.dart';

Future<List<Map<String, dynamic>>> parseCashewSqliteBytes(Uint8List bytes) async {
  if (bytes.length < 16 || String.fromCharCodes(bytes.sublist(0, 15)) != 'SQLite format 3') {
    throw const FormatException('Selected file is not a SQLite database.');
  }

  final file = File('${Directory.systemTemp.path}/cashew_import_${DateTime.now().microsecondsSinceEpoch}.db');
  try {
    await file.writeAsBytes(bytes, flush: true);
    final db = sqlite3.open(file.path, mode: OpenMode.readOnly);
    try {
      return CashewSqliteQueries.readTransactions(db);
    } finally {
      db.close();
    }
  } finally {
    try {
      await file.delete();
    } catch (_) {}
  }
}
