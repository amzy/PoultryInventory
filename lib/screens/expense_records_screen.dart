import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/expense_sales_log.dart';
import '../providers/poultry_provider.dart';
import '../services/expense_category_config.dart';
import '../widgets/app_shell.dart';
import 'dashboard_screen.dart';

class ExpenseRecordsScreen extends StatelessWidget {
  final bool embedded;
  const ExpenseRecordsScreen({super.key, this.embedded = false});

  void _navigate(BuildContext context, int index) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => DashboardScreen(initialIndex: index)),
    );
  }

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
          groups[key] = (groups[key] ?? 0) + r.netTotal;
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
              const Text('All Expense Records', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF162A21))),
              const SizedBox(height: 8),
              ...records.map((record) => _recordTile(context, record)),
            ])),
          ],
        );
      },
    );
    if (embedded) return content;
    return PopScope(
      canPop: true,
      child: PoultryAppShell(
        selectedIndex: 8,
        title: 'Manage Expenses',
        subtitle: 'Manage and group expense records',
        onBack: () => Navigator.maybePop(context),
        onNavigate: (index) => _navigate(context, index),
        child: content,
      ),
    );
  }

  Map<String, double> _subcategoryGroups(List<ExpenseSalesLog> records) {
    final groups = <String, double>{};
    for (final r in records.where((r) => r.category != 'Egg_Sales')) {
      final key = r.category.trim().isEmpty ? 'Uncategorized' : r.category.trim();
      groups[key] = (groups[key] ?? 0) + r.netTotal;
    }
    return Map.fromEntries(groups.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
  }

  Map<String, double> _accountGroups(List<ExpenseSalesLog> records) {
    final groups = <String, double>{};
    for (final r in records.where((r) => r.category != 'Egg_Sales')) {
      final key = r.account.trim().isEmpty ? 'Unassigned' : r.account.trim();
      groups[key] = (groups[key] ?? 0) + r.netTotal;
    }
    return Map.fromEntries(groups.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
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
        Text('${record.mainCategory} • ${record.account} • ${DateFormat('dd MMM yyyy').format(record.date)}', style: const TextStyle(fontSize: 10, color: Color(0xFF71827A))),
        if (record.originalCategory != record.category) Text('Original: ${record.originalCategory}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Color(0xFF71827A))),
        if (record.description.isNotEmpty) Text(record.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Color(0xFF71827A))),
      ])),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('₹${NumberFormat('#,##0.00').format(record.amount)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        if (record.freightCharge > 0) Text('Net ₹${NumberFormat('#,##0.00').format(record.netTotal)}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF087A4F))),
      ]),
      IconButton(onPressed: () => _edit(context, record), icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF0E9F6E))),
    ]),
  );

  Future<void> _edit(BuildContext context, ExpenseSalesLog record) async {
    var selectedMain = ExpenseCategoryConfig.isValidMainCategory(record.mainCategory)
        ? record.mainCategory
        : ExpenseCategoryConfig.mainCategories.first;
    var selectedCategory = ExpenseCategoryConfig.isValidSubcategory(selectedMain, record.category)
        ? record.category
        : ExpenseCategoryConfig.subcategoriesFor(selectedMain).first;
    var selectedDate = record.date;
    var transactionType = record.transactionType;
    final accountController = TextEditingController(text: record.account);
    final descriptionController = TextEditingController(text: record.description);
    final amountController = TextEditingController(text: record.amount.toStringAsFixed(2));
    final unitPriceController = TextEditingController(text: record.unitPrice.toStringAsFixed(2));
    final freightController = TextEditingController(text: record.freightCharge.toStringAsFixed(2));
    final unitController = TextEditingController(text: record.unit);
    final quantityController = TextEditingController(text: record.quantity.toStringAsFixed(2));

    final result = await showDialog<ExpenseSalesLog>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final materialPricing = const {'Feed', 'Grit', 'Tray'}.contains(selectedCategory);
          double parse(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;
          final netTotal = parse(amountController) + (materialPricing ? parse(freightController) : 0);
          return AlertDialog(
            title: const Text('Edit Expense Record'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_month_outlined),
                    title: Text(DateFormat('dd MMM yyyy').format(selectedDate)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: dialogContext,
                        initialDate: selectedDate,
                        firstDate: DateTime(2026, 4, 27),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setDialogState(() => selectedDate = picked);
                    },
                  ),
                  DropdownButtonFormField<String>(
                    value: selectedMain,
                    decoration: const InputDecoration(labelText: 'Main Category'),
                    items: ExpenseCategoryConfig.mainCategories.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() {
                        selectedMain = value;
                        final options = ExpenseCategoryConfig.subcategoriesFor(value);
                        if (!options.contains(selectedCategory)) selectedCategory = options.first;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: const InputDecoration(labelText: 'Subcategory'),
                    items: ExpenseCategoryConfig.subcategoriesFor(selectedMain).map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                    onChanged: (value) => setDialogState(() => selectedCategory = value ?? selectedCategory),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: ExpenseCategoryConfig.accounts.contains(accountController.text) ? accountController.text : ExpenseCategoryConfig.accounts.first,
                    decoration: const InputDecoration(labelText: 'Account / Paid By'),
                    items: ExpenseCategoryConfig.accounts.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                    onChanged: (value) => accountController.text = value ?? ExpenseCategoryConfig.accounts.first,
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: descriptionController, decoration: const InputDecoration(labelText: 'Description')),
                  const SizedBox(height: 10),
                  if (materialPricing) ...[
                    Row(children: [
                      Expanded(child: TextField(controller: quantityController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Quantity'))),
                      const SizedBox(width: 10),
                      Expanded(child: TextField(controller: unitPriceController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Unit Price (₹)'))),
                    ]),
                    const SizedBox(height: 10),
                    TextField(controller: unitController, decoration: const InputDecoration(labelText: 'Unit')),
                    const SizedBox(height: 10),
                    TextField(controller: freightController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Freight Charge (₹)'), onChanged: (_) => setDialogState(() {})),
                    const SizedBox(height: 10),
                  ] else ...[
                    Row(children: [
                      Expanded(child: TextField(controller: unitController, decoration: const InputDecoration(labelText: 'Unit'))),
                      const SizedBox(width: 10),
                      Expanded(child: TextField(controller: quantityController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Quantity'))),
                    ]),
                    const SizedBox(height: 10),
                  ],
                  TextField(controller: amountController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount (₹)'), onChanged: (_) => setDialogState(() {})),
                  if (materialPricing) ...[
                    const SizedBox(height: 6),
                    Align(alignment: Alignment.centerLeft, child: Text('Net Total: ₹${netTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF087A4F)))),
                  ],
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: transactionType,
                    decoration: const InputDecoration(labelText: 'Transaction Type'),
                    items: const [DropdownMenuItem(value: 'expense', child: Text('Expense')), DropdownMenuItem(value: 'credit', child: Text('Credit'))],
                    onChanged: (value) => setDialogState(() => transactionType = value ?? transactionType),
                  ),
                ]),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  final amount = double.tryParse(amountController.text.trim());
                  final quantity = double.tryParse(quantityController.text.trim());
                  final unitPrice = double.tryParse(unitPriceController.text.trim());
                  final freight = double.tryParse(freightController.text.trim());
                  if (amount == null || amount < 0 || quantity == null || quantity < 0 || unitPrice == null || unitPrice < 0 || freight == null || freight < 0) return;
                  Navigator.pop(dialogContext, record.copyWith(
                    date: selectedDate,
                    mainCategory: selectedMain,
                    category: selectedCategory,
                    account: accountController.text,
                    description: descriptionController.text,
                    amount: amount,
                    quantity: quantity,
                    unitPrice: materialPricing ? unitPrice : 0,
                    freightCharge: materialPricing ? freight : 0,
                    unit: unitController.text,
                    transactionType: transactionType,
                    // Manual editing means the amount is no longer considered an automatic calculation.
                    pricingCalculated: false,
                  ));
                },
                child: const Text('Save Changes'),
              ),
            ],
          );
        },
      ),
    );
    accountController.dispose();
    descriptionController.dispose();
    amountController.dispose();
    unitPriceController.dispose();
    freightController.dispose();
    unitController.dispose();
    quantityController.dispose();
    if (result == null || !context.mounted) return;
    try {
      await context.read<PoultryProvider>().updateExpenseRecord(result);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense record updated.')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to update expense: $e')));
    }
  }

}
