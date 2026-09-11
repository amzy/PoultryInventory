import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/expense_sales_log.dart';
import '../providers/poultry_provider.dart';
import '../widgets/app_shell.dart';
import '../services/farm_config.dart';
import '../services/bv300_analytics_service.dart';
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
  bool _showTransactions = false;
  ExpenseSalesLog? _editingTransaction;
  Future<List<Map<String, dynamic>>>? _pendingInvitationsFuture;
  String _expenseLoadRequestedForFlock = '';
  bool _expenseLoadScheduled = false;

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
      if (mounted) {
        setState(() => _pendingInvitationsFuture = null);
        _refreshingAfterResume = false;
      }
    });
  }

  void _navigate(int index) {
    final provider = context.read<PoultryProvider>();
    if (!provider.isAdmin && index != 0 && index != 2 && index != 11) {
      const gated = <int, String>{1: 'reports', 3: 'medical', 4: 'feed', 5: 'grit', 6: 'tray', 7: 'otherExpenses', 8: 'eggSales', 9: 'suppliers'};
      final feature = gated[index];
      if (feature != null && !provider.hasFeature(feature)) return;
    }
    if (_selectedIndex == index && !_showTransactions && _editingTransaction == null) return;
    setState(() {
      _selectedIndex = index;
      _showTransactions = false;
      _editingTransaction = null;
    });
  }

  void _backToDashboard() {
    setState(() {
      _selectedIndex = 0;
      _showTransactions = false;
      _editingTransaction = null;
    });
  }

  void _openTransactionsInShell() {
    setState(() {
      _selectedIndex = 0;
      _showTransactions = true;
      _editingTransaction = null;
    });
  }

  void _openTransactionForEdit(ExpenseSalesLog record) {
    setState(() {
      _selectedIndex = 0;
      _showTransactions = true;
      _editingTransaction = record;
    });
  }

  Widget _currentContent(PoultryProvider provider) {
    if (_editingTransaction != null) {
      return ExpenseSalesFormScreen(
        existingRecord: _editingTransaction,
        embedded: true,
        onEmbeddedBack: () => setState(() => _editingTransaction = null),
        key: ValueKey('edit-transaction-${_editingTransaction!.id}'),
      );
    }

    if (_showTransactions) {
      return ExpenseRecordsScreen(
        embedded: true,
        onBack: _backToDashboard,
        onEdit: _openTransactionForEdit,
        key: const ValueKey('transactions'),
      );
    }

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
        headerOverride: (_selectedIndex == 0 && !_showTransactions && _editingTransaction == null && provider.activeFlock != null)
            ? DashboardHeader(
                flockName: provider.activeFlock!.name,
                startDate: provider.activeFlock!.startDate,
                age: FarmConfig.flockAgeOnDate(DateTime.now(), startDate: provider.activeFlock!.startDate),
              )
            : null,
        onNavigate: _navigate,
        onBack: _editingTransaction != null
            ? () => setState(() => _editingTransaction = null)
            : _showTransactions
                ? _backToDashboard
                : _selectedIndex == 11
                    ? _backToDashboard
                    : null,
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
    if (_editingTransaction != null) return 'Edit Expense';
    if (_showTransactions) return 'Transactions';
    if (_selectedIndex == 0) return 'Dashboard';
    if (_selectedIndex == 1) return 'Reports';
    if (_selectedIndex == 2) return 'Add Daily Log';
    if (_selectedIndex == 9) return 'Suppliers';
    if (_selectedIndex == 10) return 'Settings';
    if (_selectedIndex == 11) return 'My Profile';
    return 'Add ${category == 'Egg Sales' ? 'Egg Sales' : 'Expense'}';
  }

  String _pageSubtitle() {
    if (_editingTransaction != null) return 'Modify an existing financial record';
    if (_showTransactions) return 'View and manage all farm financial transactions';
    if (_selectedIndex == 0) return 'Overview of your poultry farm';
    if (_selectedIndex == 1) return 'Production, mortality and financial analysis';
    if (_selectedIndex == 2) return 'Track daily flock data';
    if (_selectedIndex == 9) return 'Supplier directory';
    if (_selectedIndex == 10) return 'App preferences, data tools and administration';
    if (_selectedIndex == 11) return 'Personal account information';
    return 'Record farm financial activity';
  }

  void _ensureDashboardFinancialData(PoultryProvider provider) {
    if (!provider.hasFlock || !provider.hasFeature('expenses')) return;
    final flockId = provider.activeFlockId;
    if (flockId.isEmpty || _expenseLoadRequestedForFlock == flockId || _expenseLoadScheduled) return;
    _expenseLoadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _expenseLoadScheduled = false;
      if (!mounted) return;
      final current = context.read<PoultryProvider>();
      if (!current.hasFlock || current.activeFlockId != flockId || !current.hasFeature('expenses')) return;
      _expenseLoadRequestedForFlock = flockId;
      await current.loadExpenseRecords();
      if (mounted) setState(() {});
    });
  }

  Widget _dashboardBody(PoultryProvider provider) {
    _ensureDashboardFinancialData(provider);
    return RefreshIndicator(
      color: const Color(0xFF087A4F),
      onRefresh: provider.fetchLogs,
      child: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1050;
        return ListView(
          padding: EdgeInsets.fromLTRB(wide ? 24 : 14, 8, wide ? 24 : 14, 28),
          children: [
            if (!provider.isAdmin) _memberInvitationsCard(provider),
            ..._buildDashboardGroups(provider, wide),
          ],
        );
      }),
    );
  }

  Widget _memberInvitationsCard(PoultryProvider provider) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _pendingInvitationsFuture ??= provider.pendingInvitations(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) return const SizedBox.shrink();
        if (snapshot.hasError) {
          return Card(
            margin: const EdgeInsets.only(bottom: 14),
            elevation: 0,
            child: ListTile(
              leading: const Icon(Icons.mail_outline),
              title: const Text('Unable to load flock invitations'),
              subtitle: const Text('Refresh the dashboard after deploying the latest Firestore rules.'),
              trailing: IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => setState(() => _pendingInvitationsFuture = null),
              ),
            ),
          );
        }
        final invitations = snapshot.data ?? const <Map<String, dynamic>>[];
        if (invitations.isEmpty) return const SizedBox.shrink();
        return Card(
          margin: const EdgeInsets.only(bottom: 14),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFDCE9E2))),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [Icon(Icons.mail_outline, color: Color(0xFF087A4F)), SizedBox(width: 8), Text('Flock Invitations', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16))]),
              const SizedBox(height: 8),
              ...invitations.map((invite) {
                final flockId = invite['flockId']?.toString() ?? '';
                final invitationId = invite['invitationId']?.toString() ?? '';
                final flockName = invite['flockName']?.toString() ?? 'Flock';
                final declineCount = (invite['declineCount'] as num?)?.toInt() ?? 0;
                return Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: const Color(0xFFF7FBF9)),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    const Icon(Icons.pets_outlined, color: Color(0xFF087A4F)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(flockName, style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(declineCount > 0 ? 'Invitation resent after your first decline.' : 'You have been invited to join this flock.', style: const TextStyle(fontSize: 11, color: Color(0xFF667970))),
                    ])),
                    TextButton(onPressed: () async {
                      try { await provider.declineFlockInvitation(flockId, invitationId); if (mounted) setState(() => _pendingInvitationsFuture = null); }
                      catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to decline invitation: $e'))); }
                    }, child: Text(declineCount >= 1 ? 'Decline & Report' : 'Decline')),
                    const SizedBox(width: 4),
                    FilledButton(onPressed: () async {
                      try { await provider.acceptFlockInvitation(flockId, invitationId); if (mounted) setState(() => _pendingInvitationsFuture = null); }
                      catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to accept invitation: $e'))); }
                    }, child: const Text('Accept')),
                  ]),
                );
              }),
            ]),
          ),
        );
      },
    );
  }

  // Dashboard artifacts are intentionally grouped so visibility/order can later be
  // controlled by an admin without changing the individual artifact widgets.
  List<Widget> _buildDashboardGroups(PoultryProvider provider, bool wide) {
    if (!provider.hasFlock) {
      return [
        AppCard(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Icon(Icons.pets_outlined, size: 42, color: Color(0xFF0E9F6E)),
                const SizedBox(height: 10),
                const Text('No flock selected', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                Text(
                  provider.isAdmin ? 'Create a flock from Settings → Flock Configuration.' : 'Accept a flock invitation to start viewing flock data.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF71827A)),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    const groups = [
      // Critical, cheap-to-render data stays first: flock + daily log metrics.
      DashboardArtifactGroupConfig(DashboardArtifactGroup.flockContext),
      DashboardArtifactGroupConfig(DashboardArtifactGroup.overview),
      // Keep the dashboard intentionally lightweight: only the two requested
      // charts are rendered. Other analytics/financial breakdowns live in Reports.
      DashboardArtifactGroupConfig(DashboardArtifactGroup.analytics),
      DashboardArtifactGroupConfig(DashboardArtifactGroup.activity),
      DashboardArtifactGroupConfig(DashboardArtifactGroup.actions),
    ];

    final widgets = <Widget>[];
    for (final config in groups) {
      if (!config.visible) continue;
      final groupWidgets = switch (config.group) {
        DashboardArtifactGroup.flockContext => [
            if (provider.errorMessage != null) _error(provider.errorMessage!),
          ],
        DashboardArtifactGroup.overview => [
            _metrics(provider, wide),
          ],
        DashboardArtifactGroup.analytics => [
            if (wide)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: _eggProductionChart(provider)),
                if (provider.hasFeature('expenses')) ...[
                  const SizedBox(width: 14),
                  Expanded(child: _financialCharts(provider)),
                ],
              ])
            else ...[
              _eggProductionChart(provider),
              if (provider.hasFeature('expenses')) ...[
                const SizedBox(height: 14),
                _financialCharts(provider),
              ],
            ],
          ],
        // Kept explicit for exhaustive matching; additional financial charts
        // are intentionally not rendered on the dashboard.
        DashboardArtifactGroup.financial => const <Widget>[],
        DashboardArtifactGroup.activity => [
            _performanceSuggestions(provider),
            const SizedBox(height: 14),
            _recentLogs(provider),
            if (provider.hasFeature('expenses')) ...[
              const SizedBox(height: 14),
              _recentTransactionsSection(provider),
            ],
          ],
        DashboardArtifactGroup.actions => [
            _quickActions(provider),
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
    return '${grit.toStringAsFixed(0)} kg • ${percentage.toStringAsFixed(2)}%';
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

  Widget _eggProductionChart(PoultryProvider p) => _EggProductionChart(provider: p);

  Widget _financialCharts(PoultryProvider p) => _FinancialPieChart(provider: p);

  Widget _recentTransactionsSection(PoultryProvider p) {
    if (p.expenseRecordsLoading) {
      return AppCard(child: const SizedBox(height: 180, child: Center(child: CircularProgressIndicator(strokeWidth: 2))));
    }
    if (p.expenseRecordsError != null) return _recentTransactions(p);
    return _recentTransactions(p);
  }


  void _openTransactions(BuildContext context) {
    _openTransactionsInShell();
  }

  Widget _recentTransactions(PoultryProvider p) {
    final records = p.expenseRecords;

    if (p.expenseRecordsError != null) {
      return AppCard(
        child: const Padding(
          padding: EdgeInsets.all(18),
          child: Center(child: Text('Unable to load recent transactions. Pull to refresh and try again.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Color(0xFF71827A)))),
        ),
      );
    }

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

  Widget _performanceSuggestions(PoultryProvider p) {
    final a = p.bv300Analytics;
    if (a.ageWeek <= 0) return const SizedBox.shrink();
    final critical = a.indicators.where((i) => i.status == 'critical').toList();
    final suggestions = <String>[...a.suggestions];
    for (final item in critical) {
      suggestions.insert(0, item.message);
    }
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.auto_awesome_outlined, color: Color(0xFF087A4F)),
          const SizedBox(width: 8),
          const Expanded(child: Text('Flock Performance & Suggestions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
          Text('Week ${a.ageWeek}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF087A4F))),
        ]),
        const SizedBox(height: 4),
        Text(a.phase, style: const TextStyle(fontSize: 10, color: Color(0xFF71827A))),
        const SizedBox(height: 10),
        if (a.indicators.isEmpty)
          const Text("Add today's daily log to compare actual flock performance with the applicable BV300 weekly standards.", style: TextStyle(fontSize: 11, color: Color(0xFF667970)))
        else ...[
          ...a.indicators.map((i) => _indicatorTile(i, a.ageWeek, a.phase)),
          if (suggestions.isNotEmpty) ...[
            const Divider(height: 18),
            ...suggestions.take(4).map((text) => Padding(padding: const EdgeInsets.only(bottom: 7), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('• ', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF087A4F))), Expanded(child: Text(text, style: const TextStyle(fontSize: 11, color: Color(0xFF4F6259))))]))),
          ],
        ],
      ]),
    );
  }

  Widget _indicatorTile(BV300MetricIndicator i, int week, String phase) {
    final critical = i.status == 'critical';
    final warning = i.status == 'warning';
    final icon = critical ? Icons.warning_amber_rounded : warning ? Icons.info_outline : Icons.check_circle_outline;
    final accent = critical ? const Color(0xFFC2410C) : warning ? const Color(0xFFD97706) : const Color(0xFF087A4F);
    final background = critical ? const Color(0xFFFFF1F0) : warning ? const Color(0xFFFFF8E8) : const Color(0xFFF1FAF5);
    String fmt(double? value) => value == null ? '' : value.toStringAsFixed(i.unit == '%' ? 1 : 2);
    final range = i.min != null && i.max != null
        ? '${fmt(i.min)}–${fmt(i.max)} ${i.unit}'
        : i.min != null
            ? '≥ ${fmt(i.min)} ${i.unit}'
            : '≤ ${fmt(i.max)} ${i.unit}';
    final text = i.hasStandard ? '${i.metric}: ${fmt(i.actual)} ${i.unit} • Standard $range' : i.message;
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(10)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 17, color: accent),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: accent)),
            const SizedBox(height: 2),
            Text(i.message, style: const TextStyle(fontSize: 10, color: Color(0xFF667970))),
          ]),
        ),
        const SizedBox(width: 4),
        IconButton(
          tooltip: 'View expected standard',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          icon: const Icon(Icons.info_outline, size: 18, color: Color(0xFF087A4F)),
          onPressed: () => _showExpectedStandard(i, week, phase),
        ),
      ]),
    );
  }

  void _showExpectedStandard(BV300MetricIndicator indicator, int week, String phase) {
    final geometry = BV300AnalyticsService.eggGeometryForWeek(week);
    final lighting = BV300AnalyticsService.lightingForWeek(week);
    final base = BV300AnalyticsService.standardForWeek(week);

    String fmt(double? value, {int decimals = 1}) {
      if (value == null) return '—';
      return value.toStringAsFixed(value.truncateToDouble() == value ? 0 : decimals);
    }

    String standardText() {
      switch (indicator.metric) {
        case 'HDEP':
          final economic = BV300AnalyticsService.economicStandardFor('HDEP');
          if (week >= 23 && week <= 35) return economic?.target ?? '95.0–98.0% (Weeks 23–35)';
          return 'The supplied HDEP target is 95.0–98.0% for Weeks 23–35.';
        case 'HHPE':
          final economic = BV300AnalyticsService.economicStandardFor('HHPE');
          return economic?.target ?? '330+ eggs by Week 72';
        case 'Laying':
          if (base?.layingMin != null) return '${fmt(base!.layingMin)}–${fmt(base.layingMax)} % hen-day production';
          return 'No laying % range supplied for Week $week.';
        case 'Livability':
          if (base?.livabilityMin != null) return '≥ ${fmt(base!.livabilityMin)} %';
          return 'No livability target supplied for Week $week.';
        case 'Egg weight':
          if (geometry != null) return '${fmt(geometry.eggWeightMin)}–${fmt(geometry.eggWeightMax)} g/egg';
          return 'No egg-weight range supplied for Week $week.';
        case 'Egg mass':
          if (geometry != null) return '${fmt(geometry.eggMassMin)}–${fmt(geometry.eggMassMax)} g/hen/day';
          return 'No egg-mass range supplied for Week $week.';
        case 'FCR / egg mass':
          return BV300AnalyticsService.economicStandardFor('FCR per kg Egg Mass')?.target ?? '2.10–2.15 kg feed/kg egg mass';
        case 'Water-to-Feed Ratio':
          return '2.0:1 at 21°C';
        default:
          return indicator.hasStandard ? '${fmt(indicator.min)}–${fmt(indicator.max)} ${indicator.unit}' : 'No standard supplied.';
      }
    }

    final notes = <String>[];
    if (indicator.metric == 'Egg weight' && geometry != null) {
      notes.add('Egg profile: ${geometry.ratioTarget}.');
      notes.add('Shell thickness: ${fmt(geometry.shellMin, decimals: 2)}–${fmt(geometry.shellMax, decimals: 2)} mm.');
    }
    if (indicator.metric == 'Egg mass') {
      notes.add('Calculated as hen-day laying % × egg weight ÷ 100.');
    }
    if (indicator.metric == 'HDEP') {
      notes.add('Drastic action limit: drop of >3% within any 48-hour window.');
    }
    if (indicator.metric == 'HHPE') {
      notes.add('Drastic action limit: deviation of >15 eggs from the cumulative curve. The supplied matrix does not include intermediate weekly curve values.');
    }
    if (indicator.metric == 'FCR / egg mass') {
      notes.add('Drastic action limit: >2.35, indicating extreme feed wastage or egg-weight tracking errors.');
    }
    if (indicator.metric == 'Water-to-Feed Ratio') {
      notes.add('Target is specified at 21°C. Drastic action limit: >3.5:1, alerting to systemic heat stress or severe water-line leaks.');
    }
    if (indicator.metric == 'Laying' && lighting != null) {
      notes.add('Lighting target: ${fmt(lighting.lightHours)} h/day, ${fmt(lighting.luxMin, decimals: 0)}–${fmt(lighting.luxMax, decimals: 0)} lux.');
    }

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.info_outline, color: Color(0xFF087A4F)),
          const SizedBox(width: 8),
          Expanded(child: Text('${indicator.metric} — Week $week')),
        ]),
        content: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(phase, style: const TextStyle(fontSize: 12, color: Color(0xFF71827A))),
            const SizedBox(height: 14),
            const Text('Expected standard', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
            const SizedBox(height: 5),
            Text(standardText(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF087A4F))),
            const SizedBox(height: 14),
            const Text('Your actual', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
            const SizedBox(height: 5),
            Text('${indicator.actual.toStringAsFixed(indicator.unit == '%' ? 1 : 2)} ${indicator.unit}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text('Additional guidance', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              ...notes.map((note) => Padding(padding: const EdgeInsets.only(bottom: 5), child: Text('• $note', style: const TextStyle(fontSize: 11, color: Color(0xFF53675E))))),
            ],
          ]),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  Widget _quickActions(PoultryProvider p) => LayoutBuilder(builder: (context, c) {
    final actions = [
      ('Add Daily Log', 'Record today’s data', Icons.calendar_month_outlined, const Color(0xFF0E9F6E), 2),
      ('Add Expense', 'Track expenses', Icons.payments_outlined, const Color(0xFFF59E0B), 3),
      ('Add Egg Sales', 'Record egg sales', Icons.egg_alt_outlined, const Color(0xFFF97316), 8),
      ('View Reports', 'Growth & analytics', Icons.bar_chart_outlined, const Color(0xFF0E9F6E), 1),
    ];
    final visibleActions = actions.where((a) => a.$5 == 2 || a.$5 == 0 || p.isAdmin || (a.$5 == 1 && p.hasFeature('reports')) || (a.$5 == 3 && p.hasFeature('expenses')) || (a.$5 == 8 && p.hasFeature('eggSales'))).toList();
    final w = (c.maxWidth - 30) / 4;
    return Wrap(spacing: 10, runSpacing: 10, children: visibleActions.map((a) => SizedBox(width: c.maxWidth < 650 ? (c.maxWidth - 10) / 2 : w, child: InkWell(onTap: () => _navigate(a.$5), child: AppCard(padding: const EdgeInsets.all(12), child: Row(children: [Container(width: 34, height: 34, decoration: BoxDecoration(color: a.$4.withValues(alpha: .11), borderRadius: BorderRadius.circular(9)), child: Icon(a.$3, color: a.$4, size: 19)), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(a.$1, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)), Text(a.$2, style: const TextStyle(fontSize: 9, color: Color(0xFF75867D)))]))]))))).toList());
  });

  Widget _error(String text) => Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFFFF1F0), borderRadius: BorderRadius.circular(11), border: Border.all(color: const Color(0xFFF5C2C0))), child: Text(text, style: const TextStyle(color: Color(0xFF9F2D28), fontSize: 12)));
  String _money(double value) => '₹${NumberFormat('#,##0').format(value)}';

}


