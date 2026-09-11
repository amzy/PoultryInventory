import 'dart:convert';
import '../../models/supplier.dart';

final class VCardGenerator {
  const VCardGenerator();

  String generate(Iterable<Supplier> suppliers) {
    return suppliers.map(_single).join('\r\n') + '\r\n';
  }

  String _single(Supplier supplier) {
    final lines = <String>[
      'BEGIN:VCARD',
      'VERSION:3.0',
      'FN:${_escape(supplier.fullName)}',
      'N:${_escape(supplier.fullName)};;;;',
    ];

    for (final phone in supplier.phoneNumbers) {
      lines.add('TEL;TYPE=CELL:${_escape(phone)}');
    }
    if (supplier.businessAddress.trim().isNotEmpty) {
      lines.add('ADR;TYPE=WORK:;;${_escape(supplier.businessAddress)};;;;');
    }
    if (supplier.category.trim().isNotEmpty) {
      lines.add('NOTE:${_escape(supplier.category)}');
    }
    lines.add('END:VCARD');
    return lines.join('\r\n');
  }

  String _escape(String value) => value
      .replaceAll('\\', '\\\\')
      .replaceAll(';', '\\;')
      .replaceAll(',', '\\,')
      .replaceAll('\r\n', '\\n')
      .replaceAll('\n', '\\n')
      .replaceAll('\r', '\\n');

  List<int> bytes(Iterable<Supplier> suppliers) => utf8.encode(generate(suppliers));
}
