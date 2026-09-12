import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

Future<String?> saveSqlFile(Uint8List bytes, String fileName) async {
  final uri = await FilePicker.saveFile(
    dialogTitle: 'Export Poultry Inventory financial data',
    fileName: fileName,
    type: FileType.custom,
    allowedExtensions: ['sql'],
    bytes: bytes,
  );

  return uri?.toString();
}
