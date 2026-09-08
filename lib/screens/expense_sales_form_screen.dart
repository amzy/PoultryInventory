import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/expense_sales_log.dart';
import 'package:provider/provider.dart';
import '../providers/poultry_provider.dart';
import '../widgets/app_shell.dart';

class ExpenseSalesFormScreen extends StatefulWidget {
  final String? initialCategory;
  const ExpenseSalesFormScreen({super.key, this.initialCategory});
  @override
  _ExpenseSalesFormScreenState createState() => _ExpenseSalesFormScreenState();
}

class _ExpenseSalesFormScreenState extends State<ExpenseSalesFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  DateTime _selectedDate = DateTime.now();
  late String _selectedCategory;
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _unitController = TextEditingController();
  final _quantityController = TextEditingController();

  final List<String> categories = ['Medical', 'Feed', 'Grit', 'Other_Expenses', 'Egg_Sales'];

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory != null && categories.contains(widget.initialCategory)
        ? widget.initialCategory!
        : 'Feed';
  }

  @override
  Widget build(BuildContext context) {
    return PoultryAppShell(
      selectedIndex: _navIndex,
      title: 'Add ${_selectedCategory == 'Egg_Sales' ? 'Egg Sales' : 'Expense'}',
      subtitle: 'Record farm financial activity',
      onBack: () => Navigator.pop(context),
      onNavigate: (index) { if (index != _navIndex) Navigator.pop(context); },
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
          children: [
            AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Record Details', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF162A21))),
              const SizedBox(height: 4),
              const Text('Enter the date, category and transaction details.', style: TextStyle(fontSize: 10, color: Color(0xFF75867D))),
              const SizedBox(height: 14),
              InkWell(onTap: _pickDate, borderRadius: BorderRadius.circular(11), child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFF8FBF9), borderRadius: BorderRadius.circular(11), border: Border.all(color: const Color(0xFFDCE7E0))), child: Row(children: [const Icon(Icons.calendar_month_outlined, color: Color(0xFF0E9F6E)), const SizedBox(width: 10), Expanded(child: Text(DateFormat('dd MMM yyyy').format(_selectedDate), style: const TextStyle(fontWeight: FontWeight.w700))), const Icon(Icons.chevron_right, color: Color(0xFF71827A))]))),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(value: _selectedCategory, decoration: _decoration('Category', Icons.category_outlined), items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c.replaceAll('_',' ')))).toList(), onChanged: (v) => setState(() => _selectedCategory = v ?? 'Feed')),
              const SizedBox(height: 10),
              _buildTextField(_descriptionController, 'Description', TextInputType.text),
              const SizedBox(height: 10),
              LayoutBuilder(builder: (context, c) { final wide=c.maxWidth>=700; final fields=[_buildTextField(_amountController,'Amount',TextInputType.numberWithOptions(decimal:true)),_buildTextField(_unitController,'Unit (kg, L, etc)',TextInputType.text),_buildTextField(_quantityController,'Quantity',TextInputType.numberWithOptions(decimal:true))]; return wide ? Row(children: fields.map((f)=>Expanded(child:Padding(padding:const EdgeInsets.only(right:8),child:f))).toList()) : Column(children: fields); }),
            ])),
            const SizedBox(height: 14),
            SizedBox(height: 50, child: FilledButton.icon(onPressed: _submitForm, icon: const Icon(Icons.save_outlined), label: const Text('Save Record'), style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0E9F6E), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), textStyle: const TextStyle(fontWeight: FontWeight.w800)))),
          ],
        ),
      ),
    );
  }

  int get _navIndex {
    switch (_selectedCategory) {
      case 'Medical': return 2;
      case 'Feed': return 3;
      case 'Grit': return 4;
      case 'Other_Expenses': return 5;
      case 'Egg_Sales': return 6;
      default: return 3;
    }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2026,4,27), lastDate: DateTime.now());
    if (d != null) setState(() => _selectedDate = d);
  }

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(labelText: label, labelStyle: const TextStyle(color: Color(0xFF708178), fontSize: 12), prefixIcon: Icon(icon, color: const Color(0xFF0E9F6E), size: 19), filled: true, fillColor: const Color(0xFFF9FBFA), border: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: Color(0xFFDCE7E0))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: Color(0xFFDCE7E0))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: Color(0xFF0E9F6E), width: 1.4)));

  Widget _buildTextField(TextEditingController controller, String label, TextInputType type) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(color: Color(0xFF172A21), fontWeight: FontWeight.w600),
        decoration: _decoration(label, Icons.edit_outlined),
        keyboardType: type,
        validator: (value) => value == null || value.isEmpty ? 'Required' : null,
      ),
    );
  }

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final log = ExpenseSalesLog(
      date: _selectedDate,
      category: _selectedCategory,
      description: _descriptionController.text,
      amount: double.parse(_amountController.text),
      unit: _unitController.text,
      quantity: double.parse(_quantityController.text),
    );

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(Color(0xFF00D9FF)),
          ),
        ),
      );
      
      await context.read<PoultryProvider>().addExpenseRecord(log);
      if (!mounted) return;
      Navigator.pop(context); // Close loading
      Navigator.pop(context, true); // Return to dashboard

    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving record: $e')),
      );
    }
  }
}
