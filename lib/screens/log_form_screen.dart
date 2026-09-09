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
  static final DateTime _minimumLogDate = DateTime(2026, 4, 27);
  final _formKey = GlobalKey<FormState>();
  DateTime _selectedDate = DateTime.now();
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
    for(final c in [_mortalityController,_traysController,_feedConsumedController]) c.addListener(_refreshPreview);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.existingLog == null) {
        final now = DateTime.now();
        _selectedDate = DateTime(now.year, now.month, now.day);
      }
    });
  }
  @override void dispose() { for(final c in [_mortalityController,_traysController,_feedConsumedController]) c.removeListener(_refreshPreview); for(final c in [_mortalityController,_traysController,_avgTrayWeightController,_feedConsumedController,_stoneGritConsumedController,_waterIntakeController]) c.dispose(); super.dispose(); }
  void _refreshPreview() { if(mounted) setState(() {}); }

  @override
  Widget build(BuildContext context) {
    final content = Form(key: _formKey, child: LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= 1000;
        return ListView(padding: EdgeInsets.fromLTRB(wide ? 24 : 14, 8, wide ? 24 : 14, 28), children: [
          _dateHeader(wide),
          const SizedBox(height: 14),
          if (wide) _wideSections() else _narrowSections(),
          const SizedBox(height: 14),
          _calculatedPreview(wide),
          const SizedBox(height: 14),
          SizedBox(height: 50, child: FilledButton.icon(onPressed: _submitForm, icon: const Icon(Icons.save_outlined), label: Text(widget.existingLog == null ? 'Save Daily Log' : 'Update Daily Log'), style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0E9F6E), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), textStyle: const TextStyle(fontWeight: FontWeight.w800)))),
          const SizedBox(height: 8),
          const Center(child: Text('One daily log per date • Backdated entries allowed', style: TextStyle(color: Color(0xFF7A8A82), fontSize: 10))),
        ]);
      }));

    if (widget.embedded) return content;
    return PoultryAppShell(
      selectedIndex: 1,
      title: widget.existingLog == null ? 'Add Daily Log' : 'Edit Daily Log',
      subtitle: widget.existingLog == null ? 'Track daily flock data' : 'Update daily flock data',
      onBack: widget.embedded ? widget.onEmbeddedBack : () => Navigator.pop(context),
      onNavigate: _navigate,
      child: content,
    );
  }

  void _navigate(int index) {
    if(index == 1) return;
    if (widget.embedded) {
      widget.onEmbeddedBack?.call();
    } else {
      Navigator.pop(context);
    }
  }

  Widget _dateHeader(bool wide) => AppCard(child: _datePickerTile());

  Widget _datePickerTile() => InkWell(
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
                  'Earliest allowed: 27 Apr 2026',
                  style: TextStyle(
                    fontSize: 9,
                    color: _selectedDate.isBefore(_minimumLogDate) ? Colors.red : const Color(0xFF789087),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.calendar_today_outlined, size: 18, color: Color(0xFF52675D)),
        ],
      ),
    ),
  );

  Widget _wideSections() => Column(children: [_flockProduction(), const SizedBox(height: 14), _consumption()]);
  Widget _narrowSections() => Column(children: [_flockProduction(), const SizedBox(height:14), _consumption()]);
  Widget _flockProduction() => AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_sectionHeader('Flock & Production','Enter daily flock and egg production',Icons.pets_outlined,const Color(0xFF0E9F6E)), const SizedBox(height:12), _responsiveFields([_field(_mortalityController,'Mortality',Icons.warning_amber_outlined,integer:true),_field(_traysController,'Trays (30 eggs)',Icons.inventory_2_outlined),_field(_avgTrayWeightController,'Avg Tray Weight (g)',Icons.monitor_weight_outlined)])]));
  Widget _consumption() => AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_sectionHeader('Consumption','Track daily resource usage',Icons.inventory_2_outlined,const Color(0xFFF59E0B)), const SizedBox(height:12), _responsiveFields([_field(_feedConsumedController,'Feed Consumed (kg)',Icons.grass_outlined),_field(_stoneGritConsumedController,'Grit Consumed (kg)',Icons.scatter_plot_outlined),_field(_waterIntakeController,'Water Intake (L)',Icons.water_drop_outlined)])]));

  Widget _responsiveFields(List<Widget> fields) => LayoutBuilder(builder:(context,c){final n=c.maxWidth>=700?3:1;final w=(c.maxWidth-(n-1)*10)/n;return Wrap(spacing:10,runSpacing:10,children:fields.map((f)=>SizedBox(width:w,child:f)).toList());});
  Widget _field(TextEditingController c,String label,IconData icon,{bool integer=false}) => TextFormField(controller:c,keyboardType:TextInputType.numberWithOptions(decimal:!integer),style:const TextStyle(color:Color(0xFF172A21),fontWeight:FontWeight.w600),decoration:_decoration(label,icon),validator:(v){if(v==null||v.trim().isEmpty)return 'Required';final x=integer?int.tryParse(v.trim()):double.tryParse(v.trim());if(x==null||(x is num&&x<0))return 'Enter a valid non-negative value';return null;});
  InputDecoration _decoration(String label,IconData icon,{bool readOnly=false}) => InputDecoration(labelText:label,labelStyle:const TextStyle(color:Color(0xFF708178),fontSize:12),prefixIcon:Icon(icon,color:Color(0xFF0E9F6E),size:19),suffixIcon:readOnly?const Icon(Icons.lock_outline,size:17,color:Color(0xFF83928A)):null,filled:true,fillColor:readOnly?const Color(0xFFF0F4F2):const Color(0xFFF9FBFA),border:OutlineInputBorder(borderRadius:BorderRadius.circular(11),borderSide:const BorderSide(color:Color(0xFFDCE7E0))),enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(11),borderSide:const BorderSide(color:Color(0xFFDCE7E0))),focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(11),borderSide:const BorderSide(color:Color(0xFF0E9F6E),width:1.4)),errorBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(11),borderSide:const BorderSide(color:Color(0xFFDC4B45))));
  Widget _sectionHeader(String title,String subtitle,IconData icon,Color color)=>Row(children:[Container(width:36,height:36,decoration:BoxDecoration(color:color.withOpacity(.10),borderRadius:BorderRadius.circular(10)),child:Icon(icon,color:color,size:19)),const SizedBox(width:9),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontSize:16,fontWeight:FontWeight.w800,color:Color(0xFF162A21))),Text(subtitle,style:const TextStyle(fontSize:9,color:Color(0xFF788A81)))]))]);
  Widget _iconBox(IconData icon,Color color)=>Container(width:38,height:38,decoration:BoxDecoration(color:color.withOpacity(.10),borderRadius:BorderRadius.circular(10)),child:Icon(icon,color:color,size:20));

  int _previewStartingBirds() {
    final provider = Provider.of<PoultryProvider>(context, listen: false);
    final selected = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    PoultryLog? previous;
    for (final log in provider.logs) {
      if (widget.existingLog != null &&
          log.date.year == widget.existingLog!.date.year &&
          log.date.month == widget.existingLog!.date.month &&
          log.date.day == widget.existingLog!.date.day) continue;
      final d = DateTime(log.date.year, log.date.month, log.date.day);
      if (d.isBefore(selected) && (previous == null || d.isAfter(DateTime(previous!.date.year, previous!.date.month, previous!.date.day)))) {
        previous = log;
      }
    }
    return previous?.endingBirds ?? 5200;
  }

  Widget _calculatedPreview(bool wide) {
    final starting = _previewStartingBirds();
    final mortality = int.tryParse(_mortalityController.text) ?? 0;
    final trays = double.tryParse(_traysController.text) ?? 0;
    final feed = double.tryParse(_feedConsumedController.text) ?? 0;
    final ending = (starting - mortality).clamp(0, 1000000000);
    final eggs = (trays * 30).round();
    final fcr = trays > 0 ? feed / trays : 0;
    final laying = ending > 0 ? eggs / ending * 100 : 0;
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFFE5F6EC), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFCBE8D6))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionHeader('Calculated Preview', 'Starting birds are calculated automatically', Icons.calculate_outlined, const Color(0xFF0E9F6E)),
      const SizedBox(height: 12),
      LayoutBuilder(builder: (context, c) {
        final n = c.maxWidth >= 700 ? 4 : 2;
        final w = (c.maxWidth - (n - 1) * 10) / n;
        return Wrap(spacing: 10, runSpacing: 10, children: [
          _preview('Starting Birds', '$starting', Icons.lock_outline),
          _preview('Ending Birds', '$ending', Icons.pets_outlined),
          _preview('Total Eggs', '$eggs', Icons.egg_alt_outlined),
          _preview('FCR', fcr.toStringAsFixed(2), Icons.speed_outlined),
          _preview('Laying %', '${laying.toStringAsFixed(1)}%', Icons.bar_chart_outlined),
        ].map((x) => SizedBox(width: n == 4 ? (c.maxWidth - 30) / 4 : (c.maxWidth - 10) / 2, child: x)).toList());
      }),
    ]));
  }
  Widget _preview(String label, String value, IconData icon) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFDDEAE1)),
    ),
    child: Row(
      children: [
        Icon(icon, color: const Color(0xFF0E9F6E), size: 19),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF6F8177))),
              Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF142A20))),
            ],
          ),
        ),
      ],
    ),
  );

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initial = _selectedDate.isBefore(_minimumLogDate) ? _minimumLogDate : (_selectedDate.isAfter(today) ? today : _selectedDate);
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: _minimumLogDate,
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
    final normalized = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    if (normalized.isBefore(_minimumLogDate)) { _show('Daily Log date cannot be before 27 Apr 2026.'); return; }
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<PoultryProvider>();
    final editing = widget.existingLog != null;
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
    // Starting birds and all calculated fields are intentionally hidden from the form.
    // FirebaseService/PoultryCalculationService derives starting birds from the previous
    // log or the 5200 opening flock when this is the first log.
    final log = PoultryLog(date: normalized, startingBirds: 0, mortality: mortality, endingBirds: 0, trays: trays, totalEggs: 0, avgTrayWeight: avgWeight, feedConsumed: feed, stoneGritConsumed: grit, waterIntake: water, automatedFCR: 0, layingPercentage: 0);
    try {
      if (editing) { await provider.updateLog(log); } else { await provider.addLog(log); }
      if (mounted) Navigator.pop(context, true);
    } catch(e) { if (mounted) _show('Error ${editing ? 'updating' : 'saving'} log: $e'); }
  }
  void _show(String message)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(message),behavior:SnackBarBehavior.floating));
}
