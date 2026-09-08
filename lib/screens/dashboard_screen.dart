import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/expense_sales_log.dart';
import '../providers/poultry_provider.dart';
import '../widgets/app_shell.dart';
import '../services/farm_config.dart';
import 'log_form_screen.dart';
import 'log_detail_screen.dart';
import 'expense_sales_form_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  void _navigate(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
  }

  Widget _currentContent(PoultryProvider provider) {
    switch (_selectedIndex) {
      case 1:
        return LogFormScreen(
          embedded: true,
          onEmbeddedBack: () => _navigate(0),
          key: const ValueKey('daily-log'),
        );
      case 2:
      case 3:
      case 4:
      case 5:
      case 6:
        return ExpenseSalesFormScreen(
          initialCategory: poultryNavItems[_selectedIndex].label.replaceAll(' ', '_'),
          embedded: true,
          onEmbeddedBack: () => _navigate(0),
          key: ValueKey('expense-$_selectedIndex'),
        );
      case 7:
        return const SettingsScreen(embedded: true, key: ValueKey('settings'));
      default:
        return _dashboardBody(provider);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PoultryProvider>(builder: (context, provider, _) {
      final isExpense = _selectedIndex >= 2 && _selectedIndex <= 6;
      final category = isExpense ? poultryNavItems[_selectedIndex].label : '';
      return PoultryAppShell(
        selectedIndex: _selectedIndex,
        title: _pageTitle(category),
        subtitle: _pageSubtitle(),
        trailing: _selectedIndex == 0 ? _syncButton(provider) : null,
        onNavigate: _navigate,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          reverseDuration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(.025, 0), end: Offset.zero).animate(animation),
              child: child,
            ),
          ),
          child: _currentContent(provider),
        ),
      );
    });
  }

  String _pageTitle(String category) {
    if (_selectedIndex == 0) return 'Dashboard';
    if (_selectedIndex == 1) return 'Add Daily Log';
    if (_selectedIndex == 7) return 'Settings';
    return 'Add ${category == 'Egg Sales' ? 'Egg Sales' : 'Expense'}';
  }

  String _pageSubtitle() {
    if (_selectedIndex == 0) return 'Overview of your poultry farm';
    if (_selectedIndex == 1) return 'Track daily flock data';
    if (_selectedIndex == 7) return 'App preferences and data tools';
    return 'Record farm financial activity';
  }

  Widget _syncButton(PoultryProvider provider) => SizedBox(
    height: 42,
    child: FilledButton.icon(
      onPressed: provider.isSigningIn ? null : provider.signInToGoogle,
      icon: Icon(provider.isGoogleSignedIn ? Icons.cloud_done : Icons.login, size: 17),
      label: Text(provider.isSigningIn ? 'Connecting…' : provider.isGoogleSignedIn ? 'Firebase Connected' : 'Sign in'),
      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF087A4F), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11))),
    ),
  );

  Widget _dashboardBody(PoultryProvider provider) {
    return RefreshIndicator(
      color: const Color(0xFF087A4F),
      onRefresh: provider.fetchLogs,
      child: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1050;
        return ListView(
          padding: EdgeInsets.fromLTRB(wide ? 24 : 14, 8, wide ? 24 : 14, 28),
          children: [
            Row(children: [
              const Spacer(),
              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFDCE7E0))), child: Row(children: [const Icon(Icons.calendar_today_outlined, size: 15, color: Color(0xFF315B4A)), const SizedBox(width: 7), Text(_dateRange(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF29473A)))])),
            ]),
            const SizedBox(height: 12),
            if (provider.errorMessage != null) _error(provider.errorMessage!),
            _metrics(provider, wide),
            const SizedBox(height: 14),
            if (wide) Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: _eggProduction(provider)), const SizedBox(width: 14), Expanded(child: _expenseChart(provider))])
            else ...[_eggProduction(provider), const SizedBox(height: 14), _expenseChart(provider)],
            const SizedBox(height: 14),
            _expenseGroups(provider),
            const SizedBox(height: 14),
            _recentLogs(provider),
            const SizedBox(height: 14),
            _quickActions(),
          ],
        );
      }),
    );
  }

  String _dateRange() {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 6));
    return '${DateFormat('MMM d, yyyy').format(start)} – ${DateFormat('MMM d, yyyy').format(now)}';
  }

  Widget _metrics(PoultryProvider p, bool wide) {
    final items = [
      ('Flock Age', '${FarmConfig.flockAgeOn(DateTime.now())} days', Icons.timelapse_outlined, const Color(0xFF7C3AED)),
      ('Birds', '${p.totalBirds}', Icons.pets_outlined, const Color(0xFF0E9F6E)),
      ('Eggs', NumberFormat('#,##0').format(p.totalEggs), Icons.egg_alt_outlined, const Color(0xFFF59E0B)),
      ('Feed', '${p.totalFeedKg.toStringAsFixed(0)} kg', Icons.inventory_2_outlined, const Color(0xFF15803D)),
      ('Grit', '${p.logs.fold<double>(0, (s, l) => s + l.stoneGritConsumed).toStringAsFixed(0)} kg', Icons.scatter_plot_outlined, const Color(0xFF9A6B22)),
      ('Expenses', _money(p.totalExpenses), Icons.monetization_on_outlined, const Color(0xFFEA580C)),
    ];
    return LayoutBuilder(builder: (context, c) {
      final count = wide ? 6 : c.maxWidth >= 800 ? 3 : c.maxWidth >= 650 ? 2 : 2;
      final w = (c.maxWidth - (count - 1) * 10) / count;
      return Wrap(spacing: 10, runSpacing: 10, children: items.map((e) => SizedBox(width: w, child: _metricCard(e.$1, e.$2, e.$3, e.$4))).toList());
    });
  }

  Widget _metricCard(String label, String value, IconData icon, Color color) => AppCard(
    padding: const EdgeInsets.all(14),
    child: Row(children: [Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withOpacity(.11), borderRadius: BorderRadius.circular(11)), child: Icon(icon, color: color, size: 22)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Color(0xFF12251D))), const SizedBox(height: 2), Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF6A7D73)))]))]),
  );

  Widget _eggProduction(PoultryProvider p) => AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Egg Production', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF12251D))),
    const SizedBox(height: 12), SizedBox(height: 190, child: CustomPaint(painter: _BarChartPainter(p.logs.take(7).toList().reversed.map((e) => e.totalEggs.toDouble()).toList()), child: const SizedBox.expand())),
  ]));

  Widget _expenseChart(PoultryProvider p) {
    final total = p.totalExpenses + p.totalEggSales;
    final values = total <= 0 ? [45.0, 20.0, 15.0, 10.0, 10.0] : [p.totalExpenses * .45, p.totalExpenses * .20, p.totalExpenses * .15, p.totalExpenses * .10, p.totalEggSales];
    return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Expenses & Sales', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF12251D))),
      const SizedBox(height: 8), SizedBox(height: 190, child: Row(children: [Expanded(child: CustomPaint(painter: _PieChartPainter(values), child: const SizedBox.expand())), const SizedBox(width: 12), Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: const [Text('Feed', style: TextStyle(fontSize: 11)), Text('Medical', style: TextStyle(fontSize: 11)), Text('Grit', style: TextStyle(fontSize: 11)), Text('Other', style: TextStyle(fontSize: 11)), Text('Egg Sales', style: TextStyle(fontSize: 11))]))]))
    ]));
  }

  Widget _expenseGroups(PoultryProvider p) {
    final groups = <String, double>{};
    for (final e in p.expenseRecords.where((e) => e.category != 'Egg_Sales')) {
      final key = e.mainCategory.trim().isEmpty ? 'Uncategorized' : e.mainCategory.trim();
      groups[key] = (groups[key] ?? 0) + e.amount;
    }
    final entries = groups.entries.toList()..sort((a,b) => b.value.compareTo(a.value));
    return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Expenses by Main Category', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF12251D))),
      const SizedBox(height: 10),
      if (entries.isEmpty) const Text('No expense groups yet.', style: TextStyle(fontSize: 11, color: Color(0xFF71827A)))
      else ...entries.take(8).map((e) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
        Expanded(child: Text(e.key, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
        Text(_money(e.value), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0E9F6E))),
      ]))),
    ]));
  }

  Widget _recentLogs(PoultryProvider p) => AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [const Expanded(child: Text('Recent Daily Logs', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF12251D)))), TextButton(onPressed: p.logs.isEmpty ? null : () {}, child: const Text('View All'))]),
    const SizedBox(height: 4),
    if (p.logs.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('No daily log records found.', style: TextStyle(color: Color(0xFF7B8C84)))))
    else LayoutBuilder(builder: (context, c) => c.maxWidth >= 800 ? _logTable(p) : Column(children: p.logs.take(5).map((log) => _logRow(log)).toList())),
  ]));

  Widget _logTable(PoultryProvider p) => Column(children: [
    _tableHeader(),
    ...p.logs.take(5).map((log) => InkWell(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LogDetailScreen(log: log))), child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE6EEE9)))), child: Row(children: [_cell(DateFormat('MMM d, yyyy').format(log.date), 1.2), _cell('${log.startingBirds}', 1), _cell('${log.mortality}', .8), _cell('${log.endingBirds}', 1), _cell('${log.totalEggs}', 1), _cell('${log.feedConsumed.toStringAsFixed(0)}', 1), _cell(log.automatedFCR.toStringAsFixed(2), .8), _cell('${log.layingPercentage.toStringAsFixed(1)}%', 1)]))))
  ]);

  Widget _tableHeader() => Container(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: ['Date','Starting Birds','Mortality','Ending Birds','Total Eggs','Feed (kg)','FCR','Laying %'].map((x) => _cell(x, x == 'Date' ? 1.2 : 1, header: true)).toList()));
  Widget _cell(String text, double flex, {bool header = false}) => Expanded(flex: (flex * 10).round(), child: Text(text, style: TextStyle(fontSize: header ? 10 : 11, color: header ? const Color(0xFF63766C) : const Color(0xFF253B31), fontWeight: header ? FontWeight.w700 : FontWeight.w600), overflow: TextOverflow.ellipsis));

  Widget _logRow(dynamic log) => Container(margin: const EdgeInsets.only(top: 7), decoration: BoxDecoration(color: const Color(0xFFF7FAF8), borderRadius: BorderRadius.circular(11), border: Border.all(color: const Color(0xFFE1EAE5))), child: ListTile(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LogDetailScreen(log: log))), dense: true, leading: Container(width: 34, height: 34, decoration: BoxDecoration(color: const Color(0xFFE7F5EE), borderRadius: BorderRadius.circular(9)), child: const Icon(Icons.calendar_month_outlined, color: Color(0xFF0E9F6E), size: 18)), title: Text(DateFormat('dd MMM yyyy').format(log.date), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), subtitle: Text('Age ${log.flockAge}d  •  ${log.totalEggs} eggs  •  ${log.endingBirds} birds', style: const TextStyle(fontSize: 10, color: Color(0xFF71837A))), trailing: Text('${log.layingPercentage.toStringAsFixed(1)}%', style: const TextStyle(color: Color(0xFF087A4F), fontWeight: FontWeight.w800))));

  Widget _quickActions() => LayoutBuilder(builder: (context, c) {
    final actions = [
      ('Add Daily Log', 'Record today’s data', Icons.calendar_month_outlined, const Color(0xFF0E9F6E), 1),
      ('Add Expense', 'Track expenses', Icons.payments_outlined, const Color(0xFFF59E0B), 3),
      ('Add Egg Sales', 'Record egg sales', Icons.egg_alt_outlined, const Color(0xFFF97316), 6),
      ('View Reports', 'Growth & analytics', Icons.bar_chart_outlined, const Color(0xFF0E9F6E), 0),
    ];
    final w = (c.maxWidth - 30) / 4;
    return Wrap(spacing: 10, runSpacing: 10, children: actions.map((a) => SizedBox(width: c.maxWidth < 650 ? (c.maxWidth - 10) / 2 : w, child: InkWell(onTap: () => _navigate(a.$5), child: AppCard(padding: const EdgeInsets.all(12), child: Row(children: [Container(width: 34, height: 34, decoration: BoxDecoration(color: a.$4.withOpacity(.11), borderRadius: BorderRadius.circular(9)), child: Icon(a.$3, color: a.$4, size: 19)), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(a.$1, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)), Text(a.$2, style: const TextStyle(fontSize: 9, color: Color(0xFF75867D)))]))]))))).toList());
  });

  Widget _error(String text) => Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFFFF1F0), borderRadius: BorderRadius.circular(11), border: Border.all(color: const Color(0xFFF5C2C0))), child: Text(text, style: const TextStyle(color: Color(0xFF9F2D28), fontSize: 12)));
  String _money(double value) => '₹${NumberFormat('#,##0').format(value)}';
}

