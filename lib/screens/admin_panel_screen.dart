import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/flock.dart';
import '../models/supplier.dart';
import '../providers/poultry_provider.dart';
import '../services/farm_config.dart';
import '../services/app_sql_export.dart';
import '../services/sql_file_saver.dart';
import '../services/cashew_sqlite_importer.dart';
import '../widgets/app_shell.dart';

class AdminPanelScreen extends StatefulWidget {
  final bool embedded;
  final bool adminOnly;
  const AdminPanelScreen({super.key, this.embedded = false, this.adminOnly = false});
  @override State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final _name = TextEditingController();
  final _birds = TextEditingController();
  final _breed = TextEditingController();
  final _email = TextEditingController();
  final List<TextEditingController> _accounts = [];
  final List<TextEditingController> _feeds = [];
  final List<TextEditingController> _subcategories = [];
  final _supplierName = TextEditingController();
  final _supplierAddress = TextEditingController();
  final _supplierContact = TextEditingController();
  String? _editingSupplierId;
  DateTime _start = DateTime.now();
  DateTime? _end;
  bool _busy = false;
  String _dataStatus = '';
  final _notifTitleEn = TextEditingController(text: 'Daily Farm Update');
  final _notifTitleHi = TextEditingController(text: 'दैनिक फार्म अपडेट');
  final _notifBodyEn = TextEditingController(text: "Please complete today's report for {flockName}.");
  final _notifBodyHi = TextEditingController(text: 'कृपया {flockName} की आज की रिपोर्ट दर्ज करें।');
  bool _notificationsEnabled = true;
  bool _dailyReminderEnabled = true;
  bool _secondReminderEnabled = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 20, minute: 0);
  TimeOfDay _secondReminderTime = const TimeOfDay(hour: 22, minute: 0);

  @override void initState() { super.initState(); WidgetsBinding.instance.addPostFrameCallback((_) => _load()); }
  Future<void> _load() async {
    final p = context.read<PoultryProvider>();
    final f = p.activeFlock;
    if (f == null) return;
    _name.text = f.name; _birds.text = f.startingBirds.toString(); _breed.text = f.breedName; _start = f.startDate; _end = f.endDate;
    for (final c in _accounts) c.dispose(); for (final c in _feeds) c.dispose(); for (final c in _subcategories) c.dispose(); _accounts.clear(); _feeds.clear(); _subcategories.clear();
    for (final x in f.accounts) _accounts.add(TextEditingController(text: x));
    final globalFeeds = p.feedItems;
    for (final x in globalFeeds) _feeds.add(TextEditingController(text: x));
    if (_accounts.isEmpty) for (final x in FarmConfig.defaultAccounts) _accounts.add(TextEditingController(text: x));
    if (_feeds.isEmpty) for (final x in FarmConfig.defaultFeedItems) _feeds.add(TextEditingController(text: x));
    for (final x in p.expenseSubcategories) _subcategories.add(TextEditingController(text: x));
    try {
      final settings = await context.read<PoultryProvider>().fetchNotificationSettings();
      if (settings != null && mounted) {
        setState(() {
          _notificationsEnabled = settings['enabled'] != false;
          _dailyReminderEnabled = settings['dailyReportReminder'] != false;
          _secondReminderEnabled = settings['secondReminderEnabled'] == true;
          _reminderTime = TimeOfDay(hour: (settings['reminderHour'] as num?)?.toInt() ?? 20, minute: (settings['reminderMinute'] as num?)?.toInt() ?? 0);
          _secondReminderTime = TimeOfDay(hour: (settings['secondReminderHour'] as num?)?.toInt() ?? 22, minute: (settings['secondReminderMinute'] as num?)?.toInt() ?? 0);
        });
      }
      final template = await context.read<PoultryProvider>().fetchNotificationTemplate('daily_report_reminder');
      if (template != null && mounted) {
        _notifTitleEn.text = template['titleEn']?.toString() ?? _notifTitleEn.text;
        _notifTitleHi.text = template['titleHi']?.toString() ?? _notifTitleHi.text;
        _notifBodyEn.text = template['bodyEn']?.toString() ?? _notifBodyEn.text;
        _notifBodyHi.text = template['bodyHi']?.toString() ?? _notifBodyHi.text;
      }
    } catch (_) {}
    setState(() {});
  }
  @override void dispose() { _name.dispose(); _birds.dispose(); _breed.dispose(); _email.dispose(); _supplierName.dispose(); _supplierAddress.dispose(); _supplierContact.dispose(); _notifTitleEn.dispose(); _notifTitleHi.dispose(); _notifBodyEn.dispose(); _notifBodyHi.dispose(); for (final c in _accounts) c.dispose(); for (final c in _feeds) c.dispose(); for (final c in _subcategories) c.dispose(); super.dispose(); }

  Future<void> _save() async {
    final p = context.read<PoultryProvider>();
    final birds = int.tryParse(_birds.text.trim());
    final name = _name.text.trim();
    if (name.isEmpty || birds == null || birds < 0) { _snack('Enter a flock name and valid starting bird count.'); return; }
    final accounts = _accounts.map((c) => c.text.trim()).where((x) => x.isNotEmpty).toSet().toList();
    if (accounts.isEmpty) { _snack('Keep at least one account.'); return; }
    setState(() => _busy = true);
    try {
      if (p.activeFlock == null) {
        await p.createFlock(name: name, startDate: _start, startingBirds: birds, breedName: _breed.text.trim(), accounts: accounts, feedItems: p.feedItems);
      } else {
        await p.updateActiveFlock(name: name, startDate: _start, startingBirds: birds, breedName: _breed.text.trim(), accounts: accounts, endDate: _end);
      }
      _snack('Flock configuration saved.');
    } catch (e) { _snack('Unable to save flock: $e'); } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _createNew() async {
    final p = context.read<PoultryProvider>();
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('Create New Flock'), content: const Text('Create a new flock and make it the active flock? Existing flock data remains unchanged.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create'))]));
    if (ok != true) return;
    final name = TextEditingController(text: 'New Flock'); final birds = TextEditingController(text: FarmConfig.defaultStartingBirds.toString());
    DateTime start = DateTime.now();
    final created = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(title: const Text('New Flock Details'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: name, decoration: const InputDecoration(labelText: 'Flock Name')), const SizedBox(height: 10), TextField(controller: birds, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Starting Birds')), const SizedBox(height: 10), StatefulBuilder(builder: (c, set) => ListTile(title: Text('Start: ${DateFormat('dd MMM yyyy').format(start)}'), trailing: const Icon(Icons.calendar_today), onTap: () async { final d = await showDatePicker(context: c, initialDate: start, firstDate: DateTime(2000), lastDate: DateTime.now()); if (d != null) set(() => start = d); }))]), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Create'))]));
    if (created != true || !mounted) return;
    try { await p.createFlock(name: name.text.trim(), startDate: start, startingBirds: int.tryParse(birds.text) ?? 0, breedName: '', accounts: FarmConfig.defaultAccounts, feedItems: FarmConfig.defaultFeedItems); _load(); _snack('New flock created.'); } catch (e) { _snack('Unable to create flock: $e'); }
    name.dispose(); birds.dispose();
  }

  Future<void> _invite() async { final email = _email.text.trim(); if (email.isEmpty) { _snack('Enter the registered email address.'); return; } try { await context.read<PoultryProvider>().inviteFlockMember(email); _email.clear(); _snack('Invitation saved. The user will get access after signing in with that registered email.'); } catch (e) { _snack('Unable to add user: $e'); } }
  Future<void> _exportData() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final sql = AppSqlExport.buildExpenseSql(
        context.read<PoultryProvider>().expenseRecords,
        flockId: context.read<PoultryProvider>().activeFlock?.id,
        flockName: context.read<PoultryProvider>().activeFlock?.name,
        breedName: context.read<PoultryProvider>().activeFlock?.breedName,
      );
      final path = await saveSqlFile(Uint8List.fromList(utf8.encode(sql)), 'poultry_inventory_${context.read<PoultryProvider>().activeFlock?.name.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_') ?? 'flock'}.sql');
      _snack(path == null ? 'Export cancelled.' : 'Flock data exported.');
    } catch (e) { _snack('Export failed: $e'); } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _importData() async {
    if (_busy) return;
    final picked = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['sql','db','sqlite','sqlite3'], withData: true);
    final bytes = picked?.files.single.bytes;
    if (bytes == null || bytes.isEmpty) return;
    setState(() { _busy = true; _dataStatus = 'Reading import file…'; });
    try {
      final records = await parseCashewSqliteBytes(bytes);
      final result = await context.read<PoultryProvider>().importCashewRecords(records, onProgress: (m) { if (mounted) setState(() => _dataStatus = m); });
      _snack('${result.imported} imported, ${result.updated} updated, ${result.unchanged} unchanged.');
    } catch (e) { _snack('Import failed: $e'); } finally { if (mounted) setState(() { _busy = false; _dataStatus = ''; }); }
  }

  void _snack(String text) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text))); }

  @override Widget build(BuildContext context) {
    return Consumer<PoultryProvider>(builder: (context, p, _) {
      if (!p.isAdmin) return const Center(child: Text('Admin access required.'));
      final adminSections = <Widget>[
        _subcategoriesSection(p),
        const SizedBox(height: 12),
        _suppliersSection(p),
        const SizedBox(height: 12),
        _membersSection(p),
        const SizedBox(height: 12),
        _notificationsSection(p),
      ];
      final fullSections = <Widget>[
        _flockSelector(p), const SizedBox(height: 12),
        _section('Flock Configuration', Icons.pets_outlined, Column(children: [
          _fields(), const SizedBox(height: 12),
          _listEditor('Expense Accounts', _accounts, 'Account', Icons.person_outline),
          const SizedBox(height: 12),
          Row(children: [Expanded(child: FilledButton.icon(onPressed: _busy ? null : _save, icon: const Icon(Icons.save_outlined), label: const Text('Save Flock'))), const SizedBox(width: 8), OutlinedButton.icon(onPressed: _createNew, icon: const Icon(Icons.add), label: const Text('New Flock'))]),
        ])),
        const SizedBox(height: 12),
        _section('Feed Items', Icons.grass_outlined, Column(children: [
          const Align(alignment: Alignment.centerLeft, child: Text('Feed items are independent of flock configuration and shared across flocks.', style: TextStyle(fontSize: 11, color: Color(0xFF75867D)))),
          const SizedBox(height: 10),
          _listEditor('Feed Catalog', _feeds, 'Feed Item', Icons.grass_outlined),
          const SizedBox(height: 10),
          Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: _busy ? null : () async {
            final items = _feeds.map((c) => c.text.trim()).where((x) => x.isNotEmpty).toSet().toList();
            try { await p.saveFeedItems(items); _snack('Feed items saved for all flocks.'); } catch (e) { _snack('Unable to save feed items: $e'); }
          }, icon: const Icon(Icons.save_outlined), label: const Text('Save Feed Items'))),
        ])),
        const SizedBox(height: 12),
        ...adminSections,
      ];
      final content = ListView(padding: const EdgeInsets.fromLTRB(14, 8, 14, 30), children: widget.adminOnly ? adminSections : fullSections);
      if (widget.embedded) return widget.adminOnly ? Column(children: adminSections) : content;
      return PoultryAppShell(selectedIndex: 9, title: 'Settings', subtitle: 'Administration', child: content);
    });
  }

  Widget _flockSelector(PoultryProvider p) => AppCard(
    child: Row(children: [
      const Icon(Icons.filter_alt_outlined, color: Color(0xFF087A4F)),
      const SizedBox(width: 10),
      Expanded(
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            value: p.activeFlockId.isEmpty ? null : p.activeFlockId,
            hint: const Text('Select flock'),
            items: p.flocks.map((f) => DropdownMenuItem(value: f.id, child: Text('${f.name} • ${f.isActive ? 'Active' : 'Ended'}'))).toList(),
            onChanged: (id) { if (id != null) p.selectFlock(id).then((_) => _load()); },
          ),
        ),
      ),
    ]),
  );
  Widget _fields() => LayoutBuilder(builder: (context, c) { final children = [TextField(controller: _name, decoration: const InputDecoration(labelText: 'Flock Name', border: OutlineInputBorder())), TextField(controller: _breed, decoration: const InputDecoration(labelText: 'Breed Name', border: OutlineInputBorder())), TextField(controller: _birds, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Starting Birds', border: OutlineInputBorder())), ListTile(shape: RoundedRectangleBorder(side: const BorderSide(color: Color(0xFFDCE7E0)), borderRadius: BorderRadius.circular(4)), title: Text('Start: ${DateFormat('dd MMM yyyy').format(_start)}'), trailing: const Icon(Icons.calendar_today), onTap: () async { final d = await showDatePicker(context: context, initialDate: _start, firstDate: DateTime(2000), lastDate: DateTime.now()); if (d != null) setState(() => _start = d); }), ListTile(shape: RoundedRectangleBorder(side: const BorderSide(color: Color(0xFFDCE7E0)), borderRadius: BorderRadius.circular(4)), title: Text(_end == null ? 'End: Active flock' : 'End: ${DateFormat('dd MMM yyyy').format(_end!)}'), trailing: Icon(_end == null ? Icons.lock_open_outlined : Icons.event_busy_outlined), onTap: () async { final d = await showDatePicker(context: context, initialDate: _end ?? DateTime.now(), firstDate: _start, lastDate: DateTime.now()); if (d != null) setState(() => _end = d); })]; return Wrap(spacing: 10, runSpacing: 10, children: children.map((w) => SizedBox(width: c.maxWidth >= 900 ? (c.maxWidth - 20) / 3 : c.maxWidth, child: w)).toList()); });
  Widget _listEditor(String title, List<TextEditingController> list, String hint, IconData icon) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 6), ...list.asMap().entries.map((e) => Padding(padding: const EdgeInsets.only(bottom: 7), child: Row(children: [Expanded(child: TextField(controller: e.value, decoration: InputDecoration(prefixIcon: Icon(icon), labelText: '$hint ${e.key + 1}', border: const OutlineInputBorder()))), IconButton(onPressed: () => setState(() { final c = list.removeAt(e.key); c.dispose(); }), icon: const Icon(Icons.remove_circle_outline, color: Colors.red))]))), OutlinedButton.icon(onPressed: () => setState(() => list.add(TextEditingController())), icon: const Icon(Icons.add), label: Text('Add $hint'))]);
  Widget _subcategoriesSection(PoultryProvider p) => _section(
    'Expense Subcategories',
    Icons.category_outlined,
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Subcategories are global and independent from main categories and suppliers.', style: TextStyle(fontSize: 11, color: Color(0xFF75867D))),
      const SizedBox(height: 10),
      _listEditor('Subcategory List', _subcategories, 'Subcategory', Icons.category_outlined),
      const SizedBox(height: 10),
      Align(alignment: Alignment.centerRight, child: FilledButton.icon(
        onPressed: _busy ? null : () async {
          final items = _subcategories.map((c) => c.text.trim()).where((x) => x.isNotEmpty).toSet().toList();
          try { await p.saveExpenseSubcategories(items); _snack('Expense subcategories saved.'); }
          catch (e) { _snack('Unable to save subcategories: $e'); }
        },
        icon: const Icon(Icons.save_outlined), label: const Text('Save Subcategories'),
      )),
    ]),
  );

  Widget _suppliersSection(PoultryProvider p) => _section(
    'Suppliers',
    Icons.local_shipping_outlined,
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: TextField(controller: _supplierName, decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()))),
        const SizedBox(width: 8),
        Expanded(child: TextField(controller: _supplierContact, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Contact Number', border: OutlineInputBorder()))),
      ]),
      const SizedBox(height: 8),
      TextField(controller: _supplierAddress, maxLines: 2, decoration: const InputDecoration(labelText: 'Business Address', border: OutlineInputBorder())),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: FilledButton.icon(
          onPressed: () => _saveSupplier(p),
          icon: Icon(_editingSupplierId == null ? Icons.person_add_alt_1 : Icons.save_outlined),
          label: Text(_editingSupplierId == null ? 'Add Supplier' : 'Update Supplier'),
        )),
        if (_editingSupplierId != null) ...[
          const SizedBox(width: 8),
          OutlinedButton(onPressed: _clearSupplierForm, child: const Text('Cancel')),
        ],
      ]),
      const SizedBox(height: 14),
      if (p.suppliers.isEmpty)
        const Text('No suppliers added yet.', style: TextStyle(color: Color(0xFF75867D)))
      else
        ...p.suppliers.map((supplier) => Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.local_shipping_outlined)),
            title: Text(supplier.fullName),
            subtitle: Text([
              if (supplier.contactNumber.isNotEmpty) supplier.contactNumber,
              if (supplier.businessAddress.isNotEmpty) supplier.businessAddress,
            ].join(' • ')),
            trailing: Wrap(spacing: 0, children: [
              IconButton(tooltip: 'Edit supplier', icon: const Icon(Icons.edit_outlined), onPressed: () => _editSupplier(supplier)),
              IconButton(tooltip: 'Delete supplier', icon: const Icon(Icons.delete_outline), onPressed: () => _deleteSupplier(p, supplier)),
            ]),
          ),
        )),
    ]),
  );

  Future<void> _saveSupplier(PoultryProvider p) async {
    final name = _supplierName.text.trim();
    if (name.isEmpty) { _snack('Enter supplier full name.'); return; }
    final supplier = Supplier(
      id: _editingSupplierId ?? '',
      fullName: name,
      businessAddress: _supplierAddress.text.trim(),
      contactNumber: _supplierContact.text.trim(),
    );
    try {
      if (_editingSupplierId == null) {
        await p.addSupplier(supplier);
        _snack('Supplier added.');
      } else {
        await p.updateSupplier(supplier);
        _snack('Supplier updated.');
      }
      _clearSupplierForm();
    } catch (e) {
      _snack('Unable to save supplier: $e');
    }
  }

  void _editSupplier(Supplier supplier) {
    setState(() {
      _editingSupplierId = supplier.id;
      _supplierName.text = supplier.fullName;
      _supplierAddress.text = supplier.businessAddress;
      _supplierContact.text = supplier.contactNumber;
    });
  }

  void _clearSupplierForm() {
    if (!mounted) return;
    setState(() {
      _editingSupplierId = null;
      _supplierName.clear();
      _supplierAddress.clear();
      _supplierContact.clear();
    });
  }

  Future<void> _deleteSupplier(PoultryProvider p, Supplier supplier) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Supplier'),
        content: Text('Delete ${supplier.fullName}? Existing expense records will keep their saved supplier name.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try { await p.deleteSupplier(supplier.id); _snack('Supplier deleted.'); }
    catch (e) { _snack('Unable to delete supplier: $e'); }
  }

  Widget _membersSection(PoultryProvider p) => _section('Flock Members', Icons.group_outlined, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [Expanded(child: TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Registered email address', border: OutlineInputBorder()))), const SizedBox(width: 8), FilledButton.icon(onPressed: _invite, icon: const Icon(Icons.person_add_alt_1), label: const Text('Add / Invite'))]),
    const SizedBox(height: 12),
    FutureBuilder<List<FlockMembership>>(future: p.activeFlock == null ? Future.value([]) : p.fetchFlockMembers(p.activeFlock!.id), builder: (context, snap) {
      if (!snap.hasData) return const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator());
      return Column(children: snap.data!.map((m) => ListTile(
        leading: CircleAvatar(child: Icon(m.isAdmin ? Icons.admin_panel_settings : Icons.person)),
        title: Text(m.displayName.isEmpty ? m.email : m.displayName),
        subtitle: Text('${m.email} • ${m.mobileNumber.isEmpty ? 'No mobile' : m.mobileNumber}'),
        trailing: Wrap(spacing: 6, children: [
          DropdownButton<String>(value: m.notificationLanguage, items: const [DropdownMenuItem(value:'en',child:Text('English')),DropdownMenuItem(value:'hi',child:Text('हिंदी'))], onChanged: m.isAdmin ? null : (v) { if(v!=null) p.updateMemberDetails(m.flockId,mobileNumber:m.mobileNumber,notificationLanguage:v); }),
          if (!m.isAdmin) IconButton(tooltip:'Edit mobile', icon:const Icon(Icons.phone_outlined), onPressed:() => _editMember(p,m)),
        ]),
      )).toList());
    })
  ]));

  Future<void> _editMember(PoultryProvider p, FlockMembership m) async {
    final c=TextEditingController(text:m.mobileNumber);
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:Text('Member: ${m.displayName.isEmpty?m.email:m.displayName}'),content:TextField(controller:c,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'Mobile number',border:OutlineInputBorder())),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Save'))]));
    if(ok==true){try{await p.updateMemberDetails(m.flockId,mobileNumber:c.text);_snack('Member details updated.');setState((){});}catch(e){_snack('Unable to update member: $e');}}
    c.dispose();
  }

  Widget _notificationsSection(PoultryProvider p) => _section('Notifications', Icons.notifications_active_outlined, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Enable flock notifications'),value:_notificationsEnabled,onChanged:(v)=>setState(()=>_notificationsEnabled=v)),
    SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Daily report reminder'),value:_dailyReminderEnabled,onChanged:(v)=>setState(()=>_dailyReminderEnabled=v)),
    Wrap(spacing:10,runSpacing:10,children:[_timeTile('Reminder time',_reminderTime,(){_pickTime(true);}),_timeTile('Second reminder',_secondReminderTime,(){_pickTime(false);})]),
    SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Enable second reminder'),value:_secondReminderEnabled,onChanged:(v)=>setState(()=>_secondReminderEnabled=v)),
    const Divider(height:28),
    const Text('Daily Report Reminder — configurable localization',style:TextStyle(fontWeight:FontWeight.w800)),const SizedBox(height:8),
    TextField(controller:_notifTitleEn,decoration:const InputDecoration(labelText:'Title — English',border:OutlineInputBorder())),const SizedBox(height:8),
    TextField(controller:_notifTitleHi,decoration:const InputDecoration(labelText:'Title — Hindi',border:OutlineInputBorder())),const SizedBox(height:8),
    TextField(controller:_notifBodyEn,maxLines:2,decoration:const InputDecoration(labelText:'Message — English',helperText:'Variables: {memberName}, {flockName}, {breedName}, {date}',border:OutlineInputBorder())),const SizedBox(height:8),
    TextField(controller:_notifBodyHi,maxLines:2,decoration:const InputDecoration(labelText:'Message — Hindi',helperText:'Variables: {memberName}, {flockName}, {breedName}, {date}',border:OutlineInputBorder())),const SizedBox(height:10),
    Row(children:[Expanded(child:FilledButton.icon(onPressed:()=>_saveNotifications(p),icon:const Icon(Icons.save_outlined),label:const Text('Save Notification Settings'))),const SizedBox(width:8),OutlinedButton.icon(onPressed:()=>_sendAnnouncement(p),icon:const Icon(Icons.send_outlined),label:const Text('Send Test / Announcement'))])
  ]));

  Widget _timeTile(String label, TimeOfDay time, VoidCallback onTap)=>SizedBox(width:220,child:ListTile(shape:RoundedRectangleBorder(side:const BorderSide(color:Color(0xFFDCE7E0)),borderRadius:BorderRadius.circular(8)),title:Text(label),subtitle:Text(time.format(context)),trailing:const Icon(Icons.schedule),onTap:onTap));
  Future<void> _pickTime(bool first) async { final t=await showTimePicker(context:context,initialTime:first?_reminderTime:_secondReminderTime); if(t!=null)setState(()=>first?_reminderTime=t:_secondReminderTime=t); }
  Future<void> _saveNotifications(PoultryProvider p) async { try { await p.saveNotificationSettings({'enabled':_notificationsEnabled,'dailyReportReminder':_dailyReminderEnabled,'secondReminderEnabled':_secondReminderEnabled,'reminderHour':_reminderTime.hour,'reminderMinute':_reminderTime.minute,'secondReminderHour':_secondReminderTime.hour,'secondReminderMinute':_secondReminderTime.minute,'timezone':'Asia/Kolkata'}); await p.saveNotificationTemplate('daily_report_reminder',{'titleEn':_notifTitleEn.text.trim(),'titleHi':_notifTitleHi.text.trim(),'bodyEn':_notifBodyEn.text.trim(),'bodyHi':_notifBodyHi.text.trim(),'enabled':_dailyReminderEnabled,'reminderHour':_reminderTime.hour,'reminderMinute':_reminderTime.minute,'secondReminderHour':_secondReminderTime.hour,'secondReminderMinute':_secondReminderTime.minute,'secondReminderEnabled':_secondReminderEnabled}); _snack('Notification settings saved.'); } catch(e){_snack('Unable to save notifications: $e');} }
  Future<void> _sendAnnouncement(PoultryProvider p) async { try { await p.sendFlockNotification(titleEn:_notifTitleEn.text.trim(),titleHi:_notifTitleHi.text.trim(),bodyEn:_notifBodyEn.text.trim(),bodyHi:_notifBodyHi.text.trim()); _snack('Notification queued for flock members.'); } catch(e){_snack('Unable to send notification: $e');} }
  Widget _section(String title, IconData icon, Widget child) => AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon, color: const Color(0xFF087A4F)), const SizedBox(width: 8), Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))]), const SizedBox(height: 12), child]));
}
