import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/expense_sales_log.dart';
import '../providers/poultry_provider.dart';
import '../widgets/app_shell.dart';

class ExpenseRecordsScreen extends StatelessWidget {
  final bool embedded;
  const ExpenseRecordsScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final content = Consumer<PoultryProvider>(
      builder: (context, provider, _) {
        final records = provider.expenseRecords;
        if (records.isEmpty) {
          return const Center(child: Text('No expense records found.', style: TextStyle(color: Color(0xFF71827A))));
        }
        final groups = <String, double>{};
        for (final r in records.where((r) => r.category != 'Egg_Sales')) {
          final key = r.mainCategory.trim().isEmpty ? 'Uncategorized' : r.mainCategory.trim();
          groups[key] = (groups[key] ?? 0) + r.amount;
        }
        final sortedGroups = groups.entries.toList()..sort((a,b) => b.value.compareTo(a.value));
        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
          children: [
            AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Expense Groups', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF162A21))),
              const SizedBox(height: 5),
              const Text('Group expenses by Main Category, just like Cashew.', style: TextStyle(fontSize: 11, color: Color(0xFF75867D))),
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
              const Text('All Expense Records', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF162A21))),
              const SizedBox(height: 8),
              ...records.map((record) => _recordTile(context, record)),
            ])),
          ],
        );
      },
    );
    if (embedded) return content;
    return PoultryAppShell(selectedIndex: 7, title: 'Expenses', subtitle: 'Manage and group expense records', child: content);
  }

  Widget _recordTile(BuildContext context, ExpenseSalesLog record) => Container(
    margin: const EdgeInsets.only(top: 7),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: const Color(0xFFF7FAF8), borderRadius: BorderRadius.circular(11), border: Border.all(color: const Color(0xFFE1EAE5))),
    child: Row(children: [
      Container(width: 34, height: 34, decoration: BoxDecoration(color: const Color(0xFFE7F5EE), borderRadius: BorderRadius.circular(9)), child: const Icon(Icons.receipt_long_outlined, color: Color(0xFF0E9F6E), size: 18)),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(record.category.replaceAll('_', ' '), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF243A30))),
        const SizedBox(height: 2),
        Text('${record.mainCategory} • ${DateFormat('dd MMM yyyy').format(record.date)}', style: const TextStyle(fontSize: 10, color: Color(0xFF71827A))),
        if (record.description.isNotEmpty) Text(record.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Color(0xFF71827A))),
      ])),
      Text('₹${NumberFormat('#,##0.00').format(record.amount)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
      IconButton(onPressed: () => _edit(context, record), icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF0E9F6E))),
    ]),
  );

  Future<void> _edit(BuildContext context, ExpenseSalesLog record) async {
    final main = TextEditingController(text: record.mainCategory);
    final category = TextEditingController(text: record.category);
    final result = await showDialog<ExpenseSalesLog>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Update Expense Category'),
        content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: main, decoration: const InputDecoration(labelText: 'Main Category', hintText: 'e.g. Poultry, Cashew, Farm')),
          const SizedBox(height: 10),
          TextField(controller: category, decoration: const InputDecoration(labelText: 'Category', hintText: 'e.g. Renovation, Tiles')),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () {
            if (main.text.trim().isEmpty || category.text.trim().isEmpty) return;
            Navigator.pop(dialogContext, record.copyWith(mainCategory: main.text.trim(), category: category.text.trim()));
          }, child: const Text('Update')),
        ],
      ),
    );
    main.dispose(); category.dispose();
    if (result == null || !context.mounted) return;
    try {
      await context.read<PoultryProvider>().updateExpenseRecord(result);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense category updated.')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to update expense: $e')));
    }
  }
}