class _BarChartPainter extends CustomPainter {
  final List<double> values; _BarChartPainter(this.values);
  @override void paint(Canvas canvas, Size size) {
    final grid = Paint()..color = const Color(0xFFE6ECE8)..strokeWidth = 1;
    final bar = Paint()..color = const Color(0xFF35B86B);
    for (var i=0;i<5;i++){final y=12+(size.height-35)*i/4;canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);}
    if(values.isEmpty)return; final max=values.reduce((a,b)=>a>b?a:b); final bw=size.width/(values.length*1.6); for(var i=0;i<values.length;i++){final h=max<=0 ? 0.0 : (values[i]/max)*(size.height-45); final x=i*size.width/values.length+(size.width/values.length-bw)/2; canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x,size.height-25-h,bw,h),const Radius.circular(4)),bar);}
  }
  @override bool shouldRepaint(covariant _BarChartPainter old)=>old.values!=values;
}

class _PieChartPainter extends CustomPainter {
  final List<double> values; _PieChartPainter(this.values);
  @override void paint(Canvas canvas, Size size) { final total=values.fold<double>(0,(a,b)=>a+b); if(total<=0)return; final colors=[const Color(0xFF2F80ED),const Color(0xFFF59E0B),const Color(0xFF34B66A),const Color(0xFFF97316),const Color(0xFF9CA3AF)]; final r=(size.shortestSide*.34); final center=Offset(size.width/2,size.height/2); var start=-1.57; for(var i=0;i<values.length;i++){final sweep=values[i]/total*6.283; final p=Paint()..color=colors[i%colors.length];canvas.drawArc(Rect.fromCircle(center:center,radius:r),start,sweep,true,p);start+=sweep;} }
  @override bool shouldRepaint(covariant _PieChartPainter old)=>old.values!=values;
}
