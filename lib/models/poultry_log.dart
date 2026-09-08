import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/farm_config.dart';

class PoultryLog {
  final DateTime date;
  final int flockAge;
  final int startingBirds;
  final int mortality;
  final int endingBirds;
  final double trays;
  final int totalEggs;
  final double avgTrayWeight;
  final double feedConsumed;
  final double stoneGritConsumed;
  final double waterIntake;
  final double automatedFCR;
  final double layingPercentage;
  final String previousDateKey;
  final int previousEndingBirds;

  PoultryLog({
    required this.date,
    required this.flockAge,
    required this.startingBirds,
    required this.mortality,
    required this.endingBirds,
    required this.trays,
    required this.totalEggs,
    required this.avgTrayWeight,
    required this.feedConsumed,
    required this.stoneGritConsumed,
    required this.waterIntake,
    required this.automatedFCR,
    required this.layingPercentage,
    this.previousDateKey = '',
    this.previousEndingBirds = 0,
  });

  factory PoultryLog.fromSheetRow(List<Object?> row) {
    double parseDouble(Object? value) =>
        double.tryParse(value?.toString() ?? '') ?? 0.0;

    int parseInt(Object? value) =>
        double.tryParse(value?.toString() ?? '')?.toInt() ?? 0;

    DateTime parseDate(Object? value) {
      final text = value?.toString() ?? '';
      try {
        return DateFormat('yyyy-MM-dd').parse(text);
      } catch (_) {
        return DateTime.tryParse(text) ?? DateTime.now();
      }
    }

    // Daily_Log columns A:M:
    // Date, Age, Starting, Mortality, Ending, Trays, Eggs,
    // Avg Tray Weight, Feed, Grit, Water, FCR, Laying %.
    return PoultryLog(
      date: parseDate(row[0]),
      flockAge: parseInt(row[1]),
      startingBirds: parseInt(row[2]),
      mortality: parseInt(row[3]),
      endingBirds: parseInt(row[4]),
      trays: parseDouble(row[5]),
      totalEggs: parseInt(row[6]),
      avgTrayWeight: parseDouble(row[7]),
      feedConsumed: parseDouble(row[8]),
      stoneGritConsumed: parseDouble(row[9]),
      waterIntake: parseDouble(row[10]),
      automatedFCR: parseDouble(row[11]),
      layingPercentage: parseDouble(row[12]),
      previousDateKey: '',
      previousEndingBirds: 0,
    );
  }

  PoultryLog copyWith({DateTime? date, int? flockAge, int? startingBirds, int? endingBirds, int? totalEggs, double? automatedFCR, double? layingPercentage, String? previousDateKey, int? previousEndingBirds}) => PoultryLog(
    date: date ?? this.date, flockAge: flockAge ?? this.flockAge, startingBirds: startingBirds ?? this.startingBirds, mortality: mortality,
    endingBirds: endingBirds ?? this.endingBirds, trays: trays, totalEggs: totalEggs ?? this.totalEggs,
    avgTrayWeight: avgTrayWeight, feedConsumed: feedConsumed, stoneGritConsumed: stoneGritConsumed,
    waterIntake: waterIntake, automatedFCR: automatedFCR ?? this.automatedFCR, layingPercentage: layingPercentage ?? this.layingPercentage, previousDateKey: previousDateKey ?? this.previousDateKey, previousEndingBirds: previousEndingBirds ?? this.previousEndingBirds);

  factory PoultryLog.fromFirestore(Map<String, dynamic> data) {
    DateTime date = (data['date'] is Timestamp) ? (data['date'] as Timestamp).toDate() : DateTime.parse(data['dateKey'] as String);
    double d(dynamic v) => (v as num?)?.toDouble() ?? 0;
    int i(dynamic v) => (v as num?)?.toInt() ?? 0;
    // Always derive age from the configured flock start date so records created
    // before the age fix cannot continue displaying a stale/zero value.
    final calculatedAge = FarmConfig.flockAgeOn(date);
    return PoultryLog(date: date, flockAge: calculatedAge, startingBirds: i(data['startingBirds']), mortality: i(data['mortality']), endingBirds: i(data['endingBirds']), trays: d(data['trays']), totalEggs: i(data['totalEggs']), avgTrayWeight: d(data['avgTrayWeight']), feedConsumed: d(data['feedConsumed']), stoneGritConsumed: d(data['stoneGritConsumed']), waterIntake: d(data['waterIntake']), automatedFCR: d(data['automatedFCR']), layingPercentage: d(data['layingPercentage']), previousDateKey: data['previousDateKey']?.toString() ?? '', previousEndingBirds: i(data['previousEndingBirds']));
  }

  Map<String, dynamic> toFirestore() => {
    'date': Timestamp.fromDate(date), 'dateKey': DateFormat('yyyy-MM-dd').format(date), 'flockAge': flockAge,
    'startingBirds': startingBirds, 'mortality': mortality, 'endingBirds': endingBirds, 'trays': trays, 'totalEggs': totalEggs,
    'avgTrayWeight': avgTrayWeight, 'feedConsumed': feedConsumed, 'stoneGritConsumed': stoneGritConsumed, 'waterIntake': waterIntake,
    'automatedFCR': automatedFCR, 'layingPercentage': layingPercentage, 'previousDateKey': previousDateKey, 'previousEndingBirds': previousEndingBirds, 'updatedAt': FieldValue.serverTimestamp(),
  };

  List<Object?> toSheetRow() => <Object?>[
        DateFormat('yyyy-MM-dd').format(date),
        flockAge,
        startingBirds,
        mortality,
        endingBirds,
        trays,
        totalEggs,
        avgTrayWeight,
        feedConsumed,
        stoneGritConsumed,
        waterIntake,
        automatedFCR,
        layingPercentage,
      ];
}
