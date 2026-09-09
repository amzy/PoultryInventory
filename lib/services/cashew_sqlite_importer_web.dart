import 'dart:typed_data';

import 'package:sqlite3/wasm.dart';
import 'package:typed_data/typed_buffers.dart';

import 'cashew_sqlite_queries.dart';

Future<List<Map<String, dynamic>>> parseCashewSqliteBytes(Uint8List bytes) async {
  if (bytes.length < 16 || String.fromCharCodes(bytes.sublist(0, 15)) != 'SQLite format 3') {
    throw const FormatException('Selected file is not a SQLite database.');
  }

  final sqlite = await WasmSqlite3.loadFromUrl(Uri.parse('sqlite3.wasm'));
  final vfs = InMemoryFileSystem();
  final path = '/cashew_import.db';
  vfs.fileData[path] = Uint8Buffer()..addAll(bytes);
  sqlite.registerVirtualFileSystem(vfs, makeDefault: true);

  final db = sqlite.open(path, vfs: vfs.name, mode: OpenMode.readOnly);
  return CashewSqliteQueries.readTransactions(db);
}
