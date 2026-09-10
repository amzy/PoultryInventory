import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/expense_sales_log.dart';
import '../providers/poultry_provider.dart';
import '../widgets/app_shell.dart';
import '../services/farm_config.dart';
import '../services/expense_category_config.dart';
import 'log_form_screen.dart';
import 'log_detail_screen.dart';
import 'expense_sales_form_screen.dart';
import 'expense_records_screen.dart';
import 'settings_screen.dart';
import 'reports_screen.dart';
import 'suppliers_screen.dart';
import 'profile_screen.dart';

enum DashboardArtifactGroup {
  flockContext,
  overview,
  analytics,
  financial,
  activity,
  actions,
}

class DashboardArtifactGroupConfig {
  final DashboardArtifactGroup group;
  final bool visible;

  const DashboardArtifactGroupConfig(this.group, {this.visible = true});
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  DateTime? _backgroundedAt;
  bool _refreshingAfterResume = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.hidden) {
      _backgroundedAt ??= DateTime.now();
      return;
    }
    if (state != AppLifecycleState.resumed || _backgroundedAt == null || _refreshingAfterResume) return;
    final elapsed = DateTime.now().difference(_backgroundedAt!);
    _backgroundedAt = null;
    if (elapsed < const Duration(minutes: 2) || !mounted) return;
    final provider = context.read<PoultryProvider>();
    if (!provider.isAuthenticated || !provider.hasFlock) return;
    _refreshingAfterResume = true;
    provider.fetchLogs().whenComplete(() {
      if (mounted) _refreshingAfterResume = false;
    });
  }

  void _navigate(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
  }

  void _backToDashboard() {
    setState(() => _selectedIndex = 0);
  }

  Widget _currentContent(PoultryProvider provider) {
    switch (_selectedIndex) {
      case 2:
        return LogFormScreen(
          embedded: true,
          onEmbeddedBack: () => _navigate(0),
          key: const ValueKey('daily-log'),
        );
      case 3:
      case 4:
      case 5:
      case 6:
      case 7:
      case 8:
        return ExpenseSalesFormScreen(
          initialCategory: _selectedIndex == 8 ? 'Egg' : poultryNavItems[_selectedIndex].label.replaceAll(' ', '_'),
          initialEggSale: _selectedIndex == 8,
          embedded: true,
          onEmbeddedBack: () => _navigate(0),
          key: ValueKey('expense-$_selectedIndex'),
        );
      case 1:
        return const ReportsScreen(embedded: true, key: ValueKey('reports'));
      case 9:
        return const SuppliersScreen(key: ValueKey('suppliers'));
      case 10:
        return const SettingsScreen(embedded: true, key: ValueKey('settings'));
      case 11:
        return ProfileScreen(embedded: true, onEmbeddedBack: _backToDashboard, key: const ValueKey('profile'));
      default:
        return _dashboardBody(provider);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PoultryProvider>(builder: (context, provider, _) {
      final isExpense = _selectedIndex >= 3 && _selectedIndex <= 8;
      final category = isExpense ? poultryNavItems[_selectedIndex].label : '';
      return PoultryAppShell(
        selectedIndex: _selectedIndex,
        title: _pageTitle(category),
        subtitle: _pageSubtitle(),
        trailing: null,
        headerOverride: _selectedIndex == 0 && provider.activeFlock != null
            ? DashboardHeader(
                flockName: provider.activeFlock!.name,
                startDate: provider.activeFlock!.startDate,
                age: FarmConfig.flockAgeOnDate(DateTime.now(), startDate: provider.activeFlock!.startDate),
              )
            : null,
        onNavigate: _navigate,
        onBack: _selectedIndex == 11 ? _backToDashboard : null,
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
    if (_selectedIndex == 1) return 'Reports';
    if (_selectedIndex == 2) return 'Add Daily Log';
    if (_selectedIndex == 9) return 'Suppliers';
    if (_selectedIndex == 10) return 'Settings';
    if (_selectedIndex == 11) return 'My Profile';
    return 'Add ${category == 'Egg Sales' ? 'Egg Sales' : 'Expense'}';
  }

  String _pageSubtitle() {
    if (_selectedIndex == 0) return 'Overview of your poultry farm';
    if (_selectedIndex == 1) return 'Production, mortality and financial analysis';
    if (_selectedIndex == 2) return 'Track daily flock data';
    if (_selectedIndex == 9) return 'Supplier directory';
    if (_selectedIndex == 10) return 'App preferences, data tools and administration';
    if (_selectedIndex == 11) return 'Personal account information';
    return 'Record farm financial activity';
  }

  Widget _dashboardBody(PoultryProvider provider) {
    return RefreshIndicator(
      color: const Color(0xFF087A4F),
      onRefresh: provider.fetchLogs,
      child: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1050;
        return ListView(
          padding: EdgeInsets.fromLTRB(wide ? 24 : 14, 8, wide ? 24 : 14, 28),
          children: _buildDashboardGroups(provider, wide),
        );
      }),
    );
  }

  // Dashboard artifacts are intentionally grouped so visibility/order can later be
  // controlled by an admin without changing the individual artifact widgets.
  List<Widget> _buildDashboardGroups(PoultryProvider provider, bool wide) {
    const groups = [
      DashboardArtifactGroupConfig(DashboardArtifactGroup.flockContext),
      DashboardArtifactGroupConfig(DashboardArtifactGroup.overview),
      DashboardArtifactGroupConfig(DashboardArtifactGroup.analytics),
      DashboardArtifactGroupConfig(DashboardArtifactGroup.financial),
      DashboardArtifactGroupConfig(DashboardArtifactGroup.activity),
      DashboardArtifactGroupConfig(DashboardArtifactGroup.actions),
    ];

    final widgets = <Widget>[];
    for (final config in groups) {
      if (!config.visible) continue;
      final groupWidgets = switch (config.group) {
        DashboardArtifactGroup.flockContext => [
            LayoutBuilder(builder: (context, c) {
              final count = c.maxWidth >= 1000 ? 2 : 1;
              final w = (c.maxWidth - (count - 1) * 10) / count;
              return Wrap(spacing: 10, runSpacing: 10, children: [
                SizedBox(width: w, child: _metricCard('Expenses', _money(provider.totalExpenses), Icons.monetization_on_outlined, const Color(0xFFEA580C))),
                SizedBox(width: w, child: _metricCard('Earnings', _money(provider.totalCredits), Icons.trending_up_outlined, const Color(0xFF087A4F))),
                SizedBox(width: w, child: _metricCard(
                  provider.totalCredits >= provider.totalExpenses ? 'Profit' : 'Loss',
                  _money((provider.totalCredits - provider.totalExpenses).abs()),
                  provider.totalCredits >= provider.totalExpenses ? Icons.account_balance_wallet_outlined : Icons.warning_amber_rounded,
                  provider.totalCredits >= provider.totalExpenses ? const Color(0xFF0E9F6E) : const Color(0xFFDC2626),
                )),
                SizedBox(width: w, child: _metricCard(
                  provider.totalCredits >= provider.totalExpenses ? 'Profit %' : 'Loss %',
                  _percent(provider.totalCredits > provider.totalExpenses
                      ? ((provider.totalCredits - provider.totalExpenses) / provider.totalCredits)
                      : (provider.totalExpenses > 0
                          ? ((provider.totalExpenses - provider.totalCredits) / provider.totalExpenses)
                          : 0.0)),
                  provider.totalCredits >= provider.totalExpenses ? Icons.percent : Icons.percent,
                  provider.totalCredits >= provider.totalExpenses ? const Color(0xFF0E9F6E) : const Color(0xFFDC2626),
                )),
              ]);
            }),
            const SizedBox(height: 12),
            if (provider.errorMessage != null) _error(provider.errorMessage!),
          ],
        DashboardArtifactGroup.overview => [
            _metrics(provider, wide),
          ],
        DashboardArtifactGroup.analytics => [
            if (wide)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: _eggProduction(provider)),
                const SizedBox(width: 14),
                Expanded(child: _expenseChart(provider)),
              ])
            else ...[
              _eggProduction(provider),
              const SizedBox(height: 14),
              _expenseChart(provider),
            ],
          ],
        DashboardArtifactGroup.financial => [
            _accountSummary(provider),
            const SizedBox(height: 14),
            _expenseGroups(provider),
          ],
        DashboardArtifactGroup.activity => [
            _recentTransactions(provider),
            const SizedBox(height: 14),
            _recentLogs(provider),
          ],
        DashboardArtifactGroup.actions => [
            _quickActions(),
          ],
      };
      widgets.addAll(groupWidgets);
      widgets.add(const SizedBox(height: 14));
    }
    return widgets;
  }

  Widget _metrics(PoultryProvider p, bool wide) {
    final items = [
      ('Flock Age', '${FarmConfig.flockAgeOnDate(DateTime.now(), startDate: p.farmConfig.flockStartDate)} days', Icons.timelapse_outlined, const Color(0xFF7C3AED)),
      ('Eggs', NumberFormat('#,##0').format(p.totalEggs), Icons.egg_alt_outlined, const Color(0xFFF59E0B)),
      ('Feed', '${p.totalFeedKg.toStringAsFixed(0)} kg', Icons.inventory_2_outlined, const Color(0xFF15803D)),
      ('Grit', _gritMetricValue(p), Icons.scatter_plot_outlined, const Color(0xFF9A6B22)),
      ('Laying %', '${p.latestLayingPercentage.toStringAsFixed(1)}%', Icons.show_chart_outlined, const Color(0xFF0E9F6E)),
    ];
    return LayoutBuilder(builder: (context, c) {
      final count = wide ? 3 : c.maxWidth >= 800 ? 2 : 1;
      final w = (c.maxWidth - (count - 1) * 10) / count;
      return Wrap(spacing: 10, runSpacing: 10, children: [
        SizedBox(width: w, child: _birdsCard(p)),
        ...items.map((e) => SizedBox(width: w, child: _metricCard(e.$1, e.$2, e.$3, e.$4, onTap: e.$1 == 'Laying %' ? () => _navigate(0) : null))),
      ]);
    });
  }

  String _gritMetricValue(PoultryProvider p) {
    final grit = p.logs.fold<double>(0, (sum, log) => sum + log.stoneGritConsumed);
    final feed = p.logs.fold<double>(0, (sum, log) => sum + log.feedConsumed);
    final percentage = feed > 0 ? (grit / feed) * 100 : 0.0;
    return '${grit.toStringAsFixed(0)} kg • ${percentage.toStringAsFixed(2)}% of feed';
  }

  String _birdsTitle(PoultryProvider p) {
    final breedName = p.farmConfig.breedName.trim();
    return breedName.isEmpty ? 'Birds' : '$breedName Birds';
  }

  Widget _birdsCard(PoultryProvider p) => AppCard(
    padding: const EdgeInsets.all(14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        ClipRRect(borderRadius: BorderRadius.circular(11), child: Image.asset('assets/app_icons/app_logo.png', width: 40, height: 40, fit: BoxFit.cover)),
        const SizedBox(width: 10),
        Text(_birdsTitle(p), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF12251D))),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _birdStat('Starting (Day 0)', NumberFormat('#,##0').format(p.startingBirdsAtDayZero))),
        Expanded(child: _birdStat('Current Alive', NumberFormat('#,##0').format(p.totalBirds))),
        Expanded(child: _birdStat('Mortality', '${p.mortalityPercentage.toStringAsFixed(2)}%')),
      ]),
    ]),
  );

  Widget _birdStat(String label, String value) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF12251D))),
    const SizedBox(height: 2),
    Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF6A7D73)), maxLines: 2),
  ]);

  Widget _metricCard(String label, String value, IconData icon, Color color, {VoidCallback? onTap}) => InkWell(borderRadius: BorderRadius.circular(16), onTap: onTap, child: AppCard(
    padding: const EdgeInsets.all(14),
    child: Row(children: [Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withValues(alpha: .11), borderRadius: BorderRadius.circular(11)), child: Icon(icon, color: color, size: 22)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Color(0xFF12251D))), const SizedBox(height: 2), Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF6A7D73)))]))]),
  ));

  Widget _eggProduction(PoultryProvider p) => AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Egg Production', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF12251D))),
    const SizedBox(height: 12), SizedBox(height: 190, child: CustomPaint(painter: _BarChartPainter(p.logs.take(7).toList().reversed.map((e) => e.totalEggs.toDouble()).toList()), child: const SizedBox.expand())),
  ]));

  Widget _expenseChart(PoultryProvider p) {
    final grouped = <String, List<ExpenseSalesLog>>{};
    for (final record in p.expenseRecords) {
      final isSale = record.transactionType == 'credit';
      final key = isSale
          ? 'Credits / Earnings'
          : (record.mainCategory.trim().isEmpty ? 'Uncategorized' : record.mainCategory.trim());
      grouped.putIfAbsent(key, () => []).add(record);
    }
    final entries = grouped.entries.toList()
      ..sort((a, b) => b.value.fold<double>(0, (sum, e) => sum + e.netTotal).compareTo(b.value.fold<double>(0, (sum, e) => sum + e.netTotal)));
    final values = entries.map((e) => e.value.fold<double>(0, (sum, r) => sum + r.netTotal)).toList();

    return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Expenses / Earnings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF12251D))),
      const SizedBox(height: 4),
      const Text('Tap a category to view its transactions', style: TextStyle(fontSize: 10, color: Color(0xFF71827A))),
      const SizedBox(height: 8),
      SizedBox(height: 210, child: values.isEmpty
          ? const Center(child: Text('No expense or sales transactions yet.', style: TextStyle(fontSize: 11, color: Color(0xFF71827A))))
          : Row(children: [
              Expanded(child: LayoutBuilder(builder: (context, chartConstraints) {
                final chartSize = Size(chartConstraints.maxWidth, chartConstraints.maxHeight);
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) {
                    final index = _pieIndexForTap(details.localPosition, chartSize, values);
                    if (index != null && index < entries.length) _showCategoryTransactions(entries[index].key, entries[index].value);
                  },
                  child: CustomPaint(painter: _PieChartPainter(values, selectedIndex: -1), child: const SizedBox.expand()),
                );
              })),
              const SizedBox(width: 8),
              Expanded(child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: entries.length,
                separatorBuilder: (_, __) => const SizedBox(height: 7),
                itemBuilder: (context, index) {
                  final amount = values[index];
                  final sale = entries[index].key == 'Credits / Earnings';
                  return InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _showCategoryTransactions(entries[index].key, entries[index].value),
                    child: Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [
                      Container(width: 9, height: 9, decoration: BoxDecoration(color: _pieColors[index % _pieColors.length], shape: BoxShape.circle)),
                      const SizedBox(width: 7),
                      Expanded(child: Text(entries[index].key, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700))),
                      Text('${sale ? '+' : ''}${_money(amount)}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: sale ? const Color(0xFF087A4F) : const Color(0xFFB45309))),
                    ])),
                  );
                },
              )),
            ])),
    ]));
  }

  int? _pieIndexForTap(Offset position, Size size, List<double> values) {
    final total = values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return null;
    final center = Offset(size.width / 2, size.height / 2);
    final dx = position.dx - center.dx;
    final dy = position.dy - center.dy;
    final radius = math.sqrt(dx * dx + dy * dy);
    final chartRadius = size.shortestSide * .34;
    if (radius > chartRadius) return null;
    var angle = math.atan2(dy, dx) + math.pi / 2;
    if (angle < 0) angle += math.pi * 2;
    var cursor = 0.0;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * math.pi * 2;
      if (angle >= cursor && angle <= cursor + sweep) return i;
      cursor += sweep;
    }
    return null;
  }

  void _showCategoryTransactions(String category, List<ExpenseSalesLog> records) {
    final sorted = [...records]..sort((a, b) => b.date.compareTo(a.date));
    final total = sorted.fold<double>(0, (sum, r) => sum + r.netTotal);
    final isSale = category == 'Credits / Earnings';
    showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
      title: Row(children: [Expanded(child: Text(category)), IconButton(onPressed: () => Navigator.pop(dialogContext), icon: const Icon(Icons.close))]),
      content: SizedBox(width: 520, height: 420, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${isSale ? 'Earnings' : 'Expenses'} • ${_money(total)}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: isSale ? const Color(0xFF087A4F) : const Color(0xFFB45309))),
        const SizedBox(height: 12),
        Expanded(child: sorted.isEmpty ? const Align(alignment: Alignment.topLeft, child: Text('No transactions.')) : ListView.separated(itemCount: sorted.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (_, index) {
          final r = sorted[index];
          final detail = [r.account.trim(), r.description.trim(), r.category == category ? '' : r.category, r.unit.trim().isEmpty ? '' : '${r.quantity % 1 == 0 ? r.quantity.toInt() : r.quantity} ${r.unit}'].where((x) => x.isNotEmpty).join(' • ');
          return ListTile(contentPadding: EdgeInsets.zero, leading: CircleAvatar(radius: 16, backgroundColor: isSale ? const Color(0xFFE4F7EC) : const Color(0xFFFFF3E2), child: Icon(isSale ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 16, color: isSale ? const Color(0xFF087A4F) : const Color(0xFFB45309))), title: Text(_money(r.netTotal), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)), subtitle: Text('${DateFormat('dd MMM yyyy').format(r.date)}${detail.isEmpty ? '' : ' • $detail'}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Color(0xFF71827A))));
        })),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close'))],
    ));
  }

  Widget _accountSummary(PoultryProvider p) {
    final names = <String>{
      ...ExpenseCategoryConfig.activeAccounts,
      ...p.expenseRecords.map((e) => e.account.trim()).where((e) => e.isNotEmpty),
    }.toList()..sort();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Accounts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF12251D))),
          const SizedBox(height: 4),
          const Text('Expenses and credits grouped by who paid or received the transaction.', style: TextStyle(fontSize: 10, color: Color(0xFF71827A))),
          const SizedBox(height: 12),
          if (names.isEmpty)
            const Text('No account transactions yet.', style: TextStyle(fontSize: 11, color: Color(0xFF71827A)))
          else
            LayoutBuilder(builder: (context, constraints) {
              final columns = constraints.maxWidth >= 900 ? 2 : 1;
              final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: names.map((name) {
                  final records = p.expenseRecords.where((e) => e.account.trim() == name).toList();
                  final expenses = records.where((e) => e.transactionType != 'credit').fold<double>(0, (sum, e) => sum + e.netTotal);
                  final credits = records.where((e) => e.transactionType == 'credit').fold<double>(0, (sum, e) => sum + e.netTotal);
                  return SizedBox(
                    width: width,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFFF7FAF8), borderRadius: BorderRadius.circular(11), border: Border.all(color: const Color(0xFFE1EAE5))),
                      child: Row(children: [
                        Container(width: 38, height: 38, decoration: BoxDecoration(color: const Color(0xFFE7F5EE), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.person_outline, color: Color(0xFF087A4F), size: 20)),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF243A30))),
                          const SizedBox(height: 6),
                          Row(children: [
                            Expanded(child: Text('Expense\n${_money(expenses)}', style: const TextStyle(fontSize: 10, color: Color(0xFFB45309), fontWeight: FontWeight.w700))),
                            Expanded(child: Text('Credit\n${_money(credits)}', style: const TextStyle(fontSize: 10, color: Color(0xFF087A4F), fontWeight: FontWeight.w700))),
                            Expanded(child: Text('Net\n${_money(credits - expenses)}', style: const TextStyle(fontSize: 10, color: Color(0xFF52665C), fontWeight: FontWeight.w700))),
                          ]),
                        ])),
                      ]),
                    ),
                  );
                }).toList(),
              );
            }),
        ],
      ),
    );
  }

  Widget _expenseGroups(PoultryProvider p) {
    final groups = <String, double>{};
    for (final e in p.expenseRecords.where((e) => e.transactionType != 'credit')) {
      final key = e.mainCategory.trim().isEmpty ? 'Uncategorized' : e.mainCategory.trim();
      groups[key] = (groups[key] ?? 0) + e.netTotal;
    }
    final entries = groups.entries.toList()..sort((a,b) => b.value.compareTo(a.value));
    return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Expenses by Main Category', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF12251D))),
      const SizedBox(height: 4),
      const Text('Phase/group totals. Detailed subcategory totals are available in Expenses.', style: TextStyle(fontSize: 10, color: Color(0xFF71827A))),
      const SizedBox(height: 10),
      if (entries.isEmpty) const Text('No expense groups yet.', style: TextStyle(fontSize: 11, color: Color(0xFF71827A)))
      else ...entries.take(8).map((e) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
        Expanded(child: Text(e.key, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
        Text(_money(e.value), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0E9F6E))),
      ]))),
    ]));
  }

  Future<void> _openTransactions(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ExpenseRecordsScreen(),
      ),
    );
    if (mounted) setState(() {});
  }

  Widget _recentTransactions(PoultryProvider p) {
    final records = [...p.expenseRecords]
      ..sort((a, b) => b.date.compareTo(a.date));

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Recent Transactions',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF12251D),
                  ),
                ),
              ),
              TextButton(
                onPressed: records.isEmpty ? null : () => _openTransactions(context),
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (records.isEmpty)
            const Padding(
              padding: EdgeInsets.all(18),
              child: Center(
                child: Text(
                  'No financial transactions found.',
                  style: TextStyle(color: Color(0xFF7B8C84)),
                ),
              ),
            )
          else
            ...records.take(6).map((r) {
              final sale = r.transactionType == 'credit';
              final matchingSuppliers =
                  p.suppliers.where((x) => x.id == r.supplierId);
              final supplier = matchingSuppliers.isEmpty
                  ? null
                  : matchingSuppliers.first;

              return ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: _avatarStack(
                  r.account,
                  supplier?.fullName,
                  sale,
                ),
                title: Text(
                  r.description.trim().isEmpty ? r.category : r.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: Text(
                  '${DateFormat('dd MMM yyyy').format(r.date)} • '
                  '${r.mainCategory} / ${r.category}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF71837A),
                  ),
                ),
                trailing: Text(
                  '${sale ? '+' : '−'}${_money(r.netTotal)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: sale
                        ? const Color(0xFF087A4F)
                        : const Color(0xFFB45309),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _avatarStack(String account,String? supplier,bool sale){
    Widget avatar(String text,IconData icon){final t=text.trim();return CircleAvatar(radius:15,backgroundColor:sale?const Color(0xFFE4F7EC):const Color(0xFFF0F4F1),child:t.isEmpty?Icon(icon,size:15,color:const Color(0xFF087A4F)):Text(t[0].toUpperCase(),style:const TextStyle(fontSize:11,fontWeight:FontWeight.w900,color:Color(0xFF087A4F))));}
    return SizedBox(width:supplier==null?34:50,height:32,child:Stack(children:[Positioned(left:0,child:avatar(account,Icons.person_outline)),if(supplier!=null)Positioned(left:18,child:Container(decoration:const BoxDecoration(shape:BoxShape.circle,color:Colors.white),padding:const EdgeInsets.all(2),child:avatar(supplier,Icons.local_shipping_outlined)))]));
  }

  Widget _recentLogs(PoultryProvider p) => AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [const Expanded(child: Text('Recent Daily Logs', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF12251D)))), TextButton(onPressed: p.logs.isEmpty ? null : () {}, child: const Text('View All'))]),
    const SizedBox(height: 4),
    if (p.logs.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('No daily log records found.', style: TextStyle(color: Color(0xFF7B8C84)))))
    else LayoutBuilder(builder: (context, c) => c.maxWidth >= 800 ? _logTable(p) : Column(children: p.logs.take(5).map((log) => _logRow(p, log)).toList())),
  ]));

  Widget _logTable(PoultryProvider p) => Column(children: [
    _tableHeader(),
    ...p.logs.take(5).map((log) => InkWell(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LogDetailScreen(log: log))), child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE6EEE9)))), child: Row(children: [_cell(DateFormat('MMM d, yyyy').format(log.date), 1.2), _cell('${log.mortality}', .9), _cell('${log.totalEggs}', 1), _cell('${log.feedConsumed.toStringAsFixed(0)}', 1), _cell(log.fcrByEggMass.toStringAsFixed(2), .8)]))))
  ]);

  Widget _tableHeader() => Container(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: ['Date','Mortality','Total Eggs','Feed (kg)','FCR'].map((x) => _cell(x, x == 'Date' ? 1.2 : 1, header: true)).toList()));
  Widget _cell(String text, double flex, {bool header = false}) => Expanded(flex: (flex * 10).round(), child: Text(text, style: TextStyle(fontSize: header ? 10 : 11, color: header ? const Color(0xFF63766C) : const Color(0xFF253B31), fontWeight: header ? FontWeight.w700 : FontWeight.w600), overflow: TextOverflow.ellipsis));

  Widget _logRow(PoultryProvider p, dynamic log) => Container(margin: const EdgeInsets.only(top: 7), decoration: BoxDecoration(color: const Color(0xFFF7FAF8), borderRadius: BorderRadius.circular(11), border: Border.all(color: const Color(0xFFE1EAE5))), child: ListTile(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LogDetailScreen(log: log))), dense: true, leading: CircleAvatar(radius: 17, backgroundColor: const Color(0xFFE7F5EE), backgroundImage: (log.createdByUid != null && log.createdByUid == FirebaseAuth.instance.currentUser?.uid && FirebaseAuth.instance.currentUser?.photoURL != null) ? NetworkImage(FirebaseAuth.instance.currentUser!.photoURL!) : null, child: (log.createdByUid == null || log.createdByUid != FirebaseAuth.instance.currentUser?.uid || FirebaseAuth.instance.currentUser?.photoURL == null) ? Text((log.createdByName ?? 'U').trim().isEmpty ? 'U' : (log.createdByName ?? 'U').trim()[0].toUpperCase(), style: const TextStyle(color: Color(0xFF087A4F), fontWeight: FontWeight.w900)) : null), title: Text(DateFormat('dd MMM yyyy').format(log.date), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), subtitle: Text('Age ${log.flockAge}d  •  ${log.mortality} mortality  •  ${log.totalEggs} eggs', style: const TextStyle(fontSize: 10, color: Color(0xFF71837A))), trailing: Text('${p.layingPercentageFor(log).toStringAsFixed(1)}%', style: const TextStyle(color: Color(0xFF087A4F), fontWeight: FontWeight.w800))));

  Widget _quickActions() => LayoutBuilder(builder: (context, c) {
    final actions = [
      ('Add Daily Log', 'Record today’s data', Icons.calendar_month_outlined, const Color(0xFF0E9F6E), 2),
      ('Add Expense', 'Track expenses', Icons.payments_outlined, const Color(0xFFF59E0B), 3),
      ('Add Egg Sales', 'Record egg sales', Icons.egg_alt_outlined, const Color(0xFFF97316), 8),
      ('View Reports', 'Growth & analytics', Icons.bar_chart_outlined, const Color(0xFF0E9F6E), 1),
    ];
    final w = (c.maxWidth - 30) / 4;
    return Wrap(spacing: 10, runSpacing: 10, children: actions.map((a) => SizedBox(width: c.maxWidth < 650 ? (c.maxWidth - 10) / 2 : w, child: InkWell(onTap: () => _navigate(a.$5), child: AppCard(padding: const EdgeInsets.all(12), child: Row(children: [Container(width: 34, height: 34, decoration: BoxDecoration(color: a.$4.withValues(alpha: .11), borderRadius: BorderRadius.circular(9)), child: Icon(a.$3, color: a.$4, size: 19)), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(a.$1, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)), Text(a.$2, style: const TextStyle(fontSize: 9, color: Color(0xFF75867D)))]))]))))).toList());
  });

  Widget _error(String text) => Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFFFF1F0), borderRadius: BorderRadius.circular(11), border: Border.all(color: const Color(0xFFF5C2C0))), child: Text(text, style: const TextStyle(color: Color(0xFF9F2D28), fontSize: 12)));
  String _money(double value) => '₹${NumberFormat('#,##0').format(value)}';

  String _percent(double value) => '${NumberFormat('0.0').format(value * 100)}%';
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
  final List<double> values;
  final int selectedIndex;
  _PieChartPainter(this.values, {this.selectedIndex = -1});
  @override void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return;
    final r = size.shortestSide * .34;
    final center = Offset(size.width / 2, size.height / 2);
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * math.pi * 2;
      final p = Paint()..color = _pieColors[i % _pieColors.length];
      canvas.drawArc(Rect.fromCircle(center: center, radius: r), start, sweep, true, p);
      start += sweep;
    }
    final hole = Paint()..color = Colors.white;
    canvas.drawCircle(center, r * .52, hole);
  }
  @override bool shouldRepaint(covariant _PieChartPainter old) => old.values != values || old.selectedIndex != selectedIndex;
}

const _pieColors = <Color>[
  Color(0xFF2F80ED), Color(0xFFF59E0B), Color(0xFF34B66A), Color(0xFFF97316),
  Color(0xFF8B5CF6), Color(0xFF06B6D4), Color(0xFFEF4444), Color(0xFF64748B),
];
