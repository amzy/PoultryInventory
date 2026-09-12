import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

Future<String?> saveVCardFile(Uint8List bytes, String fileName) async {
  final uri = await FilePicker.saveFile(
    dialogTitle: 'Export supplier contacts',
    fileName: fileName,
    type: FileType.custom,
    allowedExtensions: ['vcf'],
    bytes: bytes,
  );

  return uri?.toString();
}
