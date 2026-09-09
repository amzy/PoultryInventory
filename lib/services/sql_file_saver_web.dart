import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

/// Browsers do not implement FilePicker.saveFile() as a native Save As dialog.
/// Trigger a normal browser download instead.
Future<String?> saveSqlFile(Uint8List bytes, String fileName) async {
  final blob = html.Blob(<dynamic>[bytes], 'application/sql;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = fileName
    ..style.display = 'none';

  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);

  // Give the browser event loop a chance to start the download before the
  // caller clears its busy state.
  await Future<void>.delayed(const Duration(milliseconds: 100));
  return fileName;
}
