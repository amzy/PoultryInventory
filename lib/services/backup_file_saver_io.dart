import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

Future<String?> saveBackupFile(Uint8List bytes, String fileName) async {
  final uri = await FilePicker.saveFile(
    dialogTitle: 'Export Poultry Inventory flock backup',
    fileName: fileName,
    type: FileType.custom,
    allowedExtensions: ['json'],
    bytes: bytes,
  );

  return uri?.toString();
}
