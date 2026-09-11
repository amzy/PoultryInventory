import '../models/poultry_log.dart';

class PoultryCalculationService {
  static const int eggsPerTray = 30;

  static String dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static DateTime normalizeDate(DateTime date) => DateTime(date.year, date.month, date.day);

  static PoultryLog calculate({
    required PoultryLog input,
    int cumulativeMortalityBefore = 0,
    int openingBirds = 0,
    DateTime? minimumDate,
  }) {
    _validateInputs(input, minimumDate: minimumDate);
    final birdsBefore = openingBirds - cumulativeMortalityBefore;
    if (birdsBefore < 0) {
      throw StateError('Cumulative mortality cannot exceed the opening flock.');
    }
    if (input.mortality > birdsBefore) {
      throw StateError('Mortality cannot exceed the currently alive birds.');
    }

    final eggs = (input.trays * eggsPerTray).round();
    final eggMassKg = input.trays * input.avgTrayWeight / 1000.0;
    final fcr = eggMassKg > 0 ? input.feedConsumed / eggMassKg : 0.0;

    return input.copyWith(
      totalEggs: eggs,
      automatedFCR: fcr,
    );
  }

  static void _validateInputs(PoultryLog input, {DateTime? minimumDate}) {
    if (input.trays < 0 || input.feedConsumed < 0 || input.avgTrayWeight < 0 ||
        input.stoneGritConsumed < 0 || input.waterIntake < 0) {
      throw StateError('Production and consumption values cannot be negative.');
    }
    if (input.mortality < 0) {
      throw StateError('Mortality cannot be negative.');
    }
    final date = normalizeDate(input.date);
    final minimumLogDate = minimumDate == null ? DateTime(2026, 4, 27) : normalizeDate(minimumDate);
    if (date.isBefore(minimumLogDate)) {
      throw StateError('Daily Log date cannot be before $minimumLogDate.');
    }
  }
}
