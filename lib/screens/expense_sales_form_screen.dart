import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/expense_sales_log.dart';
import '../models/supplier.dart';
import '../providers/poultry_provider.dart';
import '../services/expense_category_config.dart';
import '../widgets/app_shell.dart';

class ExpenseSalesFormScreen extends StatefulWidget {
  final String? initialCategory;
  final ExpenseSalesLog? existingRecord;
  final bool embedded;
  final bool initialEggSale;
  final VoidCallback? onEmbeddedBack;

  const ExpenseSalesFormScreen({
    super.key,
    this.initialCategory,
    this.existingRecord,
    this.embedded = false,
    this.initialEggSale = false,
    this.onEmbeddedBack,
  });

  @override
  State<ExpenseSalesFormScreen> createState() => _ExpenseSalesFormScreenState();
}

class _ExpenseSalesFormScreenState extends State<ExpenseSalesFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _selectedDate;
  late String _selectedMainCategory;
  late String _selectedCategory;
  late String _selectedAccount;
  String? _selectedSupplierId;

  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _unitPriceController = TextEditingController();
  final _freightController = TextEditingController();
  final _unitController = TextEditingController();
  final _quantityController = TextEditingController();
  bool _amountAutoCalculated = false;
  bool _forceNewEntry = false;

  final List<_MedicalItemDraft> _medicalItems = [];
  final List<_FeedItemDraft> _feedItems = [];

  bool get _editing => widget.existingRecord != null && !_forceNewEntry;
  bool get _isMedical => _selectedCategory == 'Medical';
  bool get _isFeed => _selectedCategory == 'Feed';
  bool get _isEggSales => widget.initialEggSale ||
      (widget.existingRecord?.transactionType == 'credit' && widget.existingRecord?.category == 'Egg');
  bool get _usesMaterialPricing => const {'Feed', 'Grit', 'Tray'}.contains(_selectedCategory);
  String get _defaultUnit => _isFeed ? '50 kg/bag' : (_selectedCategory == 'Grit' ? 'kg' : (_selectedCategory == 'Tray' ? 'tray' : ''));

  List<String> get _subcategories => ExpenseCategoryConfig.activeSubcategories;
  List<String> get _availableFeedItems => context.read<PoultryProvider>().feedItems;
  double get _medicalTotal => _medicalItems.fold(0, (sum, item) => sum + item.total);
  double get _feedTotal => _feedItems.fold(0, (sum, item) => sum + item.total);
  double get _baseAmount => _isMedical ? _medicalTotal : (_isFeed ? _feedTotal : _parse(_amountController));
  double get _freight => _isEggSales ? 0 : _parse(_freightController);
  double get _netTotal => _baseAmount + _freight;

  double _parse(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingRecord;
    _selectedDate = existing?.date ?? DateTime.now();
    _selectedMainCategory = existing != null && ExpenseCategoryConfig.isValidMainCategory(existing.mainCategory)
        ? existing.mainCategory
        : 'Layer Bird';
    final requestedCategory = existing?.category ?? widget.initialCategory ?? 'Feed';
    _selectedCategory = ExpenseCategoryConfig.isValidSubcategory(_selectedMainCategory, requestedCategory)
        ? requestedCategory.trim()
        : 'Other Expenses';
    final configuredAccounts = ExpenseCategoryConfig.activeAccounts;
    final existingAccount = existing?.account.trim() ?? '';
    _selectedAccount = existingAccount.isNotEmpty
        ? existingAccount
        : configuredAccounts.first;
    _selectedSupplierId = existing?.supplierId;

    _descriptionController.text = existing?.description ?? '';
    _amountController.text = existing != null ? existing.amount.toStringAsFixed(2) : '';
    _unitPriceController.text = existing != null ? existing.unitPrice.toStringAsFixed(2) : '';
    _freightController.text = existing != null ? existing.freightCharge.toStringAsFixed(2) : (_isFeed ? '700' : '0');
    _unitController.text = existing?.unit ?? _defaultUnit;
    _quantityController.text = existing != null ? existing.quantity.toStringAsFixed(2) : '';
    _amountAutoCalculated = existing?.pricingCalculated ?? false;

    if (existing?.medicalItems.isNotEmpty == true) {
      for (final item in existing!.medicalItems) {
        _medicalItems.add(_MedicalItemDraft.fromMap(item));
      }
    }
    if (existing?.feedItems.isNotEmpty == true) {
      for (final item in existing!.feedItems) {
        _feedItems.add(_FeedItemDraft.fromMap(item));
      }
    } else if (existing != null && _isFeed) {
      final items = _availableFeedItems;
      final legacyName = existing.description.trim();
      final selectedName = items.contains(legacyName) ? legacyName : (items.isNotEmpty ? items.first : legacyName);
      _feedItems.add(_FeedItemDraft(name: selectedName, quantity: existing.quantity, pricePerBag: existing.unitPrice));
    } else if (!_editing && _isFeed && _availableFeedItems.isNotEmpty) {
      _feedItems.add(_FeedItemDraft(name: _availableFeedItems.first));
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _unitPriceController.dispose();
    _freightController.dispose();
    _unitController.dispose();
    _quantityController.dispose();
    _clearMedicalItems();
    _clearFeedItems();
    super.dispose();
  }

  void _clearMedicalItems() {
    for (final item in _medicalItems) item.dispose();
    _medicalItems.clear();
  }

  void _clearFeedItems() {
    for (final item in _feedItems) item.dispose();
    _feedItems.clear();
  }

  void _resetCategoryFields() {
    _descriptionController.clear();
    _amountController.clear();
    _unitPriceController.clear();
    _quantityController.clear();
    _unitController.text = _defaultUnit;
    _freightController.text = _isFeed ? '700' : '0';
    _amountAutoCalculated = false;
    _clearMedicalItems();
    _clearFeedItems();
    if (_isFeed) _addFeedItem();
  }

  void _onCategoryChanged(String value) {
    setState(() {
      _selectedCategory = value;
      _resetCategoryFields();
    });
  }

  void _addMedicalItem() => setState(() => _medicalItems.add(_MedicalItemDraft()));
  void _removeMedicalItem(int index) => setState(() { _medicalItems[index].dispose(); _medicalItems.removeAt(index); _updateMedicalAmount(); });
  void _updateMedicalAmount() {
    if (_isMedical) {
      _amountController.text = _medicalTotal.toStringAsFixed(2);
      _amountAutoCalculated = true;
    }
  }

  void _addFeedItem() {
    final options = _availableFeedItems;
    setState(() => _feedItems.add(_FeedItemDraft(name: options.isNotEmpty ? options.first : '')));
  }

  void _removeFeedItem(int index) => setState(() { _feedItems[index].dispose(); _feedItems.removeAt(index); _updateFeedAmount(); });
  void _updateFeedAmount() {
    if (_isFeed) {
      _amountController.text = _feedTotal.toStringAsFixed(2);
      _amountAutoCalculated = true;
    }
  }

  void _resetForNewEntry() {
    _forceNewEntry = true;
    _selectedDate = DateTime.now();
    _descriptionController.clear();
    _amountController.clear();
    _unitPriceController.clear();
    _quantityController.clear();
    _unitController.text = _defaultUnit;
    _freightController.text = _isFeed ? '700' : '0';
    _amountAutoCalculated = false;
    _clearMedicalItems();
    _clearFeedItems();
    if (_isFeed) {
      final options = _availableFeedItems;
      _feedItems.add(_FeedItemDraft(name: options.isNotEmpty ? options.first : ''));
    }
    _formKey.currentState?.reset();
  }

  String get _entryTypeLabel {
    if (_isEggSales) return 'Egg Sales';
    return _selectedCategory;
  }

  Future<void> _showSaveConfirmation() async {
    if (!mounted) return;
    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text('${_entryTypeLabel} Saved'),
        content: Text('The ${_entryTypeLabel.toLowerCase()} entry was saved successfully. What would you like to do next?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, 'dashboard'), child: const Text('Back to Dashboard')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, 'another'), child: Text('Add Another $_entryTypeLabel')),
        ],
      ),
    );
    if (!mounted) return;
    if (action == 'dashboard') {
      if (widget.embedded) { widget.onEmbeddedBack?.call(); } else { Navigator.pop(context, true); }
    } else if (action == 'another') {
      setState(_resetForNewEntry);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
        children: [
          AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_editing ? 'Edit Record' : 'Record Details', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF162A21))),
            const SizedBox(height: 5),
            Text(_editing ? 'Edit this existing record using the current input format.' : 'Record farm financial activity.', style: const TextStyle(fontSize: 11, color: Color(0xFF75867D))),
            const SizedBox(height: 14),
            _datePicker(),
            const SizedBox(height: 10),
            _mainCategoryPicker(),
            const SizedBox(height: 10),
            _categoryPicker(),
            const SizedBox(height: 10),
            _accountPicker(),
            const SizedBox(height: 10),
            _supplierPicker(),
            if (!_isEggSales && !_isFeed) const SizedBox(height: 2),
            if (!_isEggSales && _selectedCategory != 'Electricity' && !_isFeed && !_isMedical) ...[
              _textField(_descriptionController, 'Description', TextInputType.text, required: _selectedCategory != 'Tray'),
              const SizedBox(height: 8),
            ],
            if (_isFeed) _buildFeedFields(),
            if (_isMedical) _buildMedicalFields(),
            if (_isFeed) ...[
              const SizedBox(height: 8),
              _textField(_descriptionController, 'Description (optional)', TextInputType.text, required: false),
            ],
            if (_selectedCategory == 'Electricity') _textField(_amountController, 'Amount Paid (₹)', const TextInputType.numberWithOptions(decimal: true)),
            if (!_isFeed && !_isMedical && _selectedCategory != 'Electricity' && !_usesMaterialPricing) _buildGenericFields(),
            if (!_isFeed && !_isMedical && _selectedCategory != 'Electricity' && _usesMaterialPricing) _buildPricedGenericFields(),
          ])),
          const SizedBox(height: 14),
          SizedBox(height: 50, child: FilledButton.icon(onPressed: _submitForm, icon: Icon(_editing ? Icons.save_as_outlined : Icons.save_outlined), label: Text(_editing ? 'Update Record' : 'Save Record'), style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0E9F6E), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), textStyle: const TextStyle(fontWeight: FontWeight.w800)))),
        ],
      ),
    );

    if (widget.embedded) return content;
    return PoultryAppShell(
      selectedIndex: _navIndex,
      title: _editing ? 'Edit ${_isEggSales ? 'Egg Sales' : 'Expense'}' : 'Add ${_isEggSales ? 'Egg Sales' : 'Expense'}',
      subtitle: _editing ? 'Modify an existing financial record' : 'Record farm financial activity',
      onBack: widget.embedded ? widget.onEmbeddedBack : () => Navigator.pop(context),
      onNavigate: (index) { if (index != _navIndex) Navigator.pop(context); },
      child: content,
    );
  }

  int get _navIndex {
    switch (_selectedCategory) {
      case 'Medical': return 3;
      case 'Feed': return 4;
      case 'Grit': return 5;
      case 'Tray': return 6;
      case 'Egg': return _isEggSales ? 8 : 7;
      default: return 7;
    }
  }

  Widget _datePicker() => InkWell(
    onTap: () async {
      final d = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: context.read<PoultryProvider>().farmConfig.flockStartDate.add(const Duration(days: 1)), lastDate: DateTime.now());
      if (d != null) setState(() => _selectedDate = DateTime(d.year, d.month, d.day));
    },
    child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFF8FBF9), borderRadius: BorderRadius.circular(11), border: Border.all(color: const Color(0xFFDCE7E0))), child: Row(children: [const Icon(Icons.calendar_month_outlined, color: Color(0xFF0E9F6E)), const SizedBox(width: 10), Expanded(child: Text(DateFormat('dd MMM yyyy').format(_selectedDate), style: const TextStyle(fontWeight: FontWeight.w700))), const Icon(Icons.chevron_right, color: Color(0xFF71827A))])),
  );

  Widget _mainCategoryPicker() => DropdownButtonFormField<String>(
    value: _selectedMainCategory,
    decoration: _decoration('Main Category / Phase', Icons.account_tree_outlined),
    items: ExpenseCategoryConfig.activeMainCategories.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
    onChanged: (value) { if (value == null) return; setState(() { _selectedMainCategory = value; final options = ExpenseCategoryConfig.activeSubcategories; _selectedCategory = options.contains(_selectedCategory) ? _selectedCategory : options.first; _resetCategoryFields(); }); },
  );

  Widget _categoryPicker() => DropdownButtonFormField<String>(
    value: _selectedCategory,
    decoration: _decoration('Subcategory', Icons.category_outlined),
    items: _subcategories.map((v) => DropdownMenuItem(value: v, child: Text(v.replaceAll('_', ' ')))).toList(),
    onChanged: (v) { if (v != null) _onCategoryChanged(v); },
  );

  Widget _accountPicker() {
    final accounts = ExpenseCategoryConfig.activeAccounts;

    // When a flock has only one configured account, that account is implicit
    // for every expense/sale form. Keep it selected without showing a picker.
    if (accounts.length == 1) {
      if (_selectedAccount != accounts.first) {
        _selectedAccount = accounts.first;
      }
      return const SizedBox.shrink();
    }

    final value = accounts.contains(_selectedAccount) ? _selectedAccount : accounts.first;
    return DropdownButtonFormField<String>(
      value: value,
      decoration: _decoration('Account / Paid By', Icons.person_outline),
      items: accounts.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
      onChanged: (v) { if (v != null) setState(() => _selectedAccount = v); },
    );
  }

  Widget _supplierPicker() {
    final suppliers = context.watch<PoultryProvider>().suppliers;
    final value = suppliers.any((s) => s.id == _selectedSupplierId) ? _selectedSupplierId : null;
    return DropdownButtonFormField<String?>(
      value: value,
      decoration: _decoration('Supplier (Optional)', Icons.local_shipping_outlined),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('No supplier')),
        ...suppliers.map((supplier) => DropdownMenuItem<String?>(
          value: supplier.id,
          child: Text(supplier.fullName),
        )),
      ],
      onChanged: (v) => setState(() => _selectedSupplierId = v),
    );
  }

  Widget _buildFeedFields() {
    final options = _availableFeedItems;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Feed Items', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF162A21))), OutlinedButton.icon(onPressed: options.isEmpty ? null : _addFeedItem, icon: const Icon(Icons.add, size: 18), label: const Text('Add Item'))]),
      const SizedBox(height: 4),
      const Text('Each feed item is one 50 kg bag. Enter bags and the price of one bag.', style: TextStyle(fontSize: 11, color: Color(0xFF75867D))),
      if (_feedItems.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text('Add at least one feed item.', style: TextStyle(color: Color(0xFFB23B34), fontSize: 11))),
      ...List.generate(_feedItems.length, (index) => _feedRow(index, options)),
      const SizedBox(height: 8),
      _textField(_freightController, 'Fright Charge (₹)', const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {})),
      Text('Total Amount: ₹${_feedTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF087A4F))),
      const SizedBox(height: 2),
      Text('Net Amount: ₹${_netTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF087A4F))),
    ]);
  }

  Widget _feedRow(int index, List<String> options) {
    final item = _feedItems[index];
    final pickerItems = [...options];
    if (item.name.text.isNotEmpty && !pickerItems.contains(item.name.text)) pickerItems.insert(0, item.name.text);
    return Container(
      margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      decoration: BoxDecoration(color: const Color(0xFFF8FBF9), borderRadius: BorderRadius.circular(11), border: Border.all(color: const Color(0xFFDCE7E0))),
      child: Column(children: [
        Row(children: [Expanded(child: DropdownButtonFormField<String>(value: item.name.text.isEmpty ? null : item.name.text, decoration: _decoration('Feed Item', Icons.grass_outlined), items: pickerItems.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) { if (v != null) setState(() => item.name.text = v); }, validator: (v) => v == null || v.isEmpty ? 'Required' : null)), const SizedBox(width: 8), IconButton(onPressed: () => _removeFeedItem(index), icon: const Icon(Icons.delete_outline), tooltip: 'Remove item')]),
        LayoutBuilder(builder: (context, c) {
          final fields = [
            _textField(item.quantity, 'Quantity (50 kg bags)', const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() => _updateFeedAmount())),
            _textField(item.price, 'Price / Bag (₹)', const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() => _updateFeedAmount())),
            InputDecorator(decoration: _decoration('Item Total (₹)', Icons.calculate_outlined), child: Text('₹${item.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800))),
          ];
          return c.maxWidth >= 700 ? Row(children: fields.map((f) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 8), child: f))).toList()) : Column(children: fields);
        }),
      ]),
    );
  }

  Widget _buildMedicalFields() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Medical Items', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)), OutlinedButton.icon(onPressed: _addMedicalItem, icon: const Icon(Icons.add, size: 18), label: const Text('Add Item'))]),
    if (_medicalItems.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Add each medicine separately with its name, price and quantity.', style: TextStyle(fontSize: 11, color: Color(0xFF75867D)))),
    ...List.generate(_medicalItems.length, (index) {
      final item = _medicalItems[index];
      return Container(margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.fromLTRB(10, 8, 10, 4), decoration: BoxDecoration(color: const Color(0xFFF8FBF9), borderRadius: BorderRadius.circular(11), border: Border.all(color: const Color(0xFFDCE7E0))), child: Column(children: [
        Row(children: [Expanded(child: _textField(item.name, 'Medicine / Item Name', TextInputType.text, onChanged: (_) => setState(_updateMedicalAmount))), const SizedBox(width: 8), IconButton(onPressed: () => _removeMedicalItem(index), icon: const Icon(Icons.delete_outline))]),
        LayoutBuilder(builder: (context, c) { final fields = [_textField(item.price, 'Price (₹)', const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(_updateMedicalAmount)), _textField(item.quantity, 'Quantity', const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(_updateMedicalAmount)), InputDecorator(decoration: _decoration('Item Total (₹)', Icons.calculate_outlined), child: Text('₹${item.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800)))]; return c.maxWidth >= 700 ? Row(children: fields.map((f) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 8), child: f))).toList()) : Column(children: fields); }),
      ]));
    }),
    const SizedBox(height: 8),
    _textField(_freightController, 'Fright Charge (₹)', const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {})),
    Text('Total Amount: ₹${_medicalTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF087A4F))),
    Text('Net Total: ₹${_netTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF087A4F))),
  ]);

  Widget _buildPricedGenericFields() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      LayoutBuilder(builder: (context, c) {
        final fields = [
          _textField(_quantityController, 'Quantity', const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(_updatePricedAmount)),
          _textField(_unitPriceController, 'Rate (₹)', const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(_updatePricedAmount)),
          InputDecorator(
            decoration: _decoration('Amount (₹)', Icons.calculate_outlined),
            child: Text('₹${_baseAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ];
        return c.maxWidth >= 700
            ? Row(children: fields.map((f) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 8), child: f))).toList())
            : Column(children: fields);
      }),
      const SizedBox(height: 8),
      _textField(_freightController, 'Fright Charge (₹)', const TextInputType.numberWithOptions(decimal: true), required: false, onChanged: (_) => setState(() {})),
      Text('Total Amount: ₹${_baseAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF087A4F))),
      const SizedBox(height: 2),
      Text('Net Amount: ₹${_netTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF087A4F))),
    ],
  );

  void _updatePricedAmount() {
    if (_usesMaterialPricing && !_isFeed && !_isMedical) {
      final quantity = _parse(_quantityController);
      final rate = _parse(_unitPriceController);
      _amountController.text = (quantity * rate).toStringAsFixed(2);
      _amountAutoCalculated = true;
    }
  }

  Widget _buildGenericFields() => LayoutBuilder(builder: (context, c) { final fields = [_textField(_amountController, 'Amount (₹)', const TextInputType.numberWithOptions(decimal: true)), _textField(_unitController, 'Unit (kg, L, etc)', TextInputType.text), _textField(_quantityController, 'Quantity', const TextInputType.numberWithOptions(decimal: true))]; return c.maxWidth >= 700 ? Row(children: fields.map((f) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 8), child: f))).toList()) : Column(children: fields); });

  Widget _textField(TextEditingController controller, String label, TextInputType type, {bool required = true, ValueChanged<String>? onChanged}) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: TextFormField(controller: controller, onChanged: onChanged, keyboardType: type, style: const TextStyle(color: Color(0xFF172A21), fontWeight: FontWeight.w600), decoration: _decoration(label, Icons.edit_outlined), validator: (v) { if (required && (v == null || v.trim().isEmpty)) return 'Required'; if (v == null || v.trim().isEmpty) return null; if (type == const TextInputType.numberWithOptions(decimal: true)) { final n = double.tryParse(v.trim()); if (n == null || n < 0) return 'Enter a valid value'; } return null; }));
  InputDecoration _decoration(String label, IconData icon) => InputDecoration(labelText: label, labelStyle: const TextStyle(color: Color(0xFF708178), fontSize: 12), prefixIcon: Icon(icon, color: const Color(0xFF0E9F6E), size: 19), filled: true, fillColor: const Color(0xFFF9FBFA), border: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: Color(0xFFDCE7E0))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: Color(0xFFDCE7E0))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: Color(0xFF0E9F6E), width: 1.4)));

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isMedical && _medicalItems.isEmpty) { _show('Please add at least one medical item.'); return; }
    if (_isFeed && _feedItems.isEmpty) { _show('Please add at least one feed item.'); return; }
    if (_isFeed && _feedItems.any((x) => x.name.text.trim().isEmpty || x.quantityValue <= 0 || x.priceValue < 0)) { _show('Enter a feed item, positive bag quantity and valid bag price.'); return; }

    final amount = _baseAmount;
    final freight = _isEggSales ? 0.0 : _freight;
    final quantity = _isFeed ? _feedItems.fold(0.0, (sum, item) => sum + item.quantityValue) : (_isMedical || _selectedCategory == 'Electricity' ? 0.0 : _parse(_quantityController));
    final unitPrice = _isFeed ? (_feedItems.length == 1 ? _feedItems.first.priceValue : 0.0) : (_usesMaterialPricing ? _parse(_unitPriceController) : 0.0);
    final unit = _isFeed ? '50 kg/bag' : (_isEggSales ? _unitController.text.trim() : (_selectedCategory == 'Electricity' ? 'rupees' : _unitController.text.trim()));

    final record = ExpenseSalesLog(
      id: widget.existingRecord?.id,
      date: DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day),
      mainCategory: _selectedMainCategory,
      category: _selectedCategory,
      originalCategory: widget.existingRecord?.originalCategory ?? _selectedCategory,
      account: _selectedAccount,
      description: _isFeed ? (_descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : (_feedItems.length == 1 ? _feedItems.first.name.text.trim() : 'Feed purchase')) : (_selectedCategory == 'Electricity' ? 'Electricity bill' : _descriptionController.text.trim()),
      supplierId: _selectedSupplierId,
      supplierName: _selectedSupplierId == null
          ? null
          : (context.read<PoultryProvider>().suppliers.where((x) => x.id == _selectedSupplierId).isEmpty ? null : context.read<PoultryProvider>().suppliers.firstWhere((x) => x.id == _selectedSupplierId).fullName),
      amount: amount,
      unitPrice: unitPrice,
      freightCharge: freight,
      pricingCalculated: _amountAutoCalculated && ((!_isFeed && _usesMaterialPricing) || (_isFeed && _feedItems.length == 1)),
      medicalItems: _isMedical ? _medicalItems.map((e) => e.toMap()).toList() : const [],
      feedItems: _isFeed ? _feedItems.map((e) => e.toMap()).toList() : const [],
      unit: unit,
      quantity: quantity,
      transactionType: _isEggSales ? 'credit' : 'expense',
    );
    try {
      showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
      final provider = context.read<PoultryProvider>();
      if (_editing) { await provider.updateExpenseRecord(record); } else { await provider.addExpenseRecord(record); }
      if (!mounted) return;
      Navigator.pop(context);
      await _showSaveConfirmation();
    } catch (e) {
      if (mounted) { Navigator.pop(context); _show('Unable to ${_editing ? 'update' : 'save'} record: $e'); }
    }
  }

  void _show(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
}

