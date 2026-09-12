import 'dart:convert';
import 'package:flutter/services.dart';

class BV300BenchmarkRepository {
  BV300BenchmarkRepository._();
  static final instance = BV300BenchmarkRepository._();

  Map<String, dynamic>? _data;

  Future<void> load() async {
    if (_data != null) return;
    final raw = await rootBundle.loadString('assets/bv300_lifecycle_benchmarks.json');
    _data = jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> dayBenchmark({required int ageDays}) async {
    await load();
    final rows = (_data!['weekly_performance_matrix'] as List).cast<Map<String, dynamic>>();
    final week = (ageDays ~/ 7) + 1;
    final row = rows.firstWhere((e) => (e['week_number'] as num).toInt() == week, orElse: () => rows.last);
    return Map<String, dynamic>.from(row);
  }

  Future<List<Map<String, dynamic>>> vaccinationSchedule() async {
    await load();
    return (_data!['vaccination_schedule'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> breedMetadata() async {
    await load();
    return Map<String, dynamic>.from(_data!['breed_metadata'] as Map);
  }
}
