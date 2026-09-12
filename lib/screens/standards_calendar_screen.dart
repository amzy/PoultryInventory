import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/poultry_provider.dart';
import '../services/bv300_benchmark_repository.dart';
import '../services/farm_config.dart';
import '../widgets/app_shell.dart';

class StandardsCalendarScreen extends StatefulWidget {
  final bool embedded;
  const StandardsCalendarScreen({super.key, this.embedded = false});
  @override State<StandardsCalendarScreen> createState() => _StandardsCalendarScreenState();
}

class _StandardsCalendarScreenState extends State<StandardsCalendarScreen> {
  DateTime? _selected;
  DateTime? _month;
  Future<Map<String, dynamic>>? _benchmarkFuture;
  String? _startKey;
  bool _dayView = true;

  @override
  Widget build(BuildContext context) {
    return Consumer<PoultryProvider>(builder: (context, provider, _) {
      final flock = provider.activeFlock;
      if (flock == null) {
        final empty = const Center(child: Text('Select a flock to view its standards calendar.'));
        return widget.embedded
            ? empty
            : PoultryAppShell(
                selectedIndex: 11,
                title: 'Standards Calendar',
                subtitle: 'BV300 daily benchmark schedule',
                child: empty,
              );
      }
      final start = DateTime(flock.startDate.year, flock.startDate.month, flock.startDate.day);
      final end = start.add(const Duration(days: 72 * 7 - 1));
      final startKey = '${start.year}-${start.month}-${start.day}';
      if (_startKey != startKey) {
        _startKey = startKey;
        _month = DateTime(start.year, start.month, 1);
        final today = DateTime.now();
        final todayOnly = DateTime(today.year, today.month, today.day);
        _selected = (todayOnly.isBefore(start) || todayOnly.isAfter(end)) ? start : todayOnly;
        _benchmarkFuture = null;
      }
      _month ??= DateTime(start.year, start.month, 1);
      _selected ??= start;
      final selected = _selected!;
      if (_dayView) {
        _month = DateTime(selected.year, selected.month, 1);
      }
      final age = FarmConfig.flockAgeOnDate(selected, startDate: start);
      _benchmarkFuture ??= BV300BenchmarkRepository.instance.dayBenchmark(ageDays: age);

      final content = LayoutBuilder(builder: (context, c) {
          final compact = c.maxWidth < 700;
          return ListView(
            padding: EdgeInsets.all(compact ? 12 : 24),
            children: [
              AppCard(child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
                const Icon(Icons.event_note_outlined, color: Color(0xFF0E9F6E)),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Flock Standards Calendar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  Text('${flock.name} • Start ${DateFormat('dd MMM yyyy').format(start)}', style: const TextStyle(fontSize: 12, color: Color(0xFF667970))),
                ])),
              ]))),
              const SizedBox(height: 12),
              _calendarCard(context, start, end, compact),
              const SizedBox(height: 12),
              FutureBuilder<Map<String, dynamic>>(
                future: _benchmarkFuture,
                builder: (context, snap) => snap.hasData ? _benchmarkCard(snap.data!, selected, age) : const AppCard(child: Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))),
              ),
            ],
          );
        });
      return widget.embedded
          ? content
          : PoultryAppShell(
              selectedIndex: 11,
              title: 'Standards Calendar',
              subtitle: 'BV300 daily benchmark schedule',
              child: content,
            );
    });
  }

  Widget _calendarCard(BuildContext context, DateTime start, DateTime end, bool compact) {
    return AppCard(
      child: Padding(
        padding: EdgeInsets.all(compact ? 10 : 16),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_month_outlined, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('BV300 Standards', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(value: true, label: Text('Day'), icon: Icon(Icons.today_outlined, size: 16)),
                    ButtonSegment<bool>(value: false, label: Text('Month'), icon: Icon(Icons.calendar_view_month_outlined, size: 16)),
                  ],
                  selected: {_dayView},
                  onSelectionChanged: (value) => setState(() => _dayView = value.first),
                  showSelectedIcon: false,
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_dayView)
              _daySelector(context, start, end, compact)
            else
              _monthSelector(context, start, end, compact),
          ],
        ),
      ),
    );
  }

  Widget _daySelector(BuildContext context, DateTime start, DateTime end, bool compact) {
    final selected = _selected!;
    final canPrevious = selected.isAfter(start);
    final canNext = selected.isBefore(end);
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Previous day',
              onPressed: canPrevious ? () => _selectDate(selected.subtract(const Duration(days: 1)), start) : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _pickDate(context, start, end),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: const Color(0xFFF3F7F4),
                  ),
                  child: Column(
                    children: [
                      Text(DateFormat('EEEE').format(selected), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(DateFormat('dd MMM yyyy').format(selected), style: TextStyle(fontSize: compact ? 17 : 19, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 2),
                      Text('Day ${selected.difference(start).inDays + 1}', style: const TextStyle(fontSize: 11, color: Color(0xFF0E9F6E), fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Next day',
              onPressed: canNext ? () => _selectDate(selected.add(const Duration(days: 1)), start) : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () {
            final today = DateTime.now();
            final value = DateTime(today.year, today.month, today.day);
            if (!value.isBefore(start) && !value.isAfter(end)) {
              _selectDate(value, start);
            }
          },
          icon: const Icon(Icons.today_outlined, size: 17),
          label: const Text('Go to today'),
        ),
      ],
    );
  }

  Widget _monthSelector(BuildContext context, DateTime start, DateTime end, bool compact) {
    final month = _month!;
    final first = DateTime(month.year, month.month, 1);
    final days = DateTime(month.year, month.month + 1, 0).day;
    final leading = (first.weekday - DateTime.monday) % 7;
    return Column(
      children: [
        Row(
          children: [
            IconButton(onPressed: () => _changeMonth(-1, start, end), icon: const Icon(Icons.chevron_left)),
            Expanded(child: Center(child: Text(DateFormat('MMMM yyyy').format(month), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)))),
            IconButton(onPressed: () => _changeMonth(1, start, end), icon: const Icon(Icons.chevron_right)),
          ],
        ),
        Row(children: ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'].map((d) => Expanded(child: Center(child: Text(d, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF71827A)))))).toList()),
        const SizedBox(height: 6),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: leading + days,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: compact ? 0.95 : 1.05,
          ),
          itemBuilder: (_, index) {
            if (index < leading) return const SizedBox.shrink();
            final date = DateTime(month.year, month.month, index - leading + 1);
            final active = !date.isBefore(start) && !date.isAfter(end);
            final selected = _sameDay(date, _selected!);
            final age = active ? date.difference(start).inDays : -1;
            return InkWell(
              onTap: active ? () => _selectDate(date, start) : null,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFFD7F3E7) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: selected ? const Color(0xFF0E9F6E) : Colors.transparent),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('${date.day}', style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.w800 : FontWeight.w600, color: active ? const Color(0xFF26352E) : const Color(0xFFB6C0BB))),
                    if (active) Text('D${age + 1}', style: const TextStyle(fontSize: 8, color: Color(0xFF0E9F6E))),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _pickDate(BuildContext context, DateTime start, DateTime end) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selected!,
      firstDate: start,
      lastDate: end,
      helpText: 'Select standards day',
    );
    if (picked != null && mounted) {
      _selectDate(picked, start);
    }
  }

  Widget _benchmarkCard(Map<String, dynamic> b, DateTime date, int age) {
    String n(dynamic v, [String suffix = '']) => v is num ? '${v % 1 == 0 ? v.toInt() : v}$suffix' : '—';
    final items = [
      ('Life stage', b['life_stage']),
      ('Body weight', n(b['target_body_weight_g'], ' g/bird')),
      ('Uniformity', n(b['target_uniformity_percentage'], '%')),
      ('Feed', n(b['daily_feed_intake_g_per_bird'], ' g/bird/day')),
      ('Water', n(b['daily_water_intake_ml_per_bird'], ' ml/bird/day')),
      ('Grit', n(b['daily_grit_intake_g_per_bird'], ' g/bird/day')),
      ('Laying / HDEP', n(b['target_hen_day_production_percentage'], '%')),
      ('Egg weight', n(b['target_individual_egg_weight_g'], ' g')),
      ('Egg mass', n(b['target_daily_egg_mass_g'], ' g/bird/day')),
      ('Livability', n(b['target_flock_livability_percentage'], '%')),
      ('FCR / dozen', n(b['target_fcr_per_dozen_eggs'])),
      ('FCR / kg egg mass', n(b['target_fcr_per_kg_egg_mass'])),
      ('Lighting', '${n(b['lighting_photoperiod_hours'], ' h')} • ${n(b['lighting_intensity_lux'], ' lux')}'),
    ];
    return AppCard(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(DateFormat('EEEE, dd MMM yyyy').format(date), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      Text('Day ${age + 1} • Week ${b['week_number']} • ${b['life_stage']}', style: const TextStyle(fontSize: 12, color: Color(0xFF667970))),
      const Divider(height: 24),
      Wrap(spacing: 10, runSpacing: 10, children: items.map((e) => Container(width: 220, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFF3F7F4), borderRadius: BorderRadius.circular(12)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(e.$1, style: const TextStyle(fontSize: 10, color: Color(0xFF71827A))), const SizedBox(height: 4), Text('${e.$2}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800))]))).toList()),
    ])));
  }

  void _selectDate(DateTime date, DateTime start) {
    setState(() { _selected = date; _benchmarkFuture = BV300BenchmarkRepository.instance.dayBenchmark(ageDays: date.difference(start).inDays); });
  }

  void _changeMonth(int delta, DateTime start, DateTime end) {
    final next = DateTime(_month!.year, _month!.month + delta, 1);
    if (next.year < start.year || (next.year == start.year && next.month < start.month)) return;
    if (next.year > end.year || (next.year == end.year && next.month > end.month)) return;
    setState(() { _month = next; });
  }

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}
