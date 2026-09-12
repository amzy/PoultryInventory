import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/flock.dart';
import '../models/supplier.dart';
import '../providers/poultry_provider.dart';
import '../services/farm_config.dart';
import '../services/expense_category_config.dart';
import '../services/firebase_service.dart';
import '../widgets/app_shell.dart';

class AdminPanelScreen extends StatefulWidget {
  final bool embedded;
  final bool adminOnly;
  final bool showSuppliers;
  final bool showMembers;
  const AdminPanelScreen({
    super.key,
    this.embedded = false,
    this.adminOnly = false,
    this.showSuppliers = true,
    this.showMembers = true,
  });
  @override State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final _name = TextEditingController();
  final _birds = TextEditingController();
  final _breed = TextEditingController();
  final _email = TextEditingController();
  final List<TextEditingController> _accounts = [];
  final List<TextEditingController> _feeds = [];
  final _supplierName = TextEditingController();
  final _supplierAddress = TextEditingController();
  final _supplierContact = TextEditingController();
  final List<TextEditingController> _supplierContacts = [];
  String _supplierCategory = '';
  String? _editingSupplierId;
  DateTime _start = DateTime.now();
  DateTime? _end;
  bool _busy = false;
  String? _memberFlockId;

  @override void initState() { super.initState(); WidgetsBinding.instance.addPostFrameCallback((_) => _load()); }
  Future<void> _load() async {
    final p = context.read<PoultryProvider>();
    final f = p.activeFlock;
    final runningFlocks = p.flocks.where((flock) => flock.isActive).toList();
    _memberFlockId ??= runningFlocks.isNotEmpty ? runningFlocks.first.id : null;
    if (f == null) return;
    _name.text = f.name; _birds.text = f.startingBirds.toString(); _breed.text = f.breedName; _start = f.startDate; _end = f.endDate;
    for (final c in _accounts) c.dispose(); for (final c in _feeds) c.dispose(); _accounts.clear(); _feeds.clear();
    for (final x in f.accounts) _accounts.add(TextEditingController(text: x));
    final globalFeeds = p.feedItems;
    for (final x in globalFeeds) _feeds.add(TextEditingController(text: x));
    if (_accounts.isEmpty) for (final x in FarmConfig.defaultAccounts) _accounts.add(TextEditingController(text: x));
    if (_feeds.isEmpty) for (final x in FarmConfig.defaultFeedItems) _feeds.add(TextEditingController(text: x));
    try {
      // Reconcile invitations/memberships for every running flock. A member
      // may already have a user-side flock_memberships record even when the
      // corresponding flock/members document is missing, so repair the
      // selected flock's membership mapping as part of the admin load.
      for (final runningFlock in runningFlocks) {
        try { await p.syncInvitedMembers(runningFlock.id); } catch (_) {}
      }
    } catch (_) {}
    setState(() {});
  }
  @override void dispose() { _name.dispose(); _birds.dispose(); _breed.dispose(); _email.dispose(); _supplierName.dispose(); _supplierAddress.dispose(); _supplierContact.dispose(); for (final c in _supplierContacts) c.dispose(); for (final c in _accounts) c.dispose(); for (final c in _feeds) c.dispose(); super.dispose(); }

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

