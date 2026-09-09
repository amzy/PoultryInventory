import 'dart:convert';
import 'dart:typed_data';

import 'package:sqlite3/wasm.dart';
import 'package:typed_data/typed_buffers.dart';

import 'app_sql_export.dart';
import 'app_sqlite_queries.dart';
import 'cashew_sqlite_queries.dart';

Future<List<Map<String, dynamic>>> parseCashewSqliteBytes(Uint8List bytes) async {
  if (_isSqlite(bytes)) {
    final sqlite = await WasmSqlite3.loadFromUrl(Uri.parse('sqlite3.wasm'));
    final vfs = InMemoryFileSystem();
    final path = '/cashew_import.db';
    vfs.fileData[path] = Uint8Buffer()..addAll(bytes);
    sqlite.registerVirtualFileSystem(vfs, makeDefault: true);
    final db = sqlite.open(path, vfs: vfs.name, mode: OpenMode.readOnly);
    return CashewSqliteQueries.readTransactions(db);
  }

  final text = utf8.decode(bytes, allowMalformed: false);
  if (!AppSqlExport.isAppSql(text)) {
    throw const FormatException(
      'Unsupported file. Select a Cashew SQLite export or a Poultry Inventory SQL export created from Settings.',
    );
  }

  final sqlite = await WasmSqlite3.loadFromUrl(Uri.parse('sqlite3.wasm'));
  final vfs = InMemoryFileSystem();
  final path = '/poultry_sql_import.db';
  sqlite.registerVirtualFileSystem(vfs, makeDefault: true);
  final db = sqlite.open(path, vfs: vfs.name);
  db.execute(text);
  return AppSqliteQueries.readTransactions(db);
}

bool _isSqlite(Uint8List bytes) =>
    bytes.length >= 15 && String.fromCharCodes(bytes.sublist(0, 15)) == 'SQLite format 3';
