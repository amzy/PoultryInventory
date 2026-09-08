import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/expense_sales_log.dart';
import '../providers/poultry_provider.dart';
import 'log_form_screen.dart';
import 'log_detail_screen.dart';
import 'expense_sales_form_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PoultryProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          appBar: AppBar(
            title: const Text('Poultry Inventory'),
            backgroundColor: const Color(0xFF10243D),
            elevation: 0,
            toolbarHeight: 56,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(40),
              child: SizedBox(
                height: 40,
                child: TabBar(
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorWeight: 2,
                  labelStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  unselectedLabelStyle: const TextStyle(fontSize: 12),
                  tabs: const [
                    Tab(icon: Icon(Icons.dashboard_outlined, size: 18), text: 'Dashboard'),
                    Tab(icon: Icon(Icons.receipt_long_outlined, size: 18), text: 'Expenses & Sales'),
                  ],
                ),
              ),
            ),
            actions: [
              IconButton(
                tooltip: provider.isGoogleSignedIn ? 'Sync Firebase' : 'Sign in with Google',
                icon: Icon(
                  provider.isGoogleSignedIn ? Icons.cloud_sync : Icons.login,
                  color: provider.isGoogleSignedIn ? Colors.white : const Color(0xFF67E8F9),
                  size: 21,
                ),
                onPressed: provider.isSigningIn
                    ? null
                    : () async {
                        await provider.signInToGoogle();
                      },
              ),
            ],
          ),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0F172A), Color(0xFF1E3A5F), Color(0xFF0F172A)],
              ),
            ),
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDashboard(provider),
                _buildExpenses(provider),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _tabController.index == 0
                      ? LogFormScreen()
                      : const ExpenseSalesFormScreen(),
                ),
              );
              if (result == true && mounted) {
                await provider.fetchLogs();
              }
            },
            tooltip: _tabController.index == 0 ? 'Add Daily Log' : 'Add Expense/Sale',
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Widget _buildDashboard(PoultryProvider provider) {
    return RefreshIndicator(
      onRefresh: provider.fetchLogs,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
        children: [
          _buildGoogleSyncCard(provider),
          if (provider.errorMessage != null) _buildError(provider.errorMessage!),
          _sectionTitle('Flock Overview', Icons.pets),
          const SizedBox(height: 10),
          _buildResponsiveCards([
            _metric('Current Birds', '${provider.totalBirds}', Icons.pets, const Color(0xFF22D3EE)),
            _metric('Mortality', '${provider.totalMortality}', Icons.warning_amber, const Color(0xFFFB7185)),
            _metric('Avg Laying', '${provider.averageLayingPercentage.toStringAsFixed(1)}%', Icons.egg_alt, const Color(0xFF4ADE80)),
            _metric('Avg FCR / Tray', provider.averageFcr.toStringAsFixed(2), Icons.speed, const Color(0xFFFBBF24)),
          ]),
          const SizedBox(height: 18),
          _sectionTitle('Production & Finance', Icons.analytics_outlined),
          const SizedBox(height: 10),
          _buildResponsiveCards([
            _metric('Total Eggs', NumberFormat('#,##0').format(provider.totalEggs), Icons.egg, const Color(0xFF67E8F9)),
            _metric('Total Trays', provider.totalTrays.toStringAsFixed(1), Icons.inventory_2, const Color(0xFFA78BFA)),
            _metric('Expenses', _money(provider.totalExpenses), Icons.payments_outlined, const Color(0xFFF87171)),
            _metric('Egg Sales', _money(provider.totalEggSales), Icons.point_of_sale, const Color(0xFF4ADE80)),
          ]),
          const SizedBox(height: 18),
          _buildFinanceSummary(provider),
          const SizedBox(height: 18),
          _sectionTitle('Laying Percentage Trend', Icons.show_chart),
          const SizedBox(height: 10),
          _buildLayingChart(provider),
          const SizedBox(height: 18),
          _sectionTitle('Recent Daily Logs', Icons.calendar_month),
          const SizedBox(height: 10),
          _buildRecentLogs(provider),
        ],
      ),
    );
  }

  Widget _buildExpenses(PoultryProvider provider) {
    final records = provider.expenseRecords;
    return RefreshIndicator(
      onRefresh: provider.fetchLogs,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
        children: [
          _buildGoogleSyncCard(provider),
          _buildResponsiveCards([
            _metric('Total Expenses', _money(provider.totalExpenses), Icons.payments, const Color(0xFFF87171)),
            _metric('Egg Sales', _money(provider.totalEggSales), Icons.sell, const Color(0xFF4ADE80)),
            _metric('Net', _money(provider.netExpense), Icons.account_balance_wallet, provider.netExpense >= 0 ? const Color(0xFFFBBF24) : const Color(0xFF4ADE80)),
          ]),
          const SizedBox(height: 18),
          _sectionTitle('Recent Expense & Sales Records', Icons.receipt_long),
          const SizedBox(height: 10),
          if (records.isEmpty)
            _emptyCard('No expense or sales records found.')
          else
            ...records.take(20).map(_expenseTile),
        ],
      ),
    );
  }

  Widget _buildGoogleSyncCard(PoultryProvider provider) {
    final connected = provider.isGoogleSignedIn;
    return Container(
      margin: const EdgeInsets.only(bottom: 14), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: connected ? const Color(0xFF16A34A).withOpacity(.12) : const Color(0xFF0EA5E9).withOpacity(.12), borderRadius: BorderRadius.circular(14), border: Border.all(color: connected ? const Color(0xFF4ADE80).withOpacity(.30) : const Color(0xFF67E8F9).withOpacity(.30))),
      child: Row(children: [Icon(connected ? Icons.cloud_done : Icons.cloud_off, color: connected ? const Color(0xFF4ADE80) : const Color(0xFF67E8F9), size: 26), const SizedBox(width:10), Expanded(child: Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(connected?'Firebase Connected':'Firebase Not Connected',style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w700,fontSize:13)),const SizedBox(height:3),Text(connected?'Data is stored securely in Cloud Firestore.':'Sign in with Google to load and save farm data.',style:const TextStyle(color:Colors.white60,fontSize:11))])), const SizedBox(width:8), OutlinedButton.icon(onPressed: provider.isSigningIn?null:provider.signInToGoogle, icon: provider.isSigningIn?const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2)):Icon(connected?Icons.sync:Icons.login,size:17), label:Text(provider.isSigningIn?'Connecting…':connected?'Sync':'Sign in'))]),
    );
  }

  Widget _sectionTitle(String title, IconData icon) => Row(
        children: [
          Icon(icon, color: const Color(0xFF67E8F9), size: 20),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
        ],
      );

  Widget _buildResponsiveCards(List<Widget> cards) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth >= 1000 ? 4 : constraints.maxWidth >= 600 ? 2 : 1;
        final width = (constraints.maxWidth - ((count - 1) * 10)) / count;
        return Wrap(spacing: 10, runSpacing: 10, children: cards.map((c) => SizedBox(width: width, child: c)).toList());
      },
    );
  }

  Widget _metric(String title, String value, IconData icon, Color accent) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(.14)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: accent.withOpacity(.14), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: accent, size: 21),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60, fontSize: 11)),
            const SizedBox(height: 3),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: accent, fontSize: 20, fontWeight: FontWeight.w800)),
          ])),
        ],
      ),
    );
  }

  Widget _buildFinanceSummary(PoultryProvider provider) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white.withOpacity(.06), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(.12))),
      child: Row(
        children: [
          Expanded(child: _financeItem('Expenses', provider.totalExpenses, const Color(0xFFF87171))),
          Container(width: 1, height: 42, color: Colors.white12),
          Expanded(child: _financeItem('Egg Sales', provider.totalEggSales, const Color(0xFF4ADE80))),
          Container(width: 1, height: 42, color: Colors.white12),
          Expanded(child: _financeItem('Net', provider.netExpense, provider.netExpense >= 0 ? const Color(0xFFFBBF24) : const Color(0xFF4ADE80))),
        ],
      ),
    );
  }

  Widget _financeItem(String label, double value, Color color) => Column(children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
        const SizedBox(height: 4),
        Text(_money(value), style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
      ]);

  Widget _buildRecentLogs(PoultryProvider provider) {
    if (provider.logs.isEmpty) return _emptyCard('No daily log records found.');
    return Column(children: provider.logs.take(8).map((log) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(color: Colors.white.withOpacity(.06), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(.10))),
        child: ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          leading: CircleAvatar(radius: 17, backgroundColor: const Color(0xFF06B6D4).withOpacity(.15), child: const Icon(Icons.calendar_today, size: 16, color: Color(0xFF67E8F9))),
          title: Text(DateFormat('dd MMM yyyy').format(log.date), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
          subtitle: Text('Age ${log.flockAge}d  •  Eggs ${log.totalEggs}  •  Feed ${log.feedConsumed.toStringAsFixed(1)} kg', style: const TextStyle(color: Colors.white60, fontSize: 11)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${log.layingPercentage.toStringAsFixed(1)}%', style: const TextStyle(color: Color(0xFF4ADE80), fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(width: 5),
              const Icon(Icons.chevron_right, color: Colors.white38, size: 20),
            ],
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => LogDetailScreen(log: log)),
            );
          },
        ),
      );
    }).toList());
  }

  Widget _expenseTile(ExpenseSalesLog record) {
    final isSale = record.category == 'Egg_Sales';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: Colors.white.withOpacity(.06), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(.10))),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(radius: 17, backgroundColor: (isSale ? const Color(0xFF4ADE80) : const Color(0xFFF87171)).withOpacity(.14), child: Icon(isSale ? Icons.sell : Icons.receipt, size: 17, color: isSale ? const Color(0xFF4ADE80) : const Color(0xFFF87171))),
        title: Text(record.description.isEmpty ? record.category : record.description, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
        subtitle: Text('${DateFormat('dd MMM yyyy').format(record.date)}  •  ${record.category}  •  Qty ${record.quantity}', style: const TextStyle(color: Colors.white60, fontSize: 10)),
        trailing: Text(_money(record.amount), style: TextStyle(color: isSale ? const Color(0xFF4ADE80) : const Color(0xFFF87171), fontWeight: FontWeight.bold, fontSize: 13)),
      ),
    );
  }

  Widget _emptyCard(String message) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white.withOpacity(.05), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(.10))),
        child: Center(child: Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, fontSize: 13))),
      );

  Widget _buildError(String message) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.red.withOpacity(.12), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.red.withOpacity(.3))),
        child: Text(message, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      );

  Widget _buildLayingChart(PoultryProvider provider) {
    final values = provider.logs.take(14).toList().reversed.map((e) => e.layingPercentage).toList();
    if (values.isEmpty) return _emptyCard('No laying percentage data available.');
    return Container(
      height: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white.withOpacity(.06), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(.10))),
      child: CustomPaint(painter: _LayingPercentageChartPainter(values: values), child: const SizedBox.expand()),
    );
  }

  String _money(double value) => '₹${NumberFormat('#,##0.00').format(value)}';
}

class _LayingPercentageChartPainter extends CustomPainter {
  final List<double> values;
  _LayingPercentageChartPainter({required this.values});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final grid = Paint()..color = Colors.white.withOpacity(.10)..strokeWidth = 1;
    final line = Paint()..color = const Color(0xFF22D3EE)..strokeWidth = 3..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final dot = Paint()..color = const Color(0xFF67E8F9);
    for (int i = 0; i <= 4; i++) {
      final y = 12 + (size.height - 30) * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final minV = values.reduce((a,b) => a < b ? a : b);
    final maxV = values.reduce((a,b) => a > b ? a : b);
    final span = (maxV - minV).abs() < .001 ? 1.0 : maxV - minV;
    final path = ui.Path();
    for (int i = 0; i < values.length; i++) {
      final x = values.length == 1 ? size.width / 2 : i * size.width / (values.length - 1);
      final y = 12 + (size.height - 30) * (1 - ((values[i] - minV) / span));
      final p = Offset(x, y);
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
      canvas.drawCircle(p, 4, dot);
    }
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant _LayingPercentageChartPainter oldDelegate) => oldDelegate.values != values;
}
