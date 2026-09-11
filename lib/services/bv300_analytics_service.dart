import '../models/poultry_log.dart';

/// BV300 analytical standards supplied for the application.
/// Standards are resolved by flock age in weeks; the daily log remains the
/// source of actual observations.
class BV300StandardRange {
  final int startWeek;
  final int endWeek;
  final double? layingMin;
  final double? layingMax;
  final double? livabilityMin;
  final double? eggWeightMin;
  final double? eggWeightMax;
  final double? eggMassMin;
  final double? eggMassMax;
  final double? bodyWeightMin;
  final double? bodyWeightMax;
  final double? cumulativeFeedKg;
  final String phase;

  const BV300StandardRange({
    required this.startWeek,
    required this.endWeek,
    required this.phase,
    this.layingMin,
    this.layingMax,
    this.livabilityMin,
    this.eggWeightMin,
    this.eggWeightMax,
    this.eggMassMin,
    this.eggMassMax,
    this.bodyWeightMin,
    this.bodyWeightMax,
    this.cumulativeFeedKg,
  });

  bool contains(int week) => week >= startWeek && week <= endWeek;
}

class BV300LightingStandard {
  final int startWeek;
  final int endWeek;
  final double lightHours;
  final double luxMin;
  final double luxMax;
  final String objective;

  const BV300LightingStandard({
    required this.startWeek,
    required this.endWeek,
    required this.lightHours,
    required this.luxMin,
    required this.luxMax,
    required this.objective,
  });

  bool contains(int week) => week >= startWeek && week <= endWeek;
}

class BV300EggGeometryStandard {
  final int startWeek;
  final int endWeek;
  final double eggWeightMin;
  final double eggWeightMax;
  final double eggMassMin;
  final double eggMassMax;
  final String ratioTarget;
  final double shellMin;
  final double shellMax;

  const BV300EggGeometryStandard({
    required this.startWeek,
    required this.endWeek,
    required this.eggWeightMin,
    required this.eggWeightMax,
    required this.eggMassMin,
    required this.eggMassMax,
    required this.ratioTarget,
    required this.shellMin,
    required this.shellMax,
  });

  bool contains(int week) => week >= startWeek && week <= endWeek;
}

class BV300TemperatureStandard {
  final double minTemp;
  final double maxTemp;
  final double feedAdjustmentMin;
  final double feedAdjustmentMax;
  final double waterMultiplierMin;
  final double waterMultiplierMax;
  final String energyShift;
  final String ventilation;

  const BV300TemperatureStandard({
    required this.minTemp,
    required this.maxTemp,
    required this.feedAdjustmentMin,
    required this.feedAdjustmentMax,
    required this.waterMultiplierMin,
    required this.waterMultiplierMax,
    required this.energyShift,
    required this.ventilation,
  });

  bool contains(double temp) => temp >= minTemp && temp <= maxTemp;
}

class BV300EconomicStandard {
  final String metric;
  final String formulation;
  final double? min;
  final double? max;
  final String target;
  final String drasticAction;

  const BV300EconomicStandard({
    required this.metric,
    required this.formulation,
    this.min,
    this.max,
    required this.target,
    required this.drasticAction,
  });
}

class BV300MetricIndicator {
  final String metric;
  final double actual;
  final double? min;
  final double? max;
  final String unit;
  final String status;
  final String message;

  const BV300MetricIndicator({
    required this.metric,
    required this.actual,
    required this.min,
    required this.max,
    required this.unit,
    required this.status,
    required this.message,
  });

  bool get hasStandard => min != null || max != null;
}

class BV300AnalyticsSnapshot {
  final int ageDays;
  final int ageWeek;
  final String phase;
  final List<BV300MetricIndicator> indicators;
  final List<String> suggestions;

  const BV300AnalyticsSnapshot({
    required this.ageDays,
    required this.ageWeek,
    required this.phase,
    required this.indicators,
    required this.suggestions,
  });

  bool get hasWarnings => indicators.any((i) => i.status == 'warning');
  bool get hasCritical => indicators.any((i) => i.status == 'critical');
}

