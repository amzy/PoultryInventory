/// Farm-level configuration used for deterministic poultry calculations.
///
/// The current farm records establish 2026-04-26 as the flock start date:
/// 2026-04-27 is the first allowed Daily Log date. Keeping the date in one place
/// prevents the Daily Log screen from falling back to today's date (age 0).
class FarmConfig {
  static final DateTime flockStartDate = DateTime(2026, 4, 26);
  static const int defaultStartingBirds = 5200;

  static int flockAgeOn(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final start = DateTime(
      flockStartDate.year,
      flockStartDate.month,
      flockStartDate.day,
    );
    return day.difference(start).inDays;
  }
}