class _EggProductionChart extends StatelessWidget {
  final PoultryProvider provider;
  const _EggProductionChart({required this.provider});

  @override
  Widget build(BuildContext context) {
    final logs = provider.logs.take(14).toList().reversed.toList();
    final values = logs.map((e) => e.totalEggs.toDouble()).toList();
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Egg Production', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF12251D))),
        const SizedBox(height: 4),
        const Text('Daily eggs over the latest 14 logs', style: TextStyle(fontSize: 10, color: Color(0xFF71827A))),
        const SizedBox(height: 10),
        SizedBox(height: 235, child: values.isEmpty
            ? const Center(child: Text('No daily log data yet.', style: TextStyle(fontSize: 11, color: Color(0xFF71827A))))
            : CustomPaint(painter: _BarChartPainter(values), child: const SizedBox.expand())),
        const SizedBox(height: 2),
        const Center(child: Text('eggs', style: TextStyle(fontSize: 9, color: Color(0xFF71827A)))),
      ]),
    );
  }
}

class _FinancialPieChart extends StatelessWidget {
  final PoultryProvider provider;
  const _FinancialPieChart({required this.provider});

  @override
  Widget build(BuildContext context) {
    if (provider.expenseRecordsLoading && !provider.expenseRecordsLoaded) {
      return AppCard(child: const SizedBox(height: 300, child: Center(child: CircularProgressIndicator(strokeWidth: 2))));
    }
    if (!provider.expenseRecordsLoaded) {
      return AppCard(
        child: const SizedBox(
          height: 300,
          child: Center(
            child: Text(
              'Financial data is not available yet.',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF71827A),
              ),
            ),
          ),
        ),
      );
    }
    if (provider.expenseRecordsError != null) {
      return AppCard(
        child: const SizedBox(
          height: 300,
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text('Unable to load Expenses / Earnings. Pull to refresh and try again.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Color(0xFF71827A))),
            ),
          ),
        ),
      );
    }

    double expenses = 0;
    double earnings = 0;
    for (final record in provider.expenseRecords) {
      if (record.transactionType == 'credit') {
        earnings += record.netTotal;
      } else {
        expenses += record.netTotal;
      }
    }

    final total = expenses + earnings;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Expenses / Earnings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF12251D))),
        const SizedBox(height: 4),
        const Text('Overall financial split', style: TextStyle(fontSize: 10, color: Color(0xFF71827A))),
        const SizedBox(height: 8),
        SizedBox(height: 235, child: total <= 0
            ? const Center(child: Text('No financial transactions yet.', style: TextStyle(fontSize: 11, color: Color(0xFF71827A))))
            : Row(children: [
                Expanded(child: CustomPaint(painter: _SimplePiePainter([expenses, earnings]), child: const SizedBox.expand())),
                const SizedBox(width: 16),
                Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _legend('Expenses', expenses, const Color(0xFFF59E0B)),
                  const SizedBox(height: 14),
                  _legend('Earnings', earnings, const Color(0xFF087A4F)),
                ])),
              ])),
      ]),
    );
  }

  Widget _legend(String label, double value, Color color) => Row(children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 8),
    Expanded(child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
    Text(_money(value), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
  ]);

  String _money(double value) => '₹${NumberFormat('#,##0').format(value)}';
}

class _SimplePiePainter extends CustomPainter {
  final List<double> values;
  _SimplePiePainter(this.values);

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (sum, value) => sum + value);
    if (total <= 0) return;
    final radius = size.shortestSide * .34;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);
    var start = -math.pi / 2;
    const colors = [Color(0xFFF59E0B), Color(0xFF087A4F)];
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * math.pi * 2;
      canvas.drawArc(rect, start, sweep, true, Paint()..color = colors[i]);
      start += sweep;
    }
    canvas.drawCircle(center, radius * .52, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _SimplePiePainter old) => old.values != values;
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
