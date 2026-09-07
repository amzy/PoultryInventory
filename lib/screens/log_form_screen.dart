import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/poultry_log.dart';
import '../providers/poultry_provider.dart';

class LogFormScreen extends StatefulWidget {
  @override
  _LogFormScreenState createState() => _LogFormScreenState();
}

class _LogFormScreenState extends State<LogFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  DateTime _selectedDate = DateTime.now();
  DateTime _flockStartDate = DateTime.now();
  final _startingBirdsController = TextEditingController();
  final _mortalityController = TextEditingController(text: '0');
  final _traysController = TextEditingController();
  final _avgTrayWeightController = TextEditingController();
  final _feedConsumedController = TextEditingController();
  final _stoneGritConsumedController = TextEditingController();
  final _waterIntakeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Always default to today's date
    _selectedDate = DateTime.now();
    
    final provider = Provider.of<PoultryProvider>(context, listen: false);
    if (provider.logs.isNotEmpty) {
      final lastLog = provider.logs.first;
      _flockStartDate = lastLog.date.subtract(Duration(days: lastLog.flockAge));
    } else {
      // First log ever: there is no previous day's bird count to calculate from.
      _flockStartDate = DateTime.now();
    }
    _updateStartingBirdsForDate(_selectedDate);
  }

  int _calculateFlockAge() {
    return _selectedDate.difference(_flockStartDate).inDays;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Add Daily Log')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.0),
          child: Column(
            children: [
              ListTile(
                title: Text('Date: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}'),
                trailing: Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() {
                      _selectedDate = date;
                      _updateStartingBirdsForDate(date);
                    });
                  }
                },
              ),
              ListTile(
                title: Text('Flock Age: ${_calculateFlockAge()} Days'),
                subtitle: Text('Auto-calculated from date'),
              ),
              _buildReadOnlyField(
                _startingBirdsController,
                'Starting Birds',
                'Auto: previous day Starting Birds - Mortality',
              ),
              _buildTextField(_mortalityController, 'Mortality', TextInputType.number),
              _buildTextField(_traysController, 'Trays (30 Eggs)', TextInputType.numberWithOptions(decimal: true)),
              _buildTextField(_avgTrayWeightController, 'Avg Tray Weight (g)', TextInputType.numberWithOptions(decimal: true)),
              _buildTextField(_feedConsumedController, 'Feed Consumed (kg)', TextInputType.numberWithOptions(decimal: true)),
              _buildTextField(_stoneGritConsumedController, 'Stone/Grit Consumed (kg)', TextInputType.numberWithOptions(decimal: true)),
              _buildTextField(_waterIntakeController, 'Water Intake (L)', TextInputType.numberWithOptions(decimal: true)),
              SizedBox(height: 32),
              ElevatedButton(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50)),
                child: Text('Save Log'),
              ),
            ],
          ),
        ),
      ),
    );
  }


  /// Starting birds are never entered manually. For a daily entry, they are
  /// calculated from the latest log before the selected date:
  /// previous day's Starting Birds - previous day's Mortality.
  void _updateStartingBirdsForDate(DateTime date) {
    final provider = Provider.of<PoultryProvider>(context, listen: false);
    PoultryLog? previousLog;

    for (final log in provider.logs) {
      final logDate = DateTime(log.date.year, log.date.month, log.date.day);
      final selected = DateTime(date.year, date.month, date.day);
      if (logDate.isBefore(selected) &&
          (previousLog == null || logDate.isAfter(DateTime(
            previousLog!.date.year,
            previousLog!.date.month,
            previousLog!.date.day,
          )))) {
        previousLog = log;
      }
    }

    if (previousLog == null) {
      _startingBirdsController.text = '';
    } else {
      final calculated = previousLog.startingBirds - previousLog.mortality;
      _startingBirdsController.text = calculated.clamp(0, 1000000000).toString();
    }
  }

  Widget _buildReadOnlyField(
    TextEditingController controller,
    String label,
    String helperText,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        enabled: true,
        decoration: InputDecoration(
          labelText: label,
          helperText: helperText,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.lock_outline),
        ),
        validator: (value) => value == null || value.isEmpty
            ? 'No previous daily log found for this date'
            : null,
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, TextInputType type) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label, border: OutlineInputBorder()),
        keyboardType: type,
        validator: (value) => value == null || value.isEmpty ? 'Required' : null,
      ),
    );
  }

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final startingBirds = int.parse(_startingBirdsController.text);
    final mortality = int.parse(_mortalityController.text);
    if (mortality > startingBirds) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mortality cannot be greater than Starting Birds')),
      );
      return;
    }
    final endingBirds = startingBirds - mortality;
    
    final trays = double.parse(_traysController.text);
    final totalEggs = (trays * 30).round();
    
    final feed = double.parse(_feedConsumedController.text);
    
    // Tray-wise FCR = Feed Consumed (kg) / 30-egg trays
    final fcr = trays > 0 ? feed / trays : 0.0;
    
    // Laying Percentage = (Total Eggs / Ending Birds) * 100
    final layingPercentage = endingBirds > 0 ? (totalEggs / endingBirds) * 100 : 0.0;

    final log = PoultryLog(
      date: _selectedDate,
      flockAge: _calculateFlockAge(),
      startingBirds: startingBirds,
      mortality: mortality,
      endingBirds: endingBirds,
      trays: trays,
      totalEggs: totalEggs,
      avgTrayWeight: double.parse(_avgTrayWeightController.text),
      feedConsumed: feed,
      stoneGritConsumed: double.parse(_stoneGritConsumedController.text),
      waterIntake: double.parse(_waterIntakeController.text),
      automatedFCR: fcr,
      layingPercentage: layingPercentage,
    );

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(child: CircularProgressIndicator()),
      );
      
      await Provider.of<PoultryProvider>(context, listen: false).addLog(log);
      
      Navigator.pop(context); // Close loading dialog
      Navigator.pop(context); // Go back to dashboard
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Log saved successfully')),
      );
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving log: $e')),
      );
    }
  }
}