class BV300AnalyticsService {
  static const standards = <BV300StandardRange>[
    BV300StandardRange(startWeek: 4, endWeek: 4, bodyWeightMin: 260, bodyWeightMax: 280, cumulativeFeedKg: .50, livabilityMin: 99, phase: 'Brooding'),
    BV300StandardRange(startWeek: 8, endWeek: 8, bodyWeightMin: 580, bodyWeightMax: 620, cumulativeFeedKg: 1.60, livabilityMin: 98.5, phase: 'Brooding / rearing'),
    BV300StandardRange(startWeek: 12, endWeek: 12, bodyWeightMin: 900, bodyWeightMax: 940, cumulativeFeedKg: 3.10, livabilityMin: 98, phase: 'Grower'),
    BV300StandardRange(startWeek: 16, endWeek: 16, bodyWeightMin: 1180, bodyWeightMax: 1220, cumulativeFeedKg: 5.00, livabilityMin: 97.5, phase: 'Developer'),
    BV300StandardRange(startWeek: 18, endWeek: 18, bodyWeightMin: 1280, bodyWeightMax: 1350, cumulativeFeedKg: 6.20, livabilityMin: 97, layingMin: 1, layingMax: 5, phase: 'Point of lay'),
    BV300StandardRange(startWeek: 21, endWeek: 23, bodyWeightMin: 1450, bodyWeightMax: 1500, cumulativeFeedKg: 8.50, livabilityMin: 96.5, layingMin: 92, layingMax: 97, phase: 'Climbing to peak'),
    BV300StandardRange(startWeek: 24, endWeek: 40, bodyWeightMin: 1550, bodyWeightMax: 1650, livabilityMin: 95.5, layingMin: 95, layingMax: 98, eggMassMin: 50.5, eggMassMax: 53.8, phase: 'Peak'),
    BV300StandardRange(startWeek: 41, endWeek: 60, bodyWeightMin: 1650, bodyWeightMax: 1700, livabilityMin: 94.5, layingMin: 88, layingMax: 92, phase: 'Post-peak'),
    BV300StandardRange(startWeek: 61, endWeek: 71, bodyWeightMin: 1650, bodyWeightMax: 1700, livabilityMin: 94.0, layingMin: 78, layingMax: 82, eggMassMin: 46.5, eggMassMax: 48.5, phase: 'Late cycle'),
    BV300StandardRange(startWeek: 72, endWeek: 999, bodyWeightMin: 1700, bodyWeightMax: 1750, livabilityMin: 93, layingMin: 78, layingMax: 82, eggMassMin: 46.5, eggMassMax: 48.5, cumulativeFeedKg: 41.25, phase: 'End of flock'),
  ];

  static const eggGeometry = <BV300EggGeometryStandard>[
    BV300EggGeometryStandard(startWeek: 18, endWeek: 19, eggWeightMin: 42, eggWeightMax: 44, eggMassMin: .4, eggMassMax: 2.2, ratioTarget: 'Lower yolk ratio (~24%)', shellMin: .38, shellMax: .40),
    BV300EggGeometryStandard(startWeek: 20, endWeek: 22, eggWeightMin: 48, eggWeightMax: 51, eggMassMin: 24, eggMassMax: 43, ratioTarget: 'Normalizing', shellMin: .38, shellMax: .40),
    BV300EggGeometryStandard(startWeek: 23, endWeek: 30, eggWeightMin: 54, eggWeightMax: 56.5, eggMassMin: 50.5, eggMassMax: 53.8, ratioTarget: 'Optimum commercial profile', shellMin: .36, shellMax: .38),
    BV300EggGeometryStandard(startWeek: 31, endWeek: 40, eggWeightMin: 57, eggWeightMax: 59.5, eggMassMin: 52.5, eggMassMax: 53.5, ratioTarget: 'Stabilised', shellMin: .35, shellMax: .37),
    BV300EggGeometryStandard(startWeek: 41, endWeek: 50, eggWeightMin: 60, eggWeightMax: 61.5, eggMassMin: 51, eggMassMax: 52, ratioTarget: 'Increasing yolk size', shellMin: .34, shellMax: .36),
    BV300EggGeometryStandard(startWeek: 51, endWeek: 60, eggWeightMin: 61.8, eggWeightMax: 62.5, eggMassMin: 49.5, eggMassMax: 50.5, ratioTarget: 'Higher lipid/yolk ratio', shellMin: .33, shellMax: .35),
    BV300EggGeometryStandard(startWeek: 61, endWeek: 999, eggWeightMin: 63, eggWeightMax: 64, eggMassMin: 46.5, eggMassMax: 48.5, ratioTarget: 'Maximum volume (~30% yolk)', shellMin: .32, shellMax: .34),
  ];

