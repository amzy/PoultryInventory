import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/flock.dart';
import '../models/poultry_log.dart';
import 'bv300_analytics_service.dart';

class BV300MetricExport {
  final String key;
  final String title;
  final String unit;
  final String Function(PoultryLog log, int index, List<PoultryLog> logs, Flock flock) value;
  final String standard;
  final String action;

  const BV300MetricExport({
    required this.key,
    required this.title,
    required this.unit,
    required this.value,
    required this.standard,
    required this.action,
  });
}

class BV300MetricsPdfService {
  static final _date = DateFormat('dd MMM yyyy');

  static List<BV300MetricExport> metrics({required int startingBirds}) => [
    BV300MetricExport(
      key: 'hdep', title: 'HDEP (Hen-Day Egg Production)', unit: '%',
      value: (log, _, logs, flock) => _num(_laying(log, logs, startingBirds), 2),
      standard: '95.0%–98.0% (Weeks 23–35)',
      action: 'Drop of >3% within any 48-hour window.',
    ),
    BV300MetricExport(
      key: 'hhpe', title: 'HHPE (Hen-Housed Production)', unit: 'eggs/hen housed',
      value: (log, index, logs, flock) => _num(_cumulativeEggs(log, logs) / (startingBirds <= 0 ? 1 : startingBirds), 2),
      standard: '330+ eggs by Week 72',
      action: 'Deviation of >15 eggs from cumulative curve.',
    ),
    BV300MetricExport(
      key: 'fcr_mass', title: 'FCR per kg Egg Mass', unit: 'kg/kg',
      value: (log, _, __, ___) => _num(log.fcrByEggMass, 2),
      standard: '2.10–2.15',
      action: '>2.35 indicates extreme feed wastage or egg-weight tracking errors.',
    ),
    BV300MetricExport(
      key: 'water_feed', title: 'Water-to-Feed Volumetric Ratio', unit: ':1',
      value: (log, _, __, ___) => _num(log.feedConsumed > 0 ? log.waterIntake / log.feedConsumed : 0.0, 2),
      standard: '2.0:1 at 21°C',
      action: '>3.5:1 alerts to systemic heat stress or severe water-line leaks.',
    ),
    BV300MetricExport(
      key: 'egg_weight', title: 'Egg Weight', unit: 'g/egg',
      value: (log, _, __, ___) => _num(log.trays > 0 ? log.avgTrayWeight / 30.0 : 0.0, 2),
      standard: 'Week-based egg geometry range',
      action: 'Review egg size, flock age and nutrition when outside the applicable range.',
    ),
    BV300MetricExport(
      key: 'egg_mass', title: 'Daily Egg Mass per Hen', unit: 'g/hen/day',
      value: (log, _, logs, ___) {
        final double eggWeight = log.trays > 0 ? log.avgTrayWeight / 30.0 : 0.0;
        return _num(_laying(log, logs, startingBirds) * eggWeight / 100, 2);
      },
      standard: 'Week-based egg geometry range',
      action: 'Review laying rate and egg weight together when egg mass drifts.',
    ),
    BV300MetricExport(
      key: 'livability', title: 'Livability', unit: '%',
      value: (log, _, logs, flock) => _num(_aliveAt(log.date, logs, startingBirds) / (startingBirds <= 0 ? 1 : startingBirds) * 100, 2),
      standard: 'Week-based BV300 livability target where supplied',
      action: 'Investigate mortality events and flock health when below target.',
    ),
    BV300MetricExport(
      key: 'mortality', title: 'Mortality', unit: 'birds',
      value: (log, _, __, ___) => log.mortality.toString(),
      standard: 'No single universal target supplied in the matrix.',
      action: 'Investigate unusual increases immediately.',
    ),
    BV300MetricExport(
      key: 'eggs', title: 'Eggs Collected', unit: 'eggs',
      value: (log, _, __, ___) => log.totalEggs.toString(),
      standard: 'Use HDEP/HHPE and age-specific production standards for interpretation.',
      action: 'Check bird count and collection records if production changes unexpectedly.',
    ),
    BV300MetricExport(
      key: 'feed', title: 'Feed Consumed', unit: 'kg',
      value: (log, _, __, ___) => _num(log.feedConsumed, 2),
      standard: 'Used in FCR and water-to-feed calculations.',
      action: 'Review wastage, feed quality and intake when efficiency deteriorates.',
    ),
    BV300MetricExport(
      key: 'water', title: 'Water Intake', unit: 'L',
      value: (log, _, __, ___) => _num(log.waterIntake, 2),
      standard: 'Temperature-dependent water multiplier supplied in BV300 matrix.',
      action: 'Check heat stress and water-line leakage for abnormal intake.',
    ),
  ];

