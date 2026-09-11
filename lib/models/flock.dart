import 'package:cloud_firestore/cloud_firestore.dart';

class Flock {
  final String id;
  final String name;
  final DateTime startDate;
  final DateTime? endDate;
  final int startingBirds;
  final String breedName;
  final List<String> accounts;
  final List<String> feedItems;
  final String createdByUid;

  const Flock({
    required this.id,
    required this.name,
    required this.startDate,
    this.endDate,
    required this.startingBirds,
    required this.breedName,
    required this.accounts,
    required this.feedItems,
    required this.createdByUid,
  });

  bool get isActive => endDate == null;

  String get state => isActive ? 'running' : 'ended';

  factory Flock.fromFirestore(String id, Map<String, dynamic> data) {
    DateTime? asDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return value == null ? null : DateTime.tryParse(value.toString());
    }
    List<String> strings(dynamic value) => value is List
        ? value.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toSet().toList()
        : <String>[];
    return Flock(
      id: id,
      name: data['name']?.toString().trim().isNotEmpty == true ? data['name'].toString().trim() : 'Flock',
      startDate: asDate(data['startDate']) ?? DateTime.now(),
      endDate: asDate(data['endDate']),
      startingBirds: (data['startingBirds'] as num?)?.toInt() ?? 0,
      breedName: data['breedName']?.toString() ?? '',
      accounts: strings(data['accounts']),
      feedItems: strings(data['feedItems']),
      createdByUid: data['createdByUid']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name.trim(),
    'startDate': Timestamp.fromDate(DateTime(startDate.year, startDate.month, startDate.day)),
    'endDate': endDate == null ? null : Timestamp.fromDate(DateTime(endDate!.year, endDate!.month, endDate!.day)),
    'startingBirds': startingBirds,
    'breedName': breedName.trim(),
    'accounts': accounts,
    'feedItems': feedItems,
    'createdByUid': createdByUid,
    'updatedAt': FieldValue.serverTimestamp(),
  };
}

class FlockMembership {
  final String uid;
  final String flockId;
  final String role;
  final String email;
  final String displayName;
  final String mobileNumber;
  final String notificationLanguage;
  final String status;
  final bool invitationReported;

  const FlockMembership({this.uid = '', required this.flockId, required this.role, required this.email, required this.displayName, this.mobileNumber = '', this.notificationLanguage = 'en', this.status = 'active', this.invitationReported = false});

  bool get isAdmin => role == 'admin';

  factory FlockMembership.fromFirestore(String flockId, Map<String, dynamic> data, {String uid = ''}) => FlockMembership(
    uid: uid,
    flockId: flockId,
    role: data['role']?.toString() == 'admin' ? 'admin' : 'member',
    email: data['email']?.toString() ?? '',
    displayName: data['displayName']?.toString() ?? '',
    mobileNumber: data['mobileNumber']?.toString() ?? '',
    notificationLanguage: data['notificationLanguage']?.toString() == 'hi' ? 'hi' : 'en',
    status: ['pending','declined','active','suspended'].contains(data['status']?.toString()) ? data['status'].toString() : 'active',
    invitationReported: data['permanentlyReported'] == true,
  );
}