  static const lighting = <BV300LightingStandard>[
    BV300LightingStandard(startWeek: 1, endWeek: 1, lightHours: 22.0, luxMin: 20, luxMax: 40, objective: 'Chick access to feed and water'),
    BV300LightingStandard(startWeek: 2, endWeek: 2, lightHours: 18, luxMin: 15, luxMax: 20, objective: 'Dark rest and immune development'),
    BV300LightingStandard(startWeek: 3, endWeek: 3, lightHours: 15, luxMin: 10, luxMax: 15, objective: 'Step-down phase'),
    BV300LightingStandard(startWeek: 4, endWeek: 14, lightHours: 11.5, luxMin: 5, luxMax: 10, objective: 'Keep light constant or decreasing during rearing'),
    BV300LightingStandard(startWeek: 15, endWeek: 16, lightHours: 12, luxMin: 5, luxMax: 10, objective: 'Maintenance before stimulation'),
    BV300LightingStandard(startWeek: 17, endWeek: 17, lightHours: 13, luxMin: 15, luxMax: 20, objective: 'First stimulation when body weight target is met'),
    BV300LightingStandard(startWeek: 18, endWeek: 18, lightHours: 14, luxMin: 20, luxMax: 30, objective: 'Ovarian development stimulation'),
    BV300LightingStandard(startWeek: 19, endWeek: 19, lightHours: 14.5, luxMin: 20, luxMax: 40, objective: 'Step up as first eggs appear'),
    BV300LightingStandard(startWeek: 20, endWeek: 20, lightHours: 15, luxMin: 20, luxMax: 40, objective: 'Step up'),
    BV300LightingStandard(startWeek: 21, endWeek: 23, lightHours: 15.5, luxMin: 20, luxMax: 40, objective: 'Final step up'),
    BV300LightingStandard(startWeek: 24, endWeek: 999, lightHours: 16, luxMin: 30, luxMax: 40, objective: 'Peak and post-peak support'),
  ];

  static const temperature = <BV300TemperatureStandard>[
    BV300TemperatureStandard(minTemp: -100, maxTemp: 15.999, feedAdjustmentMin: 5, feedAdjustmentMax: 10, waterMultiplierMin: .8, waterMultiplierMax: .8, energyShift: 'Increase ME by 50 kcal/kg', ventilation: 'Minimum cycle for moisture control'),
    BV300TemperatureStandard(minTemp: 16, maxTemp: 20, feedAdjustmentMin: 2, feedAdjustmentMax: 4, waterMultiplierMin: .9, waterMultiplierMax: .9, energyShift: 'Standard formulation', ventilation: 'Standard baseline'),
    BV300TemperatureStandard(minTemp: 21, maxTemp: 25, feedAdjustmentMin: 0, feedAdjustmentMax: 0, waterMultiplierMin: 1, waterMultiplierMax: 1, energyShift: 'Standard formulation', ventilation: 'Normal regulation'),
    BV300TemperatureStandard(minTemp: 26, maxTemp: 29, feedAdjustmentMin: -6, feedAdjustmentMax: -4, waterMultiplierMin: 1.2, waterMultiplierMax: 1.4, energyShift: 'Concentrate amino acids', ventilation: 'Increased air velocity'),
    BV300TemperatureStandard(minTemp: 30, maxTemp: 32, feedAdjustmentMin: -15, feedAdjustmentMax: -10, waterMultiplierMin: 1.5, waterMultiplierMax: 2, energyShift: 'High density / low heat increment', ventilation: 'Pad cooling active'),
    BV300TemperatureStandard(minTemp: 33, maxTemp: 35, feedAdjustmentMin: -25, feedAdjustmentMax: -20, waterMultiplierMin: 2.5, waterMultiplierMax: 3, energyShift: 'Critical adjustment phase', ventilation: 'Maximum tunnel ventilation'),
    BV300TemperatureStandard(minTemp: 36, maxTemp: 60, feedAdjustmentMin: -35, feedAdjustmentMax: -35, waterMultiplierMin: 3.5, waterMultiplierMax: 99, energyShift: 'Survival mode / electrolytes via water', ventilation: 'Emergency cooling / foggers'),
  ];

