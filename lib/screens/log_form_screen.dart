import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/poultry_log.dart';
import '../providers/poultry_provider.dart';
import '../widgets/app_shell.dart';

class LogFormScreen extends StatefulWidget {
  final PoultryLog? existingLog;
  final bool embedded;
  final VoidCallback? onEmbeddedBack;
  const LogFormScreen({super.key, this.existingLog, this.embedded = false, this.onEmbeddedBack});
  @override State<LogFormScreen> createState() => _LogFormScreenState();
}

class _LogFormScreenState extends State<LogFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dateFocusNode = FocusNode();
  DateTime _selectedDate = DateTime.now();
  bool _forceNewEntry = false;
  final _mortalityController = TextEditingController(text: '0');
  final _traysController = TextEditingController();
  final _avgTrayWeightController = TextEditingController();
  final _feedConsumedController = TextEditingController();
  final _stoneGritConsumedController = TextEditingController();
  final _waterIntakeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final existing = widget.existingLog;
    if (existing != null) {
      _selectedDate = DateTime(existing.date.year, existing.date.month, existing.date.day);
      _mortalityController.text = existing.mortality.toString();
      _traysController.text = existing.trays.toString();
      _avgTrayWeightController.text = existing.avgTrayWeight.toString();
      _feedConsumedController.text = existing.feedConsumed.toString();
      _stoneGritConsumedController.text = existing.stoneGritConsumed.toString();
      _waterIntakeController.text = existing.waterIntake.toString();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.existingLog == null) {
        final now = DateTime.now();
        _selectedDate = DateTime(now.year, now.month, now.day);
      }
    });
  }
  @override void dispose() { _dateFocusNode.dispose(); for(final c in [_mortalityController,_traysController,_avgTrayWeightController,_feedConsumedController,_stoneGritConsumedController,_waterIntakeController]) c.dispose(); super.dispose(); }

  bool get _editing => widget.existingLog != null && !_forceNewEntry;

  void _resetForNewEntry() {
    _forceNewEntry = true;
    _selectedDate = DateTime.now();
    _mortalityController.text = '0';
    _traysController.clear();
    _avgTrayWeightController.clear();
    _feedConsumedController.clear();
    _stoneGritConsumedController.clear();
    _waterIntakeController.clear();
    _formKey.currentState?.reset();
  }

  Future<void> _showSaveConfirmation() async {
    if (!mounted) return;
    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Daily Log Saved'),
        content: const Text('Your Daily Log was saved successfully. What would you like to do next?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, 'dashboard'), child: const Text('Back to Dashboard')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, 'previous'), child: const Text('Enter/Edit Previous Date')),
        ],
      ),
    );
    if (!mounted) return;
    if (action == 'dashboard') {
      if (widget.embedded) { widget.onEmbeddedBack?.call(); } else { Navigator.pop(context, true); }
    } else if (action == 'previous') {
      _resetForNewEntry();
      setState(() {});
      await Future<void>.delayed(Duration.zero);
      if (!mounted) return;
      _dateFocusNode.requestFocus();
      await _pickDate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Form(key: _formKey, child: LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= 1000;
        return ListView(padding: EdgeInsets.fromLTRB(wide ? 24 : 14, 8, wide ? 24 : 14, 28), children: [
          _dateHeader(wide),
          const SizedBox(height: 14),
          if (wide) _wideSections() else _narrowSections(),
          const SizedBox(height: 14),
          SizedBox(height: 50, child: FilledButton.icon(onPressed: _submitForm, icon: const Icon(Icons.save_outlined), label: Text(_editing ? 'Update Daily Log' : 'Save Daily Log'), style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0E9F6E), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), textStyle: const TextStyle(fontWeight: FontWeight.w800)))),
          const SizedBox(height: 8),
          const Center(child: Text('One daily log per date • Backdated entries allowed', style: TextStyle(color: Color(0xFF7A8A82), fontSize: 10))),
        ]);
      }));

    if (widget.embedded) return content;
    return PoultryAppShell(
      selectedIndex: 2,
      title: _editing ? 'Edit Daily Log' : 'Add Daily Log',
      subtitle: widget.existingLog == null ? 'Track daily flock data' : 'Update daily flock data',
      onBack: widget.embedded ? widget.onEmbeddedBack : () => Navigator.pop(context),
      onNavigate: _navigate,
      child: content,
    );
  }

  void _navigate(int index) {
    if(index == 2) return;
    if (widget.embedded) {
      widget.onEmbeddedBack?.call();
    } else {
      Navigator.pop(context);
    }
  }

  Widget _dateHeader(bool wide) => AppCard(child: _datePickerTile());

  Widget _datePickerTile() => Focus(
    focusNode: _dateFocusNode,
    child: InkWell(
    onTap: _pickDate,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBF9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDE8E1)),
      ),
      child: Row(
        children: [
          _iconBox(Icons.calendar_month_outlined, const Color(0xFF0E9F6E)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Date', style: TextStyle(fontSize: 11, color: Color(0xFF65766D))),
                const SizedBox(height: 3),
                Text(
                  DateFormat('dd MMM yyyy').format(_selectedDate),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF172A21)),
                ),
                const SizedBox(height: 2),
                Text(
                  'Earliest allowed: ${DateFormat('dd MMM yyyy').format(context.read<PoultryProvider>().farmConfig.flockStartDate.add(const Duration(days: 1)))}',
                  style: TextStyle(
                    fontSize: 9,
                    color: _selectedDate.isBefore(context.read<PoultryProvider>().farmConfig.flockStartDate.add(const Duration(days: 1))) ? Colors.red : const Color(0xFF789087),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.calendar_today_outlined, size: 18, color: Color(0xFF52675D)),
        ],
      ),
    ),
  ));

  Widget _wideSections() => Column(children: [_flockProduction(), const SizedBox(height: 14), _consumption()]);
  Widget _narrowSections() => Column(children: [_flockProduction(), const SizedBox(height:14), _consumption()]);
  Widget _flockProduction() => AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_sectionHeader('Flock & Production','Enter daily flock and egg production',Icons.pets_outlined,const Color(0xFF0E9F6E)), const SizedBox(height:12), _responsiveFields([_field(_mortalityController,'Mortality',Icons.warning_amber_outlined,integer:true),_field(_traysController,'Trays (30 eggs)',Icons.inventory_2_outlined),_field(_avgTrayWeightController,'Avg Tray Weight (g)',Icons.monitor_weight_outlined)])]));
  Widget _consumption() => AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_sectionHeader('Consumption','Track daily resource usage',Icons.inventory_2_outlined,const Color(0xFFF59E0B)), const SizedBox(height:12), _responsiveFields([_field(_feedConsumedController,'Feed Consumed (kg)',Icons.grass_outlined),_field(_stoneGritConsumedController,'Grit Consumed (kg)',Icons.scatter_plot_outlined),_field(_waterIntakeController,'Water Intake (L)',Icons.water_drop_outlined)])]));

  Widget _responsiveFields(List<Widget> fields) => LayoutBuilder(builder:(context,c){final n=c.maxWidth>=700?3:1;final w=(c.maxWidth-(n-1)*10)/n;return Wrap(spacing:10,runSpacing:10,children:fields.map((f)=>SizedBox(width:w,child:f)).toList());});
  Widget _field(TextEditingController c,String label,IconData icon,{bool integer=false}) => TextFormField(controller:c,keyboardType:TextInputType.numberWithOptions(decimal:!integer),style:const TextStyle(color:Color(0xFF172A21),fontWeight:FontWeight.w600),decoration:_decoration(label,icon),validator:(v){if(v==null||v.trim().isEmpty)return 'Required';final x=integer?int.tryParse(v.trim()):double.tryParse(v.trim());if(x==null||(x is num&&x<0))return 'Enter a valid non-negative value';return null;});
  InputDecoration _decoration(String label,IconData icon,{bool readOnly=false}) => InputDecoration(labelText:label,labelStyle:const TextStyle(color:Color(0xFF708178),fontSize:12),prefixIcon:Icon(icon,color:Color(0xFF0E9F6E),size:19),suffixIcon:readOnly?const Icon(Icons.lock_outline,size:17,color:Color(0xFF83928A)):null,filled:true,fillColor:readOnly?const Color(0xFFF0F4F2):const Color(0xFFF9FBFA),border:OutlineInputBorder(borderRadius:BorderRadius.circular(11),borderSide:const BorderSide(color:Color(0xFFDCE7E0))),enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(11),borderSide:const BorderSide(color:Color(0xFFDCE7E0))),focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(11),borderSide:const BorderSide(color:Color(0xFF0E9F6E),width:1.4)),errorBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(11),borderSide:const BorderSide(color:Color(0xFFDC4B45))));
  Widget _sectionHeader(String title,String subtitle,IconData icon,Color color)=>Row(children:[Container(width:36,height:36,decoration:BoxDecoration(color:color.withOpacity(.10),borderRadius:BorderRadius.circular(10)),child:Icon(icon,color:color,size:19)),const SizedBox(width:9),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontSize:16,fontWeight:FontWeight.w800,color:Color(0xFF162A21))),Text(subtitle,style:const TextStyle(fontSize:9,color:Color(0xFF788A81)))]))]);
  Widget _iconBox(IconData icon,Color color)=>Container(width:38,height:38,decoration:BoxDecoration(color:color.withOpacity(.10),borderRadius:BorderRadius.circular(10)),child:Icon(icon,color:color,size:20));

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final provider = context.read<PoultryProvider>();
    final minimumDate = provider.farmConfig.flockStartDate.add(const Duration(days: 1));
    final initial = _selectedDate.isBefore(minimumDate)
        ? minimumDate
        : (_selectedDate.isAfter(today) ? today : _selectedDate);
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: minimumDate,
      lastDate: today,
      helpText: 'SELECT DAILY LOG DATE',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF0E9F6E), surface: Colors.white)),
        child: child!,
      ),
    );
    if (date != null) setState(() => _selectedDate = DateTime(date.year, date.month, date.day));
  }

  Future<void> _submitForm() async {
    FocusScope.of(context).unfocus();
    final provider = context.read<PoultryProvider>();
    final normalized = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final minimumDate = provider.farmConfig.flockStartDate.add(const Duration(days: 1));
    if (normalized.isBefore(minimumDate)) { _show('Daily Log date cannot be before ${DateFormat('dd MMM yyyy').format(minimumDate)}.'); return; }
    if (!_formKey.currentState!.validate()) return;
    final editing = _editing;
    if (editing) {
      final originalDate = DateTime(widget.existingLog!.date.year, widget.existingLog!.date.month, widget.existingLog!.date.day);
      if (normalized != originalDate) {
        _show('The date of an existing Daily Log cannot be changed. Create a new log for another date.');
        return;
      }
    }
    final duplicate = provider.logs.any((l) {
      if (editing && l.date.year == widget.existingLog!.date.year && l.date.month == widget.existingLog!.date.month && l.date.day == widget.existingLog!.date.day) return false;
      final d = DateTime(l.date.year, l.date.month, l.date.day);
      return d == normalized;
    });
    if (duplicate) { _show('A Daily Log already exists for ${DateFormat('dd MMM yyyy').format(_selectedDate)}.'); return; }
    final mortality = int.tryParse(_mortalityController.text);
    if (mortality == null || mortality < 0) { _show('Mortality must be a valid whole number.'); return; }
    final trays = double.tryParse(_traysController.text) ?? 0;
    final feed = double.tryParse(_feedConsumedController.text) ?? 0;
    final avgWeight = double.tryParse(_avgTrayWeightController.text) ?? 0;
    final grit = double.tryParse(_stoneGritConsumedController.text) ?? 0;
    final water = double.tryParse(_waterIntakeController.text) ?? 0;
    final log = PoultryLog(date: normalized, mortality: mortality, trays: trays, totalEggs: 0, avgTrayWeight: avgWeight, feedConsumed: feed, stoneGritConsumed: grit, waterIntake: water , automatedFCR: 0);
    try {
      if (editing) { await provider.updateLog(log); } else { await provider.addLog(log); }
      if (mounted) await _showSaveConfirmation();
    } catch(e) { if (mounted) _show('Error ${editing ? 'updating' : 'saving'} log: $e'); }
  }
  void _show(String message)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(message),behavior:SnackBarBehavior.floating));
}