  static Future<void> export({
    required Flock flock,
    required List<PoultryLog> logs,
    required int startingBirds,
    required List<String> metricKeys,
  }) async {
    final selected = metrics(startingBirds: startingBirds)
        .where((m) => metricKeys.contains(m.key))
        .toList();
    if (selected.isEmpty) return;

    final ordered = [...logs]..sort((a, b) => a.date.compareTo(b.date));
    final doc = pw.Document();
    final generated = DateFormat('dd MMM yyyy HH:mm').format(DateTime.now());

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (context) => [
        pw.Text('BV300 Flock Performance Metrics', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 5),
        pw.Text('${flock.name} • ${flock.breedName.isEmpty ? 'BV300' : flock.breedName}'),
        pw.Text('Flock period: ${_date.format(flock.startDate)}${flock.endDate == null ? '' : ' – ${_date.format(flock.endDate!)}'}'),
        pw.Text('Generated: $generated'),
        pw.SizedBox(height: 16),
        ...selected.map((metric) => _metricSection(metric, ordered, flock, startingBirds)),
      ],
    ));

    final bytes = await doc.save();
    await Printing.sharePdf(bytes: Uint8List.fromList(bytes), filename: 'bv300_${_safe(flock.name)}_metrics.pdf');
  }

  static pw.Widget _metricSection(BV300MetricExport metric, List<PoultryLog> logs, Flock flock, int startingBirds) {
    final rows = logs.map((log) => [
      _date.format(log.date),
      'Week ${BV300AnalyticsService.weekFromAgeDays(BV300AnalyticsService.ageDaysForDate(log.date, flock.startDate))}',
      '${metric.value(log, 0, logs, flock)} ${metric.unit}',
    ]).toList();
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(metric.title, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 3),
      pw.Text('Expected standard: ${metric.standard}'),
      pw.Text('Drastic/action limit: ${metric.action}'),
      pw.SizedBox(height: 6),
      pw.TableHelper.fromTextArray(
        headers: const ['Date', 'Age', 'Actual'],
        data: rows,
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
        cellStyle: const pw.TextStyle(fontSize: 8),
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      ),
      pw.SizedBox(height: 16),
    ]);
  }

  static double _laying(PoultryLog log, List<PoultryLog> logs, int startingBirds) {
    final mortality = logs.where((x) => !x.date.isAfter(log.date)).fold<int>(0, (s, x) => s + x.mortality);
    final int alive = (startingBirds - mortality).clamp(0, startingBirds).toInt();
    return alive <= 0 ? 0 : log.totalEggs / alive * 100;
  }

  static int _cumulativeEggs(PoultryLog log, List<PoultryLog> logs) => logs.where((x) => !x.date.isAfter(log.date)).fold<int>(0, (s, x) => s + x.totalEggs);
  static int _aliveAt(DateTime date, List<PoultryLog> logs, int startingBirds) {
    final mortality = logs.where((x) => !x.date.isAfter(date)).fold<int>(0, (s, x) => s + x.mortality);
    return (startingBirds - mortality).clamp(0, startingBirds).toInt();
  }
  static String _num(double value, int decimals) => value.toStringAsFixed(decimals);
  static String _safe(String value) => value.replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_').replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_|_$'), '');
}