  static const economicEfficiency = <BV300EconomicStandard>[
    BV300EconomicStandard(
      metric: 'HDEP',
      formulation: 'Total eggs collected daily ÷ total live birds kept that day × 100',
      min: 95.0,
      max: 98.0,
      target: '95.0–98.0% (Weeks 23–35)',
      drasticAction: 'Drop of >3% within any 48-hour window.',
    ),
    BV300EconomicStandard(
      metric: 'HHPE',
      formulation: 'Cumulative eggs produced to date ÷ original number of birds housed at Day 0',
      min: 330.0,
      target: '330+ eggs by Week 72',
      drasticAction: 'Deviation of >15 eggs from the cumulative curve. The supplied matrix does not include the intermediate weekly cumulative curve.',
    ),
    BV300EconomicStandard(
      metric: 'FCR per kg Egg Mass',
      formulation: 'Total feed consumed (kg) ÷ total mass of collected eggs (kg)',
      min: 2.10,
      max: 2.15,
      target: '2.10–2.15 kg feed/kg egg mass',
      drasticAction: '>2.35 (indicates extreme feed wastage or egg weight tracking errors).',
    ),
    BV300EconomicStandard(
      metric: 'Water-to-Feed Ratio',
      formulation: 'Daily liters of water consumed ÷ daily kilograms of feed consumed',
      min: 2.0,
      max: 2.0,
      target: '2.0:1 at 21°C',
      drasticAction: '>3.5:1 (alerts to systemic heat stress or severe water line leaks).',
    ),
  ];

  static BV300EconomicStandard? economicStandardFor(String metric) {
    for (final standard in economicEfficiency) {
      if (standard.metric == metric) return standard;
    }
    return null;
  }

  static int weekFromAgeDays(int ageDays) => (ageDays ~/ 7) + 1;

  static int ageDaysForDate(DateTime date, DateTime startDate) {
    final d = DateTime(date.year, date.month, date.day);
    final s = DateTime(startDate.year, startDate.month, startDate.day);
    final days = d.difference(s).inDays;
    return days.clamp(0, 99999).toInt();
  }

  static BV300StandardRange? standardForWeek(int week) {
    for (final standard in standards) {
      if (standard.contains(week)) return standard;
    }
    return null;
  }

  static BV300EggGeometryStandard? eggGeometryForWeek(int week) {
    for (final standard in eggGeometry) {
      if (standard.contains(week)) return standard;
    }
    return null;
  }

  static BV300LightingStandard? lightingForWeek(int week) {
    for (final standard in lighting) {
      if (standard.contains(week)) return standard;
    }
    return null;
  }

  static BV300TemperatureStandard? temperatureFor(double celsius) {
    for (final standard in temperature) {
      if (standard.contains(celsius)) return standard;
    }
    return null;
  }

