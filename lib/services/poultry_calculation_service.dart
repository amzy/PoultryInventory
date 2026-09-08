import '../models/poultry_log.dart';
import 'farm_config.dart';

class PoultryCalculationService {
  static const int eggsPerTray = 30;

  static String dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static DateTime normalizeDate(DateTime date) => DateTime(date.year, date.month, date.day);

  static PoultryLog calculate({
    required PoultryLog input,
    PoultryLog? previous,
  }) {
    _validateInputs(input);
    final starting = previous?.endingBirds ?? FarmConfig.defaultStartingBirds;
    if (input.mortality > starting) {
      throw StateError('Mortality cannot exceed Starting Birds.');
    }

    final ending = starting - input.mortality;
    final eggs = (input.trays * eggsPerTray).round();
    final fcr = input.trays > 0 ? input.feedConsumed / input.trays : 0.0;
    final laying = ending > 0 ? (eggs / ending) * 100 : 0.0;

    return input.copyWith(
      flockAge: FarmConfig.flockAgeOn(input.date),
      startingBirds: starting,
      endingBirds: ending,
      totalEggs: eggs,
      automatedFCR: fcr,
      layingPercentage: laying,
      previousDateKey: previous == null ? 'datetime_bootstrap' : dateKey(previous.date),
      previousEndingBirds: previous?.endingBirds ?? 0,
    );
  }

  static PoultryLog recalculateFromPrevious({
    required PoultryLog input,
    required PoultryLog previous,
  }) => calculate(input: input, previous: previous);

  static void _validateInputs(PoultryLog input) {
    if (input.trays < 0 || input.feedConsumed < 0 || input.avgTrayWeight < 0 ||
        input.stoneGritConsumed < 0 || input.waterIntake < 0) {
      throw StateError('Production and consumption values cannot be negative.');
    }
    if (input.mortality < 0) {
      throw StateError('Mortality cannot be negative.');
    }
    final date = normalizeDate(input.date);
    final minimumLogDate = DateTime(2026, 4, 27);
    if (date.isBefore(minimumLogDate)) {
      throw StateError('Daily Log date cannot be before 27 Apr 2026.');
    }
  }
}
