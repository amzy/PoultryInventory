import 'package:intl/intl.dart';

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
    );
  }

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