  Future<void> _invite() async {
    final email = _email.text.trim();
    final flockId = _memberFlockId;
    if (flockId == null || flockId.isEmpty) { _snack('Select a running flock first.'); return; }
    if (email.isEmpty) { _snack('Enter the registered email address.'); return; }
    try {
      final provider = context.read<PoultryProvider>();
      await provider.inviteFlockMember(email, flockId: flockId);
      // If the invited account already exists, provision/repair its membership
      // immediately instead of waiting for the member to sign in again.
      try { await provider.syncInvitedMembers(flockId); } catch (_) {}
      _email.clear();
      _snack('Invitation saved for the selected flock.');
    } catch (e) { _snack('Unable to add user: $e'); }
  }
  void _snack(String text) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text))); }

  @override Widget build(BuildContext context) {
    return Consumer<PoultryProvider>(builder: (context, p, _) {
      if (!p.isAdmin) return const Center(child: Text('Admin access required.'));
      final adminSections = <Widget>[
        if (widget.showSuppliers) _suppliersSection(p),
        if (widget.showSuppliers && widget.showMembers) const SizedBox(height: 12),
        if (widget.showMembers) _membersSection(p),
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
      return PoultryAppShell(selectedIndex: 10, title: 'Settings', subtitle: 'Administration', child: content);
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
  Widget _suppliersSection(PoultryProvider p) => _section(
    'Suppliers',
    Icons.local_shipping_outlined,
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(controller: _supplierName, decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder())),
      const SizedBox(height: 8),
      const Text('Mobile Numbers', style: TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      ..._supplierContacts.asMap().entries.map((entry) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: entry.value,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: entry.key == 0 ? 'Primary mobile' : 'Mobile ${entry.key + 1}',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            if (_supplierContacts.length > 1)
              IconButton(
                tooltip: 'Remove mobile number',
                onPressed: () => setState(() {
                  final c = _supplierContacts.removeAt(entry.key);
                  c.dispose();
                }),
                icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
              ),
          ],
        ),
      )),
      OutlinedButton.icon(
        onPressed: () => setState(() => _supplierContacts.add(TextEditingController())),
        icon: const Icon(Icons.add),
        label: const Text('Add another mobile'),
      ),
      const SizedBox(height: 8),
      TextField(controller: _supplierAddress, maxLines: 2, decoration: const InputDecoration(labelText: 'Business Address', border: OutlineInputBorder())),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(value: _supplierCategory.isEmpty ? null : _supplierCategory, decoration: const InputDecoration(labelText: 'Category (Optional)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.category_outlined)), items: [const DropdownMenuItem<String>(value: '', child: Text('No category')), ...ExpenseCategoryConfig.activeSubcategories.map((x) => DropdownMenuItem(value: x, child: Text(x)))], onChanged: (v) => setState(() => _supplierCategory = v ?? '')),
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
        ...p.suppliers.take(5).map((supplier) => Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: const Color(0xFFE6F5ED), child: Text(supplier.fullName.trim().isEmpty ? 'S' : supplier.fullName.trim()[0].toUpperCase(), style: const TextStyle(color: Color(0xFF087A4F), fontWeight: FontWeight.w900))),
            title: Text(supplier.fullName, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text([
              if (supplier.contactNumber.isNotEmpty) supplier.contactNumber,
              if (supplier.businessAddress.isNotEmpty) supplier.businessAddress,
              if (supplier.category.isNotEmpty) supplier.category,
            ].join(' • '), maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: IconButton(tooltip: 'Edit supplier', icon: const Icon(Icons.edit_outlined), onPressed: () => _editSupplier(supplier)),
          ),
        )),
        if (p.suppliers.length > 5) Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: () => _showAllSuppliers(p), icon: const Icon(Icons.list_alt_outlined), label: Text('List All (${p.suppliers.length})'))),
    ]),
  );

  Future<void> _saveSupplier(PoultryProvider p) async {
    final name = _supplierName.text.trim();
    if (name.isEmpty) { _snack('Enter supplier full name.'); return; }
    final phones = _supplierContacts
        .map((c) => c.text.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
    if (phones.isEmpty) { _snack('Add at least one mobile number.'); return; }
    final supplier = Supplier(
      id: _editingSupplierId ?? '',
      fullName: name,
      businessAddress: _supplierAddress.text.trim(),
      contactNumber: phones.first,
      contactNumbers: phones,
      category: _supplierCategory,
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
      for (final c in _supplierContacts) c.dispose();
      _supplierContacts
        ..clear()
        ..addAll(supplier.phoneNumbers.map((value) => TextEditingController(text: value)));
      if (_supplierContacts.isEmpty) _supplierContacts.add(TextEditingController());
      _supplierContact.text = supplier.contactNumber;
      _supplierCategory = supplier.category;
    });
  }

  void _clearSupplierForm() {
    if (!mounted) return;
    setState(() {
      _editingSupplierId = null;
      _supplierName.clear();
      _supplierAddress.clear();
      _supplierContact.clear();
      for (final c in _supplierContacts) c.dispose();
      _supplierContacts
        ..clear()
        ..add(TextEditingController());
      _supplierCategory = '';
    });
  }

  Widget _membersSection(PoultryProvider p) {
    final runningFlocks = p.flocks.where((f) => f.isActive).toList();
    final selectedId = runningFlocks.any((f) => f.id == _memberFlockId)
        ? _memberFlockId
        : (runningFlocks.isNotEmpty ? runningFlocks.first.id : null);
    final selectedFlock = selectedId == null
        ? null
        : runningFlocks.firstWhere((f) => f.id == selectedId);

    if (_memberFlockId != selectedId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _memberFlockId = selectedId);
      });
    }

    return _section('Flock Members & Invitations', Icons.group_outlined, Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (runningFlocks.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('No running flocks are available. Add a running flock before adding or requesting members.'),
          )
        else ...[
          DropdownButtonFormField<String>(
            value: selectedId,
            decoration: const InputDecoration(
              labelText: 'Select running flock',
              prefixIcon: Icon(Icons.pets_outlined),
              border: OutlineInputBorder(),
            ),
            items: runningFlocks.map((f) => DropdownMenuItem<String>(
              value: f.id,
              child: Text(f.name),
            )).toList(),
            onChanged: (value) {
              if (value != null) setState(() => _memberFlockId = value);
            },
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Registered email address',
                border: OutlineInputBorder(),
              ),
            )),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _invite,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Add / Invite'),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
            'Members shown below belong to ${selectedFlock?.name ?? 'the selected flock'}. The picker does not change the app\'s current flock.',
            style: const TextStyle(fontSize: 10.5, color: Color(0xFF667970)),
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<FlockMembership>>(
            stream: selectedId == null ? const Stream<List<FlockMembership>>.empty() : p.watchFlockMembers(selectedId),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
                return const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator());
              }
              if (snap.hasError) return Text('Unable to load members: ${snap.error}');
              final members = snap.data ?? const <FlockMembership>[];
              Widget card(FlockMembership m) {
                final isOwner = m.uid.isNotEmpty && m.uid == selectedFlock?.createdByUid;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFFE1EAE5))),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: const Color(0xFFE8F2EE),
                        child: Text(
                          (m.displayName.isEmpty ? m.email : m.displayName).trim().isEmpty ? 'U' : (m.displayName.isEmpty ? m.email : m.displayName).trim()[0].toUpperCase(),
                          style: const TextStyle(color: Color(0xFF087A4F), fontWeight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(m.displayName.isEmpty ? m.email : m.displayName, style: const TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 3),
                        Text(m.email, style: const TextStyle(fontSize: 11, color: Color(0xFF667970))),
                        const SizedBox(height: 3),
                        Text(m.mobileNumber.isEmpty ? 'No mobile number' : m.mobileNumber, style: const TextStyle(fontSize: 11, color: Color(0xFF667970))),
                        const SizedBox(height: 9),
                        Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                          _memberStatusChip(m.status, reported: m.invitationReported),
                          if (m.status == 'declined' && !m.invitationReported)
                            OutlinedButton.icon(
                              onPressed: () async {
                                try { await p.resendFlockInvitation(m.email, flockId: m.flockId); _snack('Invitation resent.'); }
                                catch (e) { _snack('Unable to resend invitation: $e'); }
                              },
                              icon: const Icon(Icons.send_outlined, size: 16),
                              label: const Text('Resend'),
                            ),
                          if (m.status == 'active' || m.status == 'suspended') DropdownButton<String>(
                            value: m.role,
                            items: const [DropdownMenuItem(value: 'admin', child: Text('Admin')), DropdownMenuItem(value: 'member', child: Text('Member'))],
                            onChanged: m.uid.isEmpty || isOwner ? null : (v) async {
                              if (v != null) {
                                try { await p.updateMemberRole(m.uid, v, flockId: m.flockId); _snack('Member role updated.'); }
                                catch (e) { _snack('Unable to update role: $e'); }
                              }
                            },
                          ),
                          if (m.uid.isNotEmpty && (m.status == 'active' || m.status == 'suspended') && !isOwner)
                            OutlinedButton.icon(
                              onPressed: () async {
                                try { await p.setFlockMemberStatus(m.uid, m.status == 'suspended' ? 'active' : 'suspended', flockId: m.flockId); _snack(m.status == 'suspended' ? 'Member resumed.' : 'Member suspended.'); }
                                catch (e) { _snack('Unable to change member status: $e'); }
                              },
                              icon: Icon(m.status == 'suspended' ? Icons.play_arrow_outlined : Icons.pause_circle_outline, size: 16),
                              label: Text(m.status == 'suspended' ? 'Resume' : 'Suspend'),
                            ),
                          if (m.uid.isNotEmpty && (m.status == 'active' || m.status == 'suspended')) OutlinedButton.icon(onPressed: () => _editMember(p, m), icon: const Icon(Icons.edit_outlined, size: 16), label: const Text('Edit')),
                          if (!isOwner && (m.status == 'active' || m.status == 'pending' || m.status == 'declined')) OutlinedButton.icon(onPressed: () => _editMemberAccess(p, m), icon: const Icon(Icons.tune_outlined, size: 16), label: const Text('Access')),
                          if (m.uid.isNotEmpty && !isOwner)
                            IconButton(tooltip: 'Remove member', icon: const Icon(Icons.delete_outline, color: Color(0xFFD32F2F)), onPressed: () => _confirmRemoveMember(p, m)),
                        ])
                      ])),
                    ]),
                  ),
                );
              }
              return Column(children: [
                ...members.take(5).map(card),
                if (members.length > 5)
                  Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: () => _showAllMembers(p, members), icon: const Icon(Icons.list_alt_outlined), label: Text('List All (${members.length})'))),
              ]);
            },
          ),
        ],
      ],
    ));
  }

  Widget _memberStatusChip(String status, {bool reported = false}) {
    final label = status == 'suspended' ? 'Suspended' : status == 'pending' ? 'Pending' : status == 'declined' ? (reported ? 'Declined • Reported' : 'Declined') : 'Active';
    final icon = status == 'suspended' ? Icons.pause_circle_outline : status == 'pending' ? Icons.schedule : status == 'declined' ? Icons.cancel_outlined : Icons.check_circle_outline;
    return Chip(avatar: Icon(icon, size: 15), label: Text(label), visualDensity: VisualDensity.compact);
  }

  Future<void> _showAllMembers(PoultryProvider p, List<FlockMembership> members) async {
    await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('All Members'),
      content: SizedBox(width: 620, height: 520, child: ListView.separated(
        itemCount: members.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final m = members[i];
          final flockMatches = p.flocks.where((f) => f.id == m.flockId).toList();
          final flock = flockMatches.isEmpty ? null : flockMatches.first;
          final isOwner = m.uid.isNotEmpty && m.uid == flock?.createdByUid;
          return ListTile(
            leading: CircleAvatar(backgroundColor: const Color(0xFFE8F2EE), child: Text((m.displayName.isEmpty ? m.email : m.displayName).isEmpty ? 'U' : (m.displayName.isEmpty ? m.email : m.displayName)[0].toUpperCase(), style: const TextStyle(color: Color(0xFF087A4F)))),
            title: Text(m.displayName.isEmpty ? m.email : m.displayName),
            subtitle: Text('${m.email} • ${m.role}'),
            trailing: Wrap(spacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              _memberStatusChip(m.status, reported: m.invitationReported),
              if (m.status == 'declined' && !m.invitationReported)
                IconButton(tooltip: 'Resend invitation', icon: const Icon(Icons.send_outlined), onPressed: () async {
                  try { await p.resendFlockInvitation(m.email, flockId: m.flockId); Navigator.pop(ctx); _snack('Invitation resent.'); }
                  catch (e) { _snack('Unable to resend invitation: $e'); }
                }),
              if (m.uid.isNotEmpty && (m.status == 'active' || m.status == 'suspended') && !isOwner)
                IconButton(tooltip: m.status == 'suspended' ? 'Resume member' : 'Suspend member', icon: Icon(m.status == 'suspended' ? Icons.play_arrow_outlined : Icons.pause_circle_outline), onPressed: () async {
                  try { await p.setFlockMemberStatus(m.uid, m.status == 'suspended' ? 'active' : 'suspended', flockId: m.flockId); Navigator.pop(ctx); _showAllMembers(p, members); }
                  catch (e) { _snack('Unable to change member status: $e'); }
                }),
              if (!isOwner && (m.status == 'active' || m.status == 'pending' || m.status == 'declined'))
                IconButton(tooltip: 'Feature access', icon: const Icon(Icons.tune_outlined), onPressed: () { Navigator.pop(ctx); _editMemberAccess(p, m); }),
              if (m.uid.isNotEmpty && !isOwner) IconButton(tooltip: 'Remove member', icon: const Icon(Icons.delete_outline, color: Color(0xFFD32F2F)), onPressed: () { Navigator.pop(ctx); _confirmRemoveMember(p, m); }),
            ]),
          );
        },
      )),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
    ));
  }

  Future<void> _confirmRemoveMember(PoultryProvider p, FlockMembership m) async {
    if (m.uid.isEmpty) return;
    final name = m.displayName.isEmpty ? m.email : m.displayName;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove member?'),
        content: Text('Remove $name from this flock? Existing daily logs, transactions, and other records created by this user will not be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await p.removeFlockMember(m.uid, flockId: m.flockId);
      if (mounted) _snack('Member removed from the flock. Existing records were kept.');
    } catch (e) {
      if (mounted) _snack('Unable to remove member: $e');
    }
  }

  Future<void> _editMemberAccess(PoultryProvider p, FlockMembership m) async {
    final defaults = Map<String, bool>.from(FirebaseService.defaultMemberFeatureAccess);
    defaults.addAll(m.featureAccess);
    final labels = <String, String>{
      'reports': 'Reports', 'expenses': 'Expenses / Transactions', 'medical': 'Medical',
      'feed': 'Feed', 'grit': 'Grit', 'tray': 'Tray', 'otherExpenses': 'Other Expenses',
      'eggSales': 'Egg Sales', 'suppliers': 'Suppliers',
    };
    final values = Map<String, bool>.from(defaults);
    final saved = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) => AlertDialog(
      title: Text('Feature access: ${m.displayName.isEmpty ? m.email : m.displayName}'),
      content: SizedBox(width: 430, child: ListView(shrinkWrap: true, children: [
        const ListTile(leading: Icon(Icons.info_outline), title: Text('Dashboard and Daily Log are always available to members.'), subtitle: Text('Enable additional features below as needed.')),
        ...labels.entries.map((entry) => CheckboxListTile(value: values[entry.key] == true, title: Text(entry.value), onChanged: (v) => setDialogState(() => values[entry.key] = v == true))),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save access'))],
    )));
    if (saved != true || !mounted) return;
    try {
      if (m.uid.isNotEmpty) {
        await p.updateMemberFeatureAccess(m.uid, values, flockId: m.flockId);
      } else {
        await p.updateInvitationFeatureAccess(m.email, values, flockId: m.flockId);
      }
      if (mounted) _snack('Member feature access updated.');
    } catch (e) {
      if (mounted) _snack('Unable to update feature access: $e');
    }
  }

  Future<void> _editMember(PoultryProvider p, FlockMembership m) async {
    final c=TextEditingController(text:m.mobileNumber);
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:Text('Member: ${m.displayName.isEmpty?m.email:m.displayName}'),content:TextField(controller:c,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'Mobile number',border:OutlineInputBorder())),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Save'))]));
    if(ok==true){try{await p.updateMemberDetails(m.uid, flockId: m.flockId, mobileNumber:c.text);_snack('Member details updated.');setState((){});}catch(e){_snack('Unable to update member: $e');}}
    c.dispose();
  }


  Future<void> _showAllSuppliers(PoultryProvider p) async {
    await showDialog<void>(context: context, builder: (ctx) => AlertDialog(title: const Text('All Suppliers'), content: SizedBox(width: 560, height: 480, child: ListView.separated(itemCount: p.suppliers.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (_, i) { final s=p.suppliers[i]; return ListTile(leading: CircleAvatar(backgroundColor: const Color(0xFFE6F5ED), child: Text(s.fullName.isEmpty?'S':s.fullName[0].toUpperCase(),style:const TextStyle(color:Color(0xFF087A4F)))), title: Text(s.fullName), subtitle: Text([s.contactNumber,s.businessAddress].where((x)=>x.isNotEmpty).join(' • '), maxLines:2, overflow:TextOverflow.ellipsis), trailing: IconButton(icon:const Icon(Icons.edit_outlined),onPressed:(){Navigator.pop(ctx);_editSupplier(s);}),); })), actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Close'))]));
  }

  Widget _section(String title, IconData icon, Widget child) => AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon, color: const Color(0xFF087A4F)), const SizedBox(width: 8), Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))]), const SizedBox(height: 12), child]));
}
