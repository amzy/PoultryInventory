import 'package:flutter_test/flutter_test.dart';
import 'package:poultry_inventory/models/poultry_log.dart';
import 'package:poultry_inventory/services/farm_config.dart';
import 'package:poultry_inventory/services/poultry_calculation_service.dart';

PoultryLog makeLog({
  required String date,
  int mortality = 0,
  double trays = 28,
  double feed = 650,
  double avgTrayWeight = 1237,
  double grit = 25,
  double water = 1100,
}) {
  return PoultryLog(
    date: DateTime.parse(date),
    mortality: mortality,
    trays: trays,
    totalEggs: 0,
    avgTrayWeight: avgTrayWeight,
    feedConsumed: feed,
    stoneGritConsumed: grit,
    waterIntake: water,
    automatedFCR: 0,
  );
}

void main() {
  group('PoultryCalculationService', () {
    test('calculates eggs and FCR from Daily Log observations', () {
      final result = PoultryCalculationService.calculate(
        input: makeLog(date: '2026-09-06', trays: 30, feed: 45),
      );

      expect(result.totalEggs, 900);
      expect(result.automatedFCR, 1.5);
    });

    test('calculates zero FCR when no trays are recorded', () {
      final result = PoultryCalculationService.calculate(
        input: makeLog(date: '2026-09-06', trays: 0, feed: 45),
      );

      expect(result.totalEggs, 0);
      expect(result.automatedFCR, 0);
    });

    test('validates mortality against currently alive birds', () {
      expect(
        () => PoultryCalculationService.calculate(
          input: makeLog(date: '2026-09-06', mortality: 11),
          cumulativeMortalityBefore: 5190,
          openingBirds: 5200,
        ),
        throwsStateError,
      );
    });

    test('allows mortality up to the currently alive bird count', () {
      final result = PoultryCalculationService.calculate(
        input: makeLog(date: '2026-09-06', mortality: 10),
        cumulativeMortalityBefore: 5190,
        openingBirds: 5200,
      );

      expect(result.mortality, 10);
    });

    test('rejects mortality when cumulative mortality already exceeds opening flock', () {
      expect(
        () => PoultryCalculationService.calculate(
          input: makeLog(date: '2026-09-06'),
          cumulativeMortalityBefore: 5201,
          openingBirds: 5200,
        ),
        throwsStateError,
      );
    });

    test('rejects negative Daily Log values', () {
      expect(
        () => PoultryCalculationService.calculate(
          input: makeLog(date: '2026-09-06', trays: -1),
        ),
        throwsStateError,
      );
      expect(
        () => PoultryCalculationService.calculate(
          input: makeLog(date: '2026-09-06', mortality: -1),
        ),
        throwsStateError,
      );
    });

    test('rejects Daily Logs before 27 Apr 2026', () {
      expect(
        () => PoultryCalculationService.calculate(
          input: makeLog(date: '2026-04-26'),
        ),
        throwsStateError,
      );
    });
  });

  group('FarmConfig', () {
    test('has the expected default flock configuration', () {
      final config = FarmConfig.defaults;

      expect(config.startingBirds, 5200);
      expect(config.flockStartDate, DateTime(2026, 4, 26));
      expect(config.accounts, containsAll(<String>['Amzad Khan', 'Sarfaraj Khan']));
      expect(config.feedItems, containsAll(<String>['LCC (Starter)', 'LGC (Grower)', 'LCDP (Developer)', 'LCLP1 (Phase 1)', 'Finisher']));
    });

    test('calculates flock age from the configured start date', () {
      final start = DateTime(2026, 5, 1);

      expect(FarmConfig.flockAgeOnDate(start, startDate: start), 0);
      expect(
        FarmConfig.flockAgeOnDate(DateTime(2026, 5, 2), startDate: start),
        1,
      );
      expect(
        FarmConfig.flockAgeOnDate(DateTime(2026, 5, 10), startDate: start),
        9,
      );
    });

    test('loads a legacy farm configuration without feed items', () {
      final config = FarmConfig.fromMap({
        'initialized': true,
        'openingBirds': 5200,
        'firstLogDateKey': '2026-04-27',
        'flockStartDate': DateTime(2026, 4, 26),
        'breedName': 'Layer',
        'accounts': ['Amzad Khan', 'Sarfaraj Khan'],
      });
      expect(config.startingBirds, 5200);
      expect(config.feedItems, contains('LCC (Starter)'));
    });

    test('serializes the configured flock start date and accounts', () {
      final config = FarmConfig(
        flockStartDate: DateTime(2026, 5, 10),
        startingBirds: 6000,
        breedName: 'Layer',
        accounts: const ['Amzad Khan', 'Farm Account'],
      );

      final data = config.toFirestore();

      expect(data['openingBirds'], 6000);
      expect(data['breedName'], 'Layer');
      expect(data['accounts'], ['Amzad Khan', 'Farm Account']);
      expect(data['firstLogDateKey'], '2026-05-11');
      expect(data['feedItems'], contains('Finisher'));
    });
  });

  group('PoultryLog persistence', () {
    test('does not persist derived bird counts or laying percentage', () {
      final log = makeLog(date: '2026-09-08');
      final data = log.toFirestore();

      expect(data, isNot(contains('startingBirds')));
      expect(data, isNot(contains('endingBirds')));
      expect(data, isNot(contains('layingPercentage')));
      expect(data, containsPair('mortality', 0));
      expect(data, containsPair('trays', 28.0));
    });

    test('reads a legacy Daily Log that contains removed fields', () {
      final legacy = <String, dynamic>{
        'date': DateTime(2026, 9, 8),
        'dateKey': '2026-09-08',
        'startingBirds': 5200,
        'mortality': 12,
        'endingBirds': 5188,
        'trays': 30,
        'totalEggs': 900,
        'avgTrayWeight': 1300,
        'feedConsumed': 600,
        'stoneGritConsumed': 20,
        'waterIntake': 1000,
        'automatedFCR': 2,
        'layingPercentage': 17.3,
      };
      final log = PoultryLog.fromFirestore(legacy);
      expect(log.mortality, 12);
      expect(log.totalEggs, 900);
      expect(log.automatedFCR, 2);
    });

    test('total eggs and FCR are calculated fields', () {
      final input = makeLog(date: '2026-09-08', trays: 12, feed: 60);
      final calculated = PoultryCalculationService.calculate(input: input);

      expect(calculated.totalEggs, 360);
      expect(calculated.automatedFCR, 5);
      expect(calculated.toFirestore()['totalEggs'], 360);
      expect(calculated.toFirestore()['automatedFCR'], 5);
    });

    test('flock age uses the default configured flock start date', () {
      expect(makeLog(date: '2026-04-26').flockAge, 0);
      expect(makeLog(date: '2026-04-27').flockAge, 1);
      expect(makeLog(date: '2026-09-05').flockAge, 132);
      expect(makeLog(date: '2026-09-08').flockAge, 135);
      expect(makeLog(date: '2026-09-09').flockAge, 136);
    });
  });
}
