import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/expense_sales_log.dart';
import '../providers/poultry_provider.dart';
import '../widgets/app_shell.dart';
import 'expense_sales_form_screen.dart';

class ExpenseRecordsScreen extends StatelessWidget {
  final bool embedded;
  final VoidCallback? onBack;
  final ValueChanged<ExpenseSalesLog>? onEdit;
  const ExpenseRecordsScreen({super.key, this.embedded = false, this.onBack, this.onEdit});

  @override
  Widget build(BuildContext context) {
    final content = Consumer<PoultryProvider>(
      builder: (context, provider, _) {
        final records = provider.expenseRecords;
        if (records.isEmpty) {
          return const Center(child: Text('No transactions found.', style: TextStyle(color: Color(0xFF71827A))));
        }
        final groups = <String, double>{};
        for (final r in records.where((r) => r.transactionType != 'credit')) {
          final key = r.mainCategory.trim().isEmpty ? 'Uncategorized' : r.mainCategory.trim();
          groups[key] = (groups[key] ?? 0) + r.netTotal;
        }
        final sortedGroups = groups.entries.toList()..sort((a,b) => b.value.compareTo(a.value));
        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
          children: [
            AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Transaction Summary', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF162A21))),
              const SizedBox(height: 5),
              const Text('Overview of all recorded expenses and earnings.', style: TextStyle(fontSize: 11, color: Color(0xFF75867D))),
              const SizedBox(height: 12),
              ...sortedGroups.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Expanded(child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                  Text('₹${NumberFormat('#,##0.00').format(e.value)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF0E9F6E))),
                ]),
              )),
            ])),
            const SizedBox(height: 14),
            AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Expenses by Subcategory', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF162A21))),
              const SizedBox(height: 5),
              const Text('Same subcategory names are grouped across all Main Categories.', style: TextStyle(fontSize: 11, color: Color(0xFF75867D))),
              const SizedBox(height: 12),
              ..._subcategoryGroups(records).entries.map((e) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
                Expanded(child: Text(e.key.replaceAll('_', ' '), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                Text('₹${NumberFormat('#,##0.00').format(e.value)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF0E9F6E))),
              ]))),
            ])),
            const SizedBox(height: 14),
            AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Expenses by Account', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF162A21))),
              const SizedBox(height: 5),
              const Text('See who paid for the transactions.', style: TextStyle(fontSize: 11, color: Color(0xFF75867D))),
              const SizedBox(height: 12),
              ..._accountGroups(records).entries.map((e) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
                Expanded(child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                Text('₹${NumberFormat('#,##0.00').format(e.value)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF0E9F6E))),
              ]))),
            ])),
            const SizedBox(height: 14),
            AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('All Transactions', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF162A21))),
              const SizedBox(height: 8),
              ...records.map((record) => _recordTile(context, record)),
            ])),
          ],
        );
      },
    );
    if (embedded) return content;
    return PoultryAppShell(selectedIndex: 0, title: 'Transactions', subtitle: 'View and manage all farm financial transactions', onBack: onBack ?? () => Navigator.maybePop(context), child: content);
  }

  Map<String, double> _subcategoryGroups(List<ExpenseSalesLog> records) {
    final groups = <String, double>{};
    for (final r in records.where((r) => r.transactionType != 'credit')) {
      final key = r.category.trim().isEmpty ? 'Uncategorized' : r.category.trim();
      groups[key] = (groups[key] ?? 0) + r.netTotal;
    }
    return Map.fromEntries(groups.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
  }

  Map<String, double> _accountGroups(List<ExpenseSalesLog> records) {
    final groups = <String, double>{};
    for (final r in records.where((r) => r.transactionType != 'credit')) {
      final key = r.account.trim().isEmpty ? 'Unassigned' : r.account.trim();
      groups[key] = (groups[key] ?? 0) + r.netTotal;
    }
    return Map.fromEntries(groups.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
  }

  Widget _recordTile(BuildContext context, ExpenseSalesLog record) {
    final isSale = record.transactionType == 'credit';
    final amount = record.netTotal;
    return Container(
      margin: const EdgeInsets.only(top: 7),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAF8),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFFE1EAE5)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isSale ? const Color(0xFFE7F5EE) : const Color(0xFFFFF3E7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isSale ? Icons.trending_up_rounded : Icons.trending_down_rounded,
              color: isSale ? const Color(0xFF087A4F) : const Color(0xFFB45309),
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        record.description.trim().isEmpty
                            ? record.category.replaceAll('_', ' ')
                            : record.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF243A30)),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: isSale ? const Color(0xFFE7F5EE) : const Color(0xFFFFF3E7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isSale ? 'EARNING' : 'EXPENSE',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          color: isSale ? const Color(0xFF087A4F) : const Color(0xFFB45309),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${record.mainCategory} • ${record.category.replaceAll('_', ' ')} • ${record.account.isEmpty ? 'Unassigned' : record.account}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: Color(0xFF71827A)),
                ),
                const SizedBox(height: 2),
                Text(
                  '${DateFormat('dd MMM yyyy').format(record.date)}${record.createdByName == null ? '' : ' • Added by ${record.createdByName}'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 9, color: Color(0xFF71827A)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isSale ? '+' : '−'}₹${NumberFormat('#,##0.00').format(amount)}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isSale ? const Color(0xFF087A4F) : const Color(0xFFB45309),
                ),
              ),
              if (record.freightCharge > 0)
                Text(
                  'Net ₹${NumberFormat('#,##0.00').format(record.netTotal)}',
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF087A4F)),
                ),
            ],
          ),
          const SizedBox(width: 2),
          IconButton(
            tooltip: 'Edit transaction',
            onPressed: () => _edit(context, record),
            icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF0E9F6E)),
          ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, ExpenseSalesLog record) async {
    if (onEdit != null) {
      onEdit!(record);
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExpenseSalesFormScreen(
          existingRecord: record,
        ),
      ),
    );
  }

}
