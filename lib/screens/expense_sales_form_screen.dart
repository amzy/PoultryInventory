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
  final _unitPriceController = TextEditingController();
  final _freightController = TextEditingController(text: '0');
  final _unitController = TextEditingController();
  final _quantityController = TextEditingController();
  bool _amountAutoCalculated = false;

  final List<_MedicalItemDraft> _medicalItems = [];

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
                _unitPriceController.clear();
                _freightController.text = '0';
                _amountController.clear();
                _unitController.clear();
                _quantityController.clear();
                _amountAutoCalculated = false;
                _clearMedicalItems();
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
      case 'Other_Expenses':
        return 5;
      case 'Tray':
        return 6;
      case 'Egg_Sales':
        return 7;
      default:
        return 3;
    }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2026, 4, 27), lastDate: DateTime.now());
    if (d != null) setState(() => _selectedDate = d);
  }

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(labelText: label, labelStyle: const TextStyle(color: Color(0xFF708178), fontSize: 12), prefixIcon: Icon(icon, color: const Color(0xFF0E9F6E), size: 19), filled: true, fillColor: const Color(0xFFF9FBFA), border: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: Color(0xFFDCE7E0))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: Color(0xFFDCE7E0))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: Color(0xFF0E9F6E), width: 1.4)));

  bool get _usesMaterialPricing => const {'Feed', 'Grit', 'Tray'}.contains(_selectedCategory);

  bool get _isMedical => _selectedCategory == 'Medical';

  double get _medicalTotal => _medicalItems.fold(0.0, (sum, item) => sum + item.total);

  void _clearMedicalItems() {
    for (final item in _medicalItems) {
      item.dispose();
    }
    _medicalItems.clear();
  }

  void _addMedicalItem() {
    setState(() => _medicalItems.add(_MedicalItemDraft()));
  }

  void _removeMedicalItem(int index) {
    setState(() {
      _medicalItems[index].dispose();
      _medicalItems.removeAt(index);
      _updateMedicalAmount();
    });
  }

  void _onMedicalItemsChanged() {
    if (!mounted) return;
    setState(_updateMedicalAmount);
  }

  void _updateMedicalAmount() {
    if (!_isMedical) return;
    _amountController.text = _medicalTotal.toStringAsFixed(2);
    _amountAutoCalculated = true;
  }

  double get _calculatedBaseAmount {
    final quantity = double.tryParse(_quantityController.text.trim()) ?? 0;
    final unitPrice = double.tryParse(_unitPriceController.text.trim()) ?? 0;
    return quantity * unitPrice;
  }

  double get _netTotal {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final freight = double.tryParse(_freightController.text.trim()) ?? 0;
    return amount + freight;
  }

  void _recalculateAmount() {
    if (!_usesMaterialPricing) return;
    // Amount is the editable material/base amount. Recalculate it from
    // quantity × unit price when those inputs change; freight is added only
    // to Net Total and is never folded into Amount.
    _amountController.text = _calculatedBaseAmount.toStringAsFixed(2);
    _amountAutoCalculated = true;
    if (mounted) setState(() {});
  }

  Widget _buildCategoryFields() {
    if (_selectedCategory == 'Electricity') {
      return _buildTextField(_amountController, 'Amount Paid (₹)', TextInputType.numberWithOptions(decimal: true));
    }

    if (_isMedical) {
      return _buildMedicalFields();
    }

    if (_usesMaterialPricing) {
      return Column(children: [
        LayoutBuilder(builder: (context, c) {
          final fields = [
            _buildTextField(_quantityController, _selectedCategory == 'Tray' ? 'No. of Bundles' : 'Quantity', TextInputType.numberWithOptions(decimal: true), onChanged: (_) => _recalculateAmount()),
            _buildTextField(_unitPriceController, 'Unit Price (₹)', TextInputType.numberWithOptions(decimal: true), onChanged: (_) => _recalculateAmount()),
          ];
          return c.maxWidth >= 700
              ? Row(children: fields.map((f) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 8), child: f))).toList())
              : Column(children: fields);
        }),
        _buildTextField(_freightController, 'Freight Charge (₹)', TextInputType.numberWithOptions(decimal: true), required: true, onChanged: (_) => setState(() {})),
        _buildTextField(_amountController, 'Amount (₹)', TextInputType.numberWithOptions(decimal: true), required: true, readOnly: false, onChanged: (_) { _amountAutoCalculated = false; setState(() {}); }),
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Net Total: ₹${_netTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF087A4F))),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Amount = Quantity × Unit Price (editable) • Net Total = Amount + Freight Charge', style: TextStyle(fontSize: 11, color: Color(0xFF75867D))),
          ),
        ),
      ]);
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

  Widget _buildMedicalFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Medical Items', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF162A21))),
            OutlinedButton.icon(
              onPressed: _addMedicalItem,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Item'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (_medicalItems.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Add each medicine separately with its name, price and quantity.', style: TextStyle(fontSize: 11, color: Color(0xFF75867D))),
          ),
        ...List.generate(_medicalItems.length, (index) {
          final item = _medicalItems[index];
          return Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FBF9),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: const Color(0xFFDCE7E0)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildTextField(item.name, 'Medicine / Item Name', TextInputType.text, onChanged: (_) => _onMedicalItemsChanged())),
                    const SizedBox(width: 8),
                    IconButton(onPressed: () => _removeMedicalItem(index), icon: const Icon(Icons.delete_outline), tooltip: 'Remove item'),
                  ],
                ),
                LayoutBuilder(builder: (context, c) {
                  final fields = [
                    _buildTextField(item.price, 'Price (₹)', const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => _onMedicalItemsChanged()),
                    _buildTextField(item.quantity, 'Quantity', const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => _onMedicalItemsChanged()),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: InputDecorator(
                        decoration: _decoration('Item Total (₹)', Icons.calculate_outlined),
                        child: Text('₹${item.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ];
                  return c.maxWidth >= 700
                      ? Row(children: fields.map((f) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 8), child: f))).toList())
                      : Column(children: fields);
                }),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        _buildTextField(_freightController, 'Freight Charge (₹)', const TextInputType.numberWithOptions(decimal: true), required: true, onChanged: (_) => setState(() {})),
        const SizedBox(height: 4),
        Text('Total Amount: ₹${_medicalTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF087A4F))),
        const SizedBox(height: 2),
        Text('Net Total: ₹${(_medicalTotal + (double.tryParse(_freightController.text.trim()) ?? 0)).toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF087A4F))),
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, TextInputType type, {bool required = true, bool readOnly = false, ValueChanged<String>? onChanged}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(color: Color(0xFF172A21), fontWeight: FontWeight.w600),
        decoration: _decoration(label, Icons.edit_outlined),
        keyboardType: type,
        readOnly: readOnly,
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
    _unitPriceController.dispose();
    _freightController.dispose();
    _clearMedicalItems();
    super.dispose();
  }

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isMedical && _medicalItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one medical item.')));
      return;
    }
    final quantity = _selectedCategory == 'Electricity' || _isMedical ? 0.0 : (double.tryParse(_quantityController.text.trim()) ?? -1);
    final unitPrice = _usesMaterialPricing ? (double.tryParse(_unitPriceController.text.trim()) ?? -1) : 0.0;
    final freightCharge = (_usesMaterialPricing || _isMedical) ? (double.tryParse(_freightController.text.trim()) ?? -1) : 0.0;
    final amount = _isMedical ? _medicalTotal : (_usesMaterialPricing ? (double.tryParse(_amountController.text.trim()) ?? -1) : (double.tryParse(_amountController.text.trim()) ?? -1));
    if (amount < 0 || quantity < 0 || unitPrice < 0 || freightCharge < 0 || (_isMedical && _medicalItems.any((item) => item.name.text.trim().isEmpty || item.priceValue < 0 || item.quantityValue < 0))) {
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
      unitPrice: unitPrice,
      freightCharge: freightCharge,
      pricingCalculated: _usesMaterialPricing && _amountAutoCalculated,
      medicalItems: _isMedical ? _medicalItems.map((item) => item.toMap()).toList() : const [],
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


class _MedicalItemDraft {
  final TextEditingController name = TextEditingController();
  final TextEditingController price = TextEditingController(text: '0');
  final TextEditingController quantity = TextEditingController(text: '1');
  _MedicalItemDraft();

  double get priceValue => double.tryParse(price.text.trim()) ?? 0;
  double get quantityValue => double.tryParse(quantity.text.trim()) ?? 0;
  double get total => priceValue * quantityValue;

  Map<String, dynamic> toMap() => {
    'name': name.text.trim(),
    'price': priceValue,
    'quantity': quantityValue,
    'total': total,
  };

  void dispose() {
    name.dispose();
    price.dispose();
    quantity.dispose();
  }
}