class _MedicalItemDraft {
  final TextEditingController name;
  final TextEditingController price;
  final TextEditingController quantity;
  _MedicalItemDraft({String nameValue = '', double priceValue = 0, double quantityValue = 1}) : name = TextEditingController(text: nameValue), price = TextEditingController(text: priceValue.toString()), quantity = TextEditingController(text: quantityValue.toString());
  factory _MedicalItemDraft.fromMap(Map<String, dynamic> data) => _MedicalItemDraft(nameValue: data['name']?.toString() ?? '', priceValue: (data['price'] as num?)?.toDouble() ?? 0, quantityValue: (data['quantity'] as num?)?.toDouble() ?? 0);
  double get priceValue => double.tryParse(price.text.trim()) ?? 0;
  double get quantityValue => double.tryParse(quantity.text.trim()) ?? 0;
  double get total => priceValue * quantityValue;
  Map<String, dynamic> toMap() => {'name': name.text.trim(), 'price': priceValue, 'quantity': quantityValue, 'total': total};
  void dispose() { name.dispose(); price.dispose(); quantity.dispose(); }
}

class _FeedItemDraft {
  final TextEditingController name;
  final TextEditingController quantity;
  final TextEditingController price;
  _FeedItemDraft({String name = '', double quantity = 1, double pricePerBag = 0}) : name = TextEditingController(text: name), quantity = TextEditingController(text: quantity.toString()), price = TextEditingController(text: pricePerBag.toString());
  factory _FeedItemDraft.fromMap(Map<String, dynamic> data) => _FeedItemDraft(name: data['name']?.toString() ?? '', quantity: (data['quantity'] as num?)?.toDouble() ?? 0, pricePerBag: (data['pricePerBag'] as num?)?.toDouble() ?? (data['price'] as num?)?.toDouble() ?? 0);
  double get quantityValue => double.tryParse(quantity.text.trim()) ?? 0;
  double get priceValue => double.tryParse(price.text.trim()) ?? 0;
  double get total => quantityValue * priceValue;
  Map<String, dynamic> toMap() => {'name': name.text.trim(), 'quantity': quantityValue, 'pricePerBag': priceValue, 'bagWeightKg': 50, 'total': total};
  void dispose() { name.dispose(); quantity.dispose(); price.dispose(); }
}
