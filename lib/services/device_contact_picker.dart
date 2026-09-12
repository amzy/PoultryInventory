import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

class PickedPhoneContact {
  const PickedPhoneContact({required this.name, required this.phoneNumbers});

  final String name;
  final List<String> phoneNumbers;
}

/// Opens the device contacts list and returns contacts that have at least one
/// phone number. Web intentionally returns an empty list because this helper
/// uses native device contacts.
Future<List<PickedPhoneContact>> getDevicePhoneContacts() async {
  if (kIsWeb) return const <PickedPhoneContact>[];

  final permission = await FlutterContacts.permissions.request(
    PermissionType.read,
  );
  if (permission != PermissionStatus.granted) {
    throw StateError('Contacts permission was not granted.');
  }

  final contacts = await FlutterContacts.getAll(
    properties: {
      ContactProperty.name,
      ContactProperty.phone,
    },
  );

  final candidates = contacts
      .map((contact) {
        final numbers = contact.phones
            .map((phone) => phone.number.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList(growable: false);

        return PickedPhoneContact(
          name: (contact.displayName ?? '').trim(),
          phoneNumbers: numbers,
        );
      })
      .where((contact) => contact.phoneNumbers.isNotEmpty)
      .toList(growable: false)
    ..sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );

  return candidates;
}
