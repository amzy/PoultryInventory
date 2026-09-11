import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

Future<String?> saveVCardFile(Uint8List bytes, String fileName) async {
  final blob = html.Blob(<dynamic>[bytes], 'text/vcard;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = fileName
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
  await Future<void>.delayed(const Duration(milliseconds: 100));
  return fileName;
}
