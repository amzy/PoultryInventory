import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/farm_config.dart';

class PoultryLog {
  final DateTime date;
  final int mortality;
  final double trays;
  final int totalEggs;
  final double avgTrayWeight;
  final double feedConsumed;
  final double stoneGritConsumed;
  final double waterIntake;
  final double automatedFCR;
  final String? createdByUid;
  final String? createdByName;
  final DateTime? createdAt;
  final String? updatedByUid;
  final String? updatedByName;
  final DateTime? updatedAt;

  PoultryLog({
    required this.date,
    required this.mortality,
    required this.trays,
    required this.totalEggs,
    required this.avgTrayWeight,
    required this.feedConsumed,
    required this.stoneGritConsumed,
    required this.waterIntake,
    required this.automatedFCR,
    this.createdByUid,
    this.createdByName,
    this.createdAt,
    this.updatedByUid,
    this.updatedByName,
    this.updatedAt,
  });

  factory PoultryLog.fromSheetRow(List<Object?> row) {
    double parseDouble(Object? value) => double.tryParse(value?.toString() ?? '') ?? 0.0;
    int parseInt(Object? value) => double.tryParse(value?.toString() ?? '')?.toInt() ?? 0;
    DateTime parseDate(Object? value) {
      final text = value?.toString() ?? '';
      try { return DateFormat('yyyy-MM-dd').parse(text); } catch (_) { return DateTime.tryParse(text) ?? DateTime.now(); }
    }
    // Supports the existing sheet layout. Bird-count columns are legacy/derived
    // values and are intentionally ignored; mortality is the stored bird event.
    return PoultryLog(
      date: parseDate(row[0]),
      mortality: parseInt(row[3]),
      trays: parseDouble(row[5]),
      totalEggs: parseInt(row[6]),
      avgTrayWeight: parseDouble(row[7]),
      feedConsumed: parseDouble(row[8]),
      stoneGritConsumed: parseDouble(row[9]),
      waterIntake: parseDouble(row[10]),
      automatedFCR: parseDouble(row[11]),
    );
  }

  int get flockAge => FarmConfig.flockAgeOn(date);

  PoultryLog copyWith({
    DateTime? date,
    int? totalEggs,
    double? automatedFCR,
  }) => PoultryLog(
    date: date ?? this.date,
    mortality: mortality,
    trays: trays,
    totalEggs: totalEggs ?? this.totalEggs,
    avgTrayWeight: avgTrayWeight,
    feedConsumed: feedConsumed,
    stoneGritConsumed: stoneGritConsumed,
    waterIntake: waterIntake,
    automatedFCR: automatedFCR ?? this.automatedFCR,
  );

  factory PoultryLog.fromFirestore(Map<String, dynamic> data) {
    final date = data['date'] is Timestamp
        ? (data['date'] as Timestamp).toDate()
        : DateTime.parse(data['dateKey'] as String);
    double d(dynamic v) => (v as num?)?.toDouble() ?? 0;
    int i(dynamic v) => (v as num?)?.toInt() ?? 0;
    return PoultryLog(
      date: date,
      mortality: i(data['mortality']),
      trays: d(data['trays']),
      totalEggs: i(data['totalEggs']),
      avgTrayWeight: d(data['avgTrayWeight']),
      feedConsumed: d(data['feedConsumed']),
      stoneGritConsumed: d(data['stoneGritConsumed']),
      waterIntake: d(data['waterIntake']),
      automatedFCR: d(data['automatedFCR']),
      createdByUid: data['createdByUid']?.toString(),
      createdByName: data['createdByName']?.toString(),
      createdAt: data['createdAt'] is Timestamp ? (data['createdAt'] as Timestamp).toDate() : null,
      updatedByUid: data['updatedByUid']?.toString(),
      updatedByName: data['updatedByName']?.toString(),
      updatedAt: data['updatedAt'] is Timestamp ? (data['updatedAt'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'date': Timestamp.fromDate(date),
    'dateKey': DateFormat('yyyy-MM-dd').format(date),
    'mortality': mortality,
    'trays': trays,
    'totalEggs': totalEggs,
    'avgTrayWeight': avgTrayWeight,
    'feedConsumed': feedConsumed,
    'stoneGritConsumed': stoneGritConsumed,
    'waterIntake': waterIntake,
    'automatedFCR': automatedFCR,
    if (createdByUid != null) 'createdByUid': createdByUid,
    if (createdByName != null) 'createdByName': createdByName,
    if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
    if (updatedByUid != null) 'updatedByUid': updatedByUid,
    if (updatedByName != null) 'updatedByName': updatedByName,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  List<Object?> toSheetRow() => <Object?>[
    DateFormat('yyyy-MM-dd').format(date),
    flockAge,
    '',
    mortality,
    '',
    trays,
    totalEggs,
    avgTrayWeight,
    feedConsumed,
    stoneGritConsumed,
    waterIntake,
    automatedFCR,
    '',
  ];
}