  static BV300AnalyticsSnapshot evaluate({required int ageDays, required PoultryLog? latestLog, required double livability, required double layingPercentage, double? cumulativeEggs, int? originalBirdsHoused}) {
    final week = weekFromAgeDays(ageDays);
    final standard = standardForWeek(week);
    if (standard == null) {
      return BV300AnalyticsSnapshot(ageDays: ageDays, ageWeek: week, phase: 'No mapped standard', indicators: const [], suggestions: const ['No BV300 standard is mapped to this age yet.']);
    }
    if (latestLog == null) {
      return BV300AnalyticsSnapshot(ageDays: ageDays, ageWeek: week, phase: standard.phase, indicators: const [], suggestions: ['Add today\'s daily log to compare the flock against the Week $week standards.']);
    }

    final geometry = eggGeometryForWeek(week);
    final indicators = <BV300MetricIndicator>[];
    void add(String metric, double actual, double? min, double? max, String unit) {
      if (min == null && max == null) return;
      final below = min != null && actual < min;
      final above = max != null && actual > max;
      final nearLower = min != null && actual >= min && ((actual - min) / (min.abs() < 0.0001 ? 1 : min.abs())) <= .05;
      final nearUpper = max != null && actual <= max && ((max - actual) / (max.abs() < 0.0001 ? 1 : max.abs())) <= .05;
      final status = below || above ? 'critical' : (nearLower || nearUpper ? 'warning' : 'normal');
      final message = below
          ? '$metric is ${min! - actual} $unit below the Week $week standard.'
          : above
              ? '$metric is ${actual - max!} $unit above the Week $week standard.'
              : status == 'warning'
                  ? '$metric is within the standard but close to its limit for Week $week.'
                  : '$metric is within the Week $week standard.';
      indicators.add(BV300MetricIndicator(metric: metric, actual: actual, min: min, max: max, unit: unit, status: status, message: message));
    }

    // HDEP is the same hen-day production calculation supplied by the economic matrix.
    // The provider calculates it from today's eggs and live birds for the selected day.
    final hdepMin = week >= 23 && week <= 35 ? 95.0 : null;
    final hdepMax = week >= 23 && week <= 35 ? 98.0 : null;
    add('HDEP', layingPercentage, hdepMin, hdepMax, '%');
    if (week >= 72 && cumulativeEggs != null && originalBirdsHoused != null && originalBirdsHoused > 0) {
      final hhpe = cumulativeEggs / originalBirdsHoused;
      add('HHPE', hhpe, 330.0, null, 'eggs/hen housed');
    }
    add('Laying', layingPercentage, standard.layingMin, standard.layingMax, '%');

    final double eggWeight = latestLog.trays > 0 ? latestLog.avgTrayWeight / 30.0 : 0.0;
    add('Egg weight', eggWeight, geometry?.eggWeightMin, geometry?.eggWeightMax, 'g');
    final dailyEggMassPerHen = layingPercentage * eggWeight / 100;
    add('Egg mass', dailyEggMassPerHen, geometry?.eggMassMin, geometry?.eggMassMax, 'g/hen/day');
    add('FCR / egg mass', latestLog.fcrByEggMass, 2.10, 2.15, 'kg/kg');
    if (latestLog.feedConsumed > 0) {
      final waterFeedRatio = latestLog.waterIntake / latestLog.feedConsumed;
      // The supplied target is specifically 2.0:1 at 21°C. Because this is a
      // target ratio rather than a supplied acceptable range, use the stated
      // >3.5:1 drastic-action limit separately. Temperature is not inferred.
      final status = waterFeedRatio > 3.5
          ? 'critical'
          : waterFeedRatio > 2.0
              ? 'warning'
              : 'normal';
      final message = waterFeedRatio > 3.5
          ? 'Water-to-Feed Ratio is above the 3.5:1 drastic action limit.'
          : waterFeedRatio > 2.0
              ? 'Water-to-Feed Ratio is above the 2.0:1 target at 21°C.'
              : 'Water-to-Feed Ratio is at or below the 2.0:1 target at 21°C.';
      indicators.add(BV300MetricIndicator(metric: 'Water-to-Feed Ratio', actual: waterFeedRatio, min: 2.0, max: null, unit: ':1', status: status, message: message));
    }
    add('Livability', livability, standard.livabilityMin, null, '%');

    final suggestions = <String>[];
    if (standard.layingMin != null) suggestions.add('At Week $week (${standard.phase}), target hen-day production is ${standard.layingMin!.toStringAsFixed(0)}–${standard.layingMax!.toStringAsFixed(0)}%.');
    final light = lightingForWeek(week);
    if (light != null) suggestions.add('Lighting target: ${light.lightHours.toStringAsFixed(light.lightHours % 1 == 0 ? 0 : 1)} hours/day and ${light.luxMin.toStringAsFixed(0)}–${light.luxMax.toStringAsFixed(0)} lux. ${light.objective}.');
    if (latestLog.fcrByEggMass > 2.15) suggestions.add('FCR is above the supplied 2.10–2.15 kg/kg egg-mass target. Review feed wastage, feed quality and flock performance before changing formulation.');
    if (standard.layingMin != null && standard.layingMax != null && latestLog.totalEggs > 0) suggestions.add('Use today\'s laying percentage and egg mass together; do not judge production from egg count alone.');
    return BV300AnalyticsSnapshot(ageDays: ageDays, ageWeek: week, phase: standard.phase, indicators: indicators, suggestions: suggestions);
  }
}
