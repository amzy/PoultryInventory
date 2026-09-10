import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/expense_sales_log.dart';
import '../models/poultry_log.dart';
import '../providers/poultry_provider.dart';
import '../widgets/app_shell.dart';

class ReportsScreen extends StatefulWidget {
  final bool embedded;

  const ReportsScreen({super.key, this.embedded = false});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTime? _from;
  DateTime? _to;
  String _range = 'All time';

  List<PoultryLog> _logs(PoultryProvider provider) {
    final list = provider.logs.where((log) {
      return (_from == null || !log.date.isBefore(_from!)) &&
          (_to == null || !log.date.isAfter(_to!));
    }).toList();
    list.sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  List<ExpenseSalesLog> _expenses(PoultryProvider provider) {
    final list = provider.expenseRecords.where((expense) {
      return (_from == null || !expense.date.isBefore(_from!)) &&
          (_to == null || !expense.date.isAfter(_to!));
    }).toList();
    list.sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  void _setRange(String value) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime? from;

    switch (value) {
      case '7 days':
        from = today.subtract(const Duration(days: 6));
        break;
      case '30 days':
        from = today.subtract(const Duration(days: 29));
        break;
      case '90 days':
        from = today.subtract(const Duration(days: 89));
        break;
    }

    setState(() {
      _range = value;
      _from = from;
      _to = today;
    });
  }

  Future<void> _pickDate(bool start) async {
    final initial = (start ? _from : _to) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked == null || !mounted) return;

    setState(() {
      if (start) {
        _from = picked;
      } else {
        _to = picked;
      }
      _range = 'Custom';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PoultryProvider>(
      builder: (context, provider, _) {
        final logs = _logs(provider);
        final expenses = _expenses(provider);

        final content = ListView(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 30),
          children: [
            _filters(),
            const SizedBox(height: 14),
            _overview(provider, logs, expenses),
            const SizedBox(height: 14),
            _reportCard(
              'Laying Percentage',
              'Daily laying percentage from production logs.',
              Icons.show_chart_outlined,
              _layingData(provider, logs),
            ),
            const SizedBox(height: 14),
            _reportCard(
              'Mortality',
              'Daily mortality and cumulative mortality percentage.',
              Icons.pets_outlined,
              _mortalityData(provider, logs),
            ),
            const SizedBox(height: 14),
            _reportCard(
              'Feed Consumption',
              'Daily feed consumed from operational Daily Logs.',
              Icons.inventory_2_outlined,
              _feedData(logs),
            ),
            const SizedBox(height: 14),
            _reportCard(
              'FCR',
              'Feed consumption divided by trays for each Daily Log.',
              Icons.speed_outlined,
              logs
                  .map((log) => _Point(
                        DateFormat('dd MMM').format(log.date),
                        log.automatedFCR,
                      ))
                  .toList(),
            ),
            const SizedBox(height: 14),
            _priceSection('Feed', expenses, 'Feed'),
            const SizedBox(height: 14),
            _priceSection('Grit', expenses, 'Grit'),
            const SizedBox(height: 14),
            _priceSection('Tray', expenses, 'Tray'),
            const SizedBox(height: 14),
            _financialSection(expenses),
          ],
        );

        if (widget.embedded) return content;

        return PoultryAppShell(
          selectedIndex: 1,
          title: 'Reports',
          subtitle: 'Production, mortality and financial analysis',
          onNavigate: (index) {
            if (index == 1) return;
            Navigator.pop(context);
          },
          child: content,
        );
      },
    );
  }

  Widget _filters() {
    return AppCard(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ChoiceChip(
            label: const Text('All time'),
            selected: _range == 'All time',
            onSelected: (_) => _setRange('All time'),
          ),
          ChoiceChip(
            label: const Text('7 days'),
            selected: _range == '7 days',
            onSelected: (_) => _setRange('7 days'),
          ),
          ChoiceChip(
            label: const Text('30 days'),
            selected: _range == '30 days',
            onSelected: (_) => _setRange('30 days'),
          ),
          ChoiceChip(
            label: const Text('90 days'),
            selected: _range == '90 days',
            onSelected: (_) => _setRange('90 days'),
          ),
          OutlinedButton.icon(
            onPressed: () => _pickDate(true),
            icon: const Icon(Icons.date_range_outlined, size: 17),
            label: Text(
              _from == null ? 'From' : DateFormat('dd MMM yyyy').format(_from!),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => _pickDate(false),
            icon: const Icon(Icons.event_outlined, size: 17),
            label: Text(
              _to == null ? 'To' : DateFormat('dd MMM yyyy').format(_to!),
            ),
          ),
        ],
      ),
    );
  }

