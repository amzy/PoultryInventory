import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FarmConfig {
  static final DateTime defaultFlockStartDate = DateTime(2026, 4, 26);
  static const int defaultStartingBirds = 5200;
  static const String defaultBreedName = '';
  static const List<String> defaultAccounts = ['Amzad Khan', 'Sarfaraj Khan'];
  static const List<String> defaultFeedItems = [
    'LCC (Starter)',
    'LGC (Grower)',
    'LCDP (Developer)',
    'LCLP1 (Phase 1)',
    'Finisher',
  ];

  final DateTime flockStartDate;
  final int startingBirds;
  final String breedName;
  final List<String> accounts;
  final List<String> feedItems;

  const FarmConfig({
    required this.flockStartDate,
    required this.startingBirds,
    required this.breedName,
    required this.accounts,
    this.feedItems = defaultFeedItems,
  });

  static final FarmConfig defaults = FarmConfig(
    flockStartDate: defaultFlockStartDate,
    startingBirds: defaultStartingBirds,
    breedName: defaultBreedName,
    accounts: defaultAccounts,
    feedItems: defaultFeedItems,
  );

  factory FarmConfig.fromMap(Map<String, dynamic> data) {
    final rawDate = data['flockStartDate'];
    DateTime date = defaultFlockStartDate;
    if (rawDate is Timestamp) {
      date = rawDate.toDate();
    } else if (rawDate is DateTime) {
      date = rawDate;
    } else if (rawDate != null) {
      date = DateTime.tryParse(rawDate.toString()) ?? date;
    }
    final rawAccounts = data['accounts'];
    final rawFeedItems = data['feedItems'];
    final accounts = rawAccounts is List
        ? rawAccounts.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toSet().toList()
        : <String>[];
    final feedItems = rawFeedItems is List
        ? rawFeedItems.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toSet().toList()
        : <String>[];
    return FarmConfig(
      flockStartDate: DateTime(date.year, date.month, date.day),
      startingBirds: (data['openingBirds'] as num?)?.toInt() ?? defaultStartingBirds,
      breedName: data['breedName']?.toString() ?? '',
      accounts: accounts.isEmpty ? List<String>.from(defaultAccounts) : accounts,
      feedItems: feedItems.isEmpty ? List<String>.from(defaultFeedItems) : feedItems,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'initialized': true,
    'openingBirds': startingBirds,
    'firstLogDateKey': DateFormat('yyyy-MM-dd').format(flockStartDate.add(const Duration(days: 1))),
    'flockStartDate': DateTime(flockStartDate.year, flockStartDate.month, flockStartDate.day),
    'breedName': breedName.trim(),
    'accounts': accounts,
    'feedItems': feedItems,
  };

  static int flockAgeOn(DateTime date) => DateTime(date.year, date.month, date.day).difference(
    DateTime(defaultFlockStartDate.year, defaultFlockStartDate.month, defaultFlockStartDate.day),
  ).inDays;

  static int flockAgeOnDate(DateTime date, {DateTime? startDate}) =>
      DateTime(date.year, date.month, date.day).difference(
        DateTime((startDate ?? defaultFlockStartDate).year, (startDate ?? defaultFlockStartDate).month, (startDate ?? defaultFlockStartDate).day),
      ).inDays;
}
