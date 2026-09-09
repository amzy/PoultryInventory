import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/expense_sales_log.dart';
import 'package:provider/provider.dart';
import '../providers/poultry_provider.dart';
import '../services/expense_category_config.dart';
import '../widgets/app_shell.dart';

class ExpenseSalesFormScreen extends StatefulWidget {
  final String? initialCategory;
  final bool embedded;
  final VoidCallback? onEmbeddedBack;
  const ExpenseSalesFormScreen({super.key, this.initialCategory, this.embedded = false, this.onEmbeddedBack});
  @override
  _ExpenseSalesFormScreenState createState() => _ExpenseSalesFormScreenState();
}

class _ExpenseSalesFormScreenState extends State<ExpenseSalesFormScreen> {
  final _formKey = GlobalKey<FormState>();
  DateTime _selectedDate = DateTime.now();
  late String _selectedCategory;
  String _selectedAccount = ExpenseCategoryConfig.accounts.first;
  String _selectedMainCategory = ExpenseCategoryConfig.mainCategories.first;
  final _mainCategoryController = TextEditingController(text: 'Layer Bird');
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _unitController = TextEditingController();
  final _quantityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory ?? 'Feed';
    if (!ExpenseCategoryConfig.subcategoriesFor(_selectedMainCategory).contains(_selectedCategory)) {
      _selectedCategory = ExpenseCategoryConfig.subcategoriesFor(_selectedMainCategory).first;
    }
  }

  List<String> get _subcategories => ExpenseCategoryConfig.subcategoriesFor(_mainCategoryController.text.trim());

  @override
  Widget build(BuildContext context) {
    final content = Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
        children: [
          AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Record Details', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF162A21))),
            const SizedBox(height: 4),
            const Text('Group every transaction by Main Category, Subcategory and Account.', style: TextStyle(fontSize: 10, color: Color(0xFF75867D))),
            const SizedBox(height: 14),
            InkWell(onTap: _pickDate, borderRadius: BorderRadius.circular(11), child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFF8FBF9), borderRadius: BorderRadius.circular(11), border: Border.all(color: const Color(0xFFDCE7E0))), child: Row(children: [const Icon(Icons.calendar_month_outlined, color: Color(0xFF0E9F6E)), const SizedBox(width: 10), Expanded(child: Text(DateFormat('dd MMM yyyy').format(_selectedDate), style: const TextStyle(fontWeight: FontWeight.w700))), const Icon(Icons.chevron_right, color: Color(0xFF71827A))]))),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _selectedMainCategory,
              decoration: _decoration('Main Category / Phase', Icons.account_tree_outlined),
              items: ExpenseCategoryConfig.mainCategories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                final options = ExpenseCategoryConfig.subcategoriesFor(value);
                setState(() {
                  _selectedMainCategory = value;
                  _mainCategoryController.text = value;
                  _selectedCategory = options.contains(_selectedCategory) ? _selectedCategory : options.first;
                });
              },
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: _decoration('Subcategory', Icons.category_outlined),
              items: _subcategories.map((c) => DropdownMenuItem(value: c, child: Text(c.replaceAll('_', ' ')))).toList(),
              onChanged: (v) => setState(() {
                _selectedCategory = v ?? _subcategories.first;
                _descriptionController.clear();
                _unitController.clear();
                _quantityController.clear();
              }),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _selectedAccount,
              decoration: _decoration('Account / Paid By', Icons.person_outline),
              items: ExpenseCategoryConfig.accounts.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
              onChanged: (v) => setState(() => _selectedAccount = v ?? ExpenseCategoryConfig.accounts.first),
            ),
            const SizedBox(height: 10),
            if (_selectedCategory != 'Electricity') ...[
              _buildTextField(_descriptionController, 'Description', TextInputType.text, required: _selectedCategory != 'Tray'),
              const SizedBox(height: 10),
            ],
            _buildCategoryFields(),
          ])),
          const SizedBox(height: 14),
          SizedBox(height: 50, child: FilledButton.icon(onPressed: _submitForm, icon: const Icon(Icons.save_outlined), label: const Text('Save Record'), style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0E9F6E), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), textStyle: const TextStyle(fontWeight: FontWeight.w800)))),
        ],
      ),
    );

    if (widget.embedded) return content;
    return PoultryAppShell(
      selectedIndex: _navIndex,
      title: 'Add ${_selectedCategory == 'Egg_Sales' ? 'Egg Sales' : 'Expense'}',
      subtitle: 'Record farm financial activity',
      onBack: () => Navigator.pop(context),
      onNavigate: (index) { if (index != _navIndex) Navigator.pop(context); },
      child: content,
    );
  }

  int get _navIndex {
    switch (_selectedCategory) {
      case 'Medical':
        return 2;
      case 'Feed':
        return 3;
      case 'Grit':
        return 4;
      case 'Electricity':
      case 'Tray':
      case 'Other_Expenses':
        return 5;
      case 'Egg_Sales':
        return 6;
      default:
        return 3;
    }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2026, 4, 27), lastDate: DateTime.now());
    if (d != null) setState(() => _selectedDate = d);
  }

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(labelText: label, labelStyle: const TextStyle(color: Color(0xFF708178), fontSize: 12), prefixIcon: Icon(icon, color: const Color(0xFF0E9F6E), size: 19), filled: true, fillColor: const Color(0xFFF9FBFA), border: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: Color(0xFFDCE7E0))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: Color(0xFFDCE7E0))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: Color(0xFF0E9F6E), width: 1.4)));

  Widget _buildCategoryFields() {
    if (_selectedCategory == 'Electricity') {
      return _buildTextField(_amountController, 'Amount Paid (₹)', TextInputType.numberWithOptions(decimal: true));
    }
    if (_selectedCategory == 'Tray') {
      return LayoutBuilder(builder: (context, c) {
        final fields = [
          _buildTextField(_quantityController, 'No. of Bundles', TextInputType.numberWithOptions(decimal: true)),
          _buildTextField(_amountController, 'Amount Paid (₹)', TextInputType.numberWithOptions(decimal: true)),
        ];
        return c.maxWidth >= 700 ? Row(children: fields.map((f) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 8), child: f))).toList()) : Column(children: fields);
      });
    }
    return LayoutBuilder(builder: (context, c) {
      final fields = [
        _buildTextField(_amountController, 'Amount (₹)', TextInputType.numberWithOptions(decimal: true)),
        _buildTextField(_unitController, 'Unit (kg, L, etc)', TextInputType.text),
        _buildTextField(_quantityController, 'Quantity', TextInputType.numberWithOptions(decimal: true)),
      ];
      return c.maxWidth >= 700 ? Row(children: fields.map((f) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 8), child: f))).toList()) : Column(children: fields);
    });
  }

  Widget _buildTextField(TextEditingController controller, String label, TextInputType type, {bool required = true, ValueChanged<String>? onChanged}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(color: Color(0xFF172A21), fontWeight: FontWeight.w600),
        decoration: _decoration(label, Icons.edit_outlined),
        keyboardType: type,
        validator: (value) {
          if (required && (value == null || value.trim().isEmpty)) return 'Required';
          if (!required && (value == null || value.trim().isEmpty)) return null;
          if (type == TextInputType.numberWithOptions(decimal: true)) {
            final n = double.tryParse(value!.trim());
            if (n == null || n < 0) return 'Enter a valid value';
          }
          return null;
        },
      ),
    );
  }

  @override
  void dispose() {
    _mainCategoryController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    _unitController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.tryParse(_amountController.text.trim()) ?? -1;
    final quantity = _selectedCategory == 'Electricity' ? 0.0 : (double.tryParse(_quantityController.text.trim()) ?? -1);
    if (amount < 0 || quantity < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter valid non-negative values.')));
      return;
    }
    final log = ExpenseSalesLog(
      date: _selectedDate,
      mainCategory: _selectedMainCategory,
      category: _selectedCategory,
      originalCategory: _selectedCategory,
      account: _selectedAccount,
      description: _selectedCategory == 'Electricity' ? 'Electricity bill' : _descriptionController.text.trim(),
      amount: amount,
      unit: _selectedCategory == 'Electricity' ? 'rupees' : (_selectedCategory == 'Tray' ? 'bundle' : _unitController.text.trim()),
      quantity: quantity,
      transactionType: _selectedCategory == 'Egg_Sales' ? 'credit' : 'expense',
    );
    try {
      showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));
      await context.read<PoultryProvider>().addExpenseRecord(log);
      if (!mounted) return;
      Navigator.pop(context);
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving record: $e')));
    }
  }
}
