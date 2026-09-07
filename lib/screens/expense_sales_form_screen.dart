import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/expense_sales_log.dart';
import 'package:provider/provider.dart';
import '../providers/poultry_provider.dart';

class ExpenseSalesFormScreen extends StatefulWidget {
  const ExpenseSalesFormScreen({super.key});
  @override
  _ExpenseSalesFormScreenState createState() => _ExpenseSalesFormScreenState();
}

class _ExpenseSalesFormScreenState extends State<ExpenseSalesFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  DateTime _selectedDate = DateTime.now();
  String _selectedCategory = 'Feed';
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _unitController = TextEditingController();
  final _quantityController = TextEditingController();

  final List<String> categories = ['Medical', 'Feed', 'Grit', 'Other_Expenses', 'Egg_Sales'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Expense/Sales Record'),
        backgroundColor: Colors.black.withOpacity(0.3),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0f172a),
              Color(0xFF1e3a5f),
              Color(0xFF0f172a),
            ],
          ),
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16.0),
            child: Column(
              children: [
                ListTile(
                  title: Text('Date: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}',
                      style: TextStyle(color: Colors.white)),
                  trailing: Icon(Icons.calendar_today, color: Colors.cyan),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) setState(() => _selectedDate = date);
                  },
                ),
                SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<String>(
                    dropdownColor: Color(0xFF1e3a5f),
                    value: _selectedCategory,
                    isExpanded: true,
                    underline: SizedBox(),
                    items: categories.map((String category) {
                      return DropdownMenuItem<String>(
                        value: category,
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(category,
                              style: TextStyle(color: Colors.white)),
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() => _selectedCategory = newValue);
                      }
                    },
                  ),
                ),
                SizedBox(height: 16),
                _buildTextField(_descriptionController, 'Description', TextInputType.text),
                _buildTextField(_amountController, 'Amount', TextInputType.numberWithOptions(decimal: true)),
                _buildTextField(_unitController, 'Unit (kg, L, etc)', TextInputType.text),
                _buildTextField(_quantityController, 'Quantity', TextInputType.numberWithOptions(decimal: true)),
                SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _submitForm,
                  style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50)),
                  child: Text('Save Record'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, TextInputType type) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        style: TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white70),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
          ),
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
        ),
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
