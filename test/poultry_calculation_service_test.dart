import 'package:flutter_test/flutter_test.dart';
import 'package:poultry_inventory/models/poultry_log.dart';
import 'package:poultry_inventory/services/farm_config.dart';
import 'package:poultry_inventory/services/poultry_calculation_service.dart';

PoultryLog log({
  required String date,
  int mortality = 0,
  double trays = 28,
  double feed = 650,
}) {
  final d = DateTime.parse(date);
  return PoultryLog(
    date: d,
    startingBirds: 0,
    mortality: mortality,
    endingBirds: 0,
    trays: trays,
    totalEggs: 0,
    avgTrayWeight: 1237,
    feedConsumed: feed,
    stoneGritConsumed: 25,
    waterIntake: 1100,
    automatedFCR: 0,
    layingPercentage: 0,
  );
}

void main() {
  test('uses default 5200 starting birds for the first Daily Log', () {
    final result = PoultryCalculationService.calculate(
      input: log(date: '2026-04-27', mortality: 2, trays: 10, feed: 100),
    );

    expect(result.startingBirds, 5200);
    expect(result.endingBirds, 5198);
    expect(result.previousDateKey, 'datetime_bootstrap');
    expect(result.previousEndingBirds, 0);
  });

  test('calculates all Daily Log derived values from previous ending birds', () {
    final previous = PoultryCalculationService.calculate(
      input: log(date: '2026-09-05', mortality: 2),
    );
    final result = PoultryCalculationService.calculate(
      input: log(date: '2026-09-06', mortality: 3, trays: 30, feed: 45),
      previous: previous,
    );

    expect(previous.endingBirds, 5198);
    expect(result.startingBirds, 5198);
    expect(result.endingBirds, 5195);
    expect(result.totalEggs, 900);
    expect(result.automatedFCR, 1.5);
    expect(result.layingPercentage, closeTo(17.32435, 0.00001));
    expect(result.previousDateKey, '2026-09-05');
    expect(result.previousEndingBirds, 5198);
  });

  test('changing previous-day mortality propagates to every future Daily Log', () {
    final day1Old = PoultryCalculationService.calculate(
      input: log(date: '2026-09-05', mortality: 2),
    );
    final day2Old = PoultryCalculationService.calculate(
      input: log(date: '2026-09-06', mortality: 3),
      previous: day1Old,
    );
    final day3Old = PoultryCalculationService.calculate(
      input: log(date: '2026-09-07', mortality: 1),
      previous: day2Old,
    );

    // Edit Sep 5: mortality 2 -> 5.
    final day1Updated = PoultryCalculationService.calculate(
      input: log(date: '2026-09-05', mortality: 5),
    );
    final day2Updated = PoultryCalculationService.recalculateFromPrevious(
      input: day2Old,
      previous: day1Updated,
    );
    final day3Updated = PoultryCalculationService.recalculateFromPrevious(
      input: day3Old,
      previous: day2Updated,
    );

    expect(day1Updated.endingBirds, 5195);
    expect(day2Updated.startingBirds, 5195);
    expect(day2Updated.endingBirds, 5192);
    expect(day3Updated.startingBirds, 5192);
    expect(day3Updated.endingBirds, 5191);
  });

  test('rejects mortality greater than starting birds', () {
    final previous = PoultryCalculationService.calculate(
      input: log(date: '2026-09-05', mortality: 5190),
    );
    final input = log(date: '2026-09-06', mortality: 11);

    expect(
      () => PoultryCalculationService.calculate(input: input, previous: previous),
      throwsStateError,
    );
  });

  test('flock age is always calculated from the real flock start date', () {
    expect(FarmConfig.flockAgeOn(DateTime(2026, 4, 26)), 0);
    expect(FarmConfig.flockAgeOn(DateTime(2026, 4, 27)), 1);
    expect(FarmConfig.flockAgeOn(DateTime(2026, 9, 5)), 132);
    expect(FarmConfig.flockAgeOn(DateTime(2026, 9, 8)), 135);
    expect(FarmConfig.flockAgeOn(DateTime(2026, 9, 9)), 136);
  });

  test('PoultryLog exposes flock age as a calculated property, not persisted input', () {
    final value = log(date: '2026-09-08');
    expect(value.flockAge, 135);
    expect(value.toFirestore().containsKey('flockAge'), isFalse);
  });

  test('rejects Daily Logs before 27 Apr 2026', () {
    final input = log(date: '2026-04-26');
    expect(
      () => PoultryCalculationService.calculate(input: input),
      throwsStateError,
    );
  });
}