  Widget _overview(
    PoultryProvider provider,
    List<PoultryLog> logs,
    List<ExpenseSalesLog> expenses,
  ) {
    final laying = logs.isEmpty
        ? 0.0
        : provider.layingPercentageFor(logs.last).toDouble();
    final mortality = logs.fold<int>(0, (sum, log) => sum + log.mortality);
    final feed = logs.fold<double>(0.0, (sum, log) => sum + log.feedConsumed);
    final expenseTotal = expenses
        .where((expense) => expense.transactionType != 'credit')
        .fold<double>(0.0, (sum, expense) => sum + expense.netTotal);
    final creditTotal = expenses
        .where((expense) => expense.transactionType == 'credit')
        .fold<double>(0.0, (sum, expense) => sum + expense.netTotal);

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _kpi('Laying %', '${laying.toStringAsFixed(1)}%', Icons.show_chart_outlined),
        _kpi('Mortality', mortality.toString(), Icons.pets_outlined),
        _kpi('Feed', '${feed.toStringAsFixed(0)} kg', Icons.inventory_2_outlined),
        _kpi('Expenses', _money(expenseTotal), Icons.payments_outlined),
        _kpi('Credits', _money(creditTotal), Icons.account_balance_wallet_outlined),
      ],
    );
  }

  Widget _kpi(String label, String value, IconData icon) {
    return SizedBox(
      width: 180,
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.circle, size: 0),
            Icon(icon, color: const Color(0xFF0E9F6E)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF6A7D73),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_Point> _layingData(PoultryProvider provider, List<PoultryLog> logs) {
    return logs
        .map((log) => _Point(
              DateFormat('dd MMM').format(log.date),
              provider.layingPercentageFor(log).toDouble(),
            ))
        .toList();
  }

  List<_Point> _mortalityData(
    PoultryProvider provider,
    List<PoultryLog> logs,
  ) {
    return logs
        .map((log) => _Point(
              DateFormat('dd MMM').format(log.date),
              provider.mortalityPercentageOn(log.date).toDouble(),
            ))
        .toList();
  }

  List<_Point> _feedData(List<PoultryLog> logs) {
    return logs
        .map((log) => _Point(
              DateFormat('dd MMM').format(log.date),
              log.feedConsumed.toDouble(),
            ))
        .toList();
  }

  Widget _reportCard(
    String title,
    String subtitle,
    IconData icon,
    List<_Point> points,
  ) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF0E9F6E)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF71827A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _lineChart(
            points,
            suffix: title == 'Laying Percentage' ? '%' : '',
          ),
          const SizedBox(height: 8),
          _dataTable(points, title),
        ],
      ),
    );
  }

  Widget _priceSection(
    String label,
    List<ExpenseSalesLog> expenses,
    String category,
  ) {
    final rows = expenses
        .where((expense) => expense.category == category && expense.unitPrice > 0)
        .toList();
    final points = rows
        .map((expense) => _Point(
              DateFormat('dd MMM').format(expense.date),
              expense.unitPrice.toDouble(),
            ))
        .toList();
    final total = rows.fold<double>(
      0.0,
      (sum, expense) => sum + expense.netTotal,
    );
    final avg = rows.isEmpty
        ? 0.0
        : rows.fold<double>(0.0, (sum, expense) => sum + expense.unitPrice) /
            rows.length;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label Rate & Expense',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Unit-price changes and purchase expense history.',
            style: TextStyle(fontSize: 10, color: Color(0xFF71827A)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _mini('Avg rate', '₹${avg.toStringAsFixed(2)}'),
              const SizedBox(width: 18),
              _mini('Expense', _money(total)),
              const SizedBox(width: 18),
              _mini('Purchases', rows.length.toString()),
            ],
          ),
          const SizedBox(height: 10),
          _lineChart(points, money: true),
          const SizedBox(height: 8),
          ...rows.reversed.take(8).map(_transactionRow),
        ],
      ),
    );
  }

  Widget _financialSection(List<ExpenseSalesLog> records) {
    final expenses = records
        .where((record) => record.transactionType != 'credit')
        .toList();
    final credits = records
        .where((record) => record.transactionType == 'credit')
        .toList();

    final groups = <String, double>{};
    for (final expense in expenses) {
      final key = '${expense.mainCategory} / ${expense.category}';
      groups[key] = (groups[key] ?? 0.0) + expense.netTotal;
    }

    final entries = groups.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Expenses & Credits',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Financial totals and category breakdown.',
            style: TextStyle(fontSize: 10, color: Color(0xFF71827A)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _mini(
                'Expenses',
                _money(expenses.fold<double>(
                  0.0,
                  (sum, record) => sum + record.netTotal,
                )),
              ),
              const SizedBox(width: 20),
              _mini(
                'Credits',
                _money(credits.fold<double>(
                  0.0,
                  (sum, record) => sum + record.netTotal,
                )),
              ),
              const SizedBox(width: 20),
              _mini('Transactions', (expenses.length + credits.length).toString()),
            ],
          ),
          const SizedBox(height: 12),
          ...entries.take(12).map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.key,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        _money(entry.value),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          if (credits.isNotEmpty) ...[
            const Divider(),
            const Text(
              'Credits',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
            const SizedBox(height: 5),
            ...credits.reversed.take(8).map(_transactionRow),
          ],
        ],
      ),
    );
  }

  Widget _mini(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 9, color: Color(0xFF71827A)),
        ),
      ],
    );
  }

  Widget _transactionRow(ExpenseSalesLog expense) {
    final quantityDecimals = expense.quantity % 1 == 0 ? 0 : 2;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 78,
            child: Text(
              DateFormat('dd MMM yy').format(expense.date),
              style: const TextStyle(fontSize: 10),
            ),
          ),
          Expanded(
            child: Text(
              '${expense.quantity.toStringAsFixed(quantityDecimals)} ${expense.unit}',
              style: const TextStyle(fontSize: 10),
            ),
          ),
          Text(
            '₹${expense.unitPrice.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 10),
          Text(
            _money(expense.netTotal),
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _dataTable(List<_Point> points, String title) {
    return SizedBox(
      height: 140,
      child: ListView.builder(
        itemCount: points.length,
        itemBuilder: (context, index) {
          final point = points[index];
          final value = title == 'Mortality'
              ? '${point.value.toStringAsFixed(2)}%'
              : point.value.toStringAsFixed(1);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    point.label,
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _lineChart(
    List<_Point> points, {
    String suffix = '',
    bool money = false,
  }) {
    if (points.isEmpty) {
      return const SizedBox(
        height: 170,
        child: Center(
          child: Text(
            'No data for this period.',
            style: TextStyle(fontSize: 11, color: Color(0xFF71827A)),
          ),
        ),
      );
    }

    return SizedBox(
      height: 170,
      child: CustomPaint(
        painter: _LinePainter(points),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Text(
              money
                  ? 'Unit price'
                  : suffix.isNotEmpty
                      ? 'Percentage'
                      : 'Value',
              style: const TextStyle(
                fontSize: 9,
                color: Color(0xFF71827A),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _money(double value) {
    return '₹${NumberFormat('#,##0.00').format(value)}';
  }
}

class _Point {
  final String label;
  final double value;

  const _Point(this.label, this.value);
}

class _LinePainter extends CustomPainter {
  final List<_Point> points;

  _LinePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFFE5ECE8)
      ..strokeWidth = 1;
    final linePaint = Paint()
      ..color = const Color(0xFF0E9F6E)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final pointPaint = Paint()
      ..color = const Color(0xFF0E9F6E)
      ..style = PaintingStyle.fill;

    for (var i = 0; i < 4; i++) {
      final y = 10 + (size.height - 30) * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (points.isEmpty) return;

    final values = points.map((point) => point.value).toList();
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final range = (maxValue - minValue).abs() < 0.0001
        ? 1.0
        : maxValue - minValue;

    final path = Path();

    for (var i = 0; i < points.length; i++) {
      final x = points.length == 1
          ? size.width / 2
          : i * size.width / (points.length - 1);
      final y = 10 +
          (maxValue - points[i].value) / range * (size.height - 35);
      final offset = Offset(x, y);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }

      canvas.drawCircle(offset, 3.5, pointPaint);
    }

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _LinePainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
