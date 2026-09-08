import 'package:flutter_test/flutter_test.dart';
import 'package:poultry_inventory/models/poultry_log.dart';
import 'package:poultry_inventory/services/poultry_calculation_service.dart';

PoultryLog log({
  required String date,
  required int endingBirds,
  int mortality = 0,
  double trays = 28,
  double feed = 650,
  int flockAge = 130,
}) {
  final d = DateTime.parse(date);
  final starting = endingBirds + mortality;
  return PoultryLog(
    date: d,
    flockAge: flockAge,
    startingBirds: starting,
    mortality: mortality,
    endingBirds: endingBirds,
    trays: trays,
    totalEggs: (trays * 30).round(),
    avgTrayWeight: 1237,
    feedConsumed: feed,
    stoneGritConsumed: 25,
    waterIntake: 1100,
    automatedFCR: trays > 0 ? feed / trays : 0,
    layingPercentage: endingBirds > 0 ? ((trays * 30).round() / endingBirds) * 100 : 0,
  );
}

void main() {
  test('calculates all Daily Log derived values', () {
    final previous = log(date: '2026-09-05', endingBirds: 5198);
    final input = log(
      date: '2026-09-06',
      endingBirds: 0,
      mortality: 3,
      trays: 30,
      feed: 45,
      flockAge: 131,
    );

    final result = PoultryCalculationService.calculate(
      input: input,
      previous: previous,
    );

    expect(result.startingBirds, 5198);
    expect(result.endingBirds, 5195);
    expect(result.totalEggs, 900);
    expect(result.automatedFCR, 1.5);
    expect(result.layingPercentage, closeTo(17.32435, 0.00001));
    expect(result.previousDateKey, '2026-09-05');
    expect(result.previousEndingBirds, 5198);
  });

  test('rejects mortality greater than starting birds', () {
    final previous = log(date: '2026-09-05', endingBirds: 10);
    final input = log(
      date: '2026-09-06',
      endingBirds: 0,
      mortality: 11,
    );

    expect(
      () => PoultryCalculationService.calculate(input: input, previous: previous),
      throwsStateError,
    );
  });

  test('recalculates a future log from the newly inserted previous log', () {
    final previous = log(date: '2026-09-05', endingBirds: 5198);
    final backdated = PoultryCalculationService.calculate(
      input: log(date: '2026-09-06', endingBirds: 0, mortality: 5, flockAge: 131),
      previous: previous,
    );
    final future = PoultryCalculationService.recalculateFromPrevious(
      input: log(date: '2026-09-07', endingBirds: 0, mortality: 2, flockAge: 132),
      previous: backdated,
    );

    expect(backdated.endingBirds, 5193);
    expect(future.startingBirds, 5193);
    expect(future.endingBirds, 5191);
    expect(future.previousDateKey, '2026-09-06');
    expect(future.previousEndingBirds, 5193);
  });
}
