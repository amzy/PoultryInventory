import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/repositories/firebase_supplier_repository.dart';
import '../models/supplier.dart';
import '../presentation/viewmodels/supplier_view_model.dart';
import '../providers/poultry_provider.dart';
import '../services/expense_category_config.dart';
import '../services/device_contact_picker.dart';
import '../services/firebase_service.dart';
import '../widgets/app_shell.dart';

/// Supplier feature entry point.
///
/// The screen is intentionally thin: UI events are forwarded to
/// [SupplierViewModel]. Firebase and business logic live outside this file.
class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  late final SupplierViewModel _viewModel;
  PoultryProvider? _poultryProvider;

  @override
  void initState() {
    super.initState();
    _poultryProvider = context.read<PoultryProvider>();
    _poultryProvider!.addListener(_handleProviderSupplierChange);
    _viewModel = SupplierViewModel(
      repository: FirebaseSupplierRepository(FirebaseService()),
      onSuppliersChanged: () => _poultryProvider!.reloadSuppliers(),
    )..load();
  }

  void _handleProviderSupplierChange() {
    if (!mounted) return;
    final shared = _poultryProvider?.suppliers ?? const <Supplier>[];
    final current = _viewModel.suppliers;
    if (_sameSupplierLists(current, shared)) return;
    // Settings/AdminPanel uses PoultryProvider as its source of truth.
    // Reload this feature VM only when the supplier data actually changes.
    _viewModel.load(force: true);
  }

  bool _sameSupplierLists(List<Supplier> a, List<Supplier> b) {
    if (a.length != b.length) return false;
    final left = [...a]..sort((x, y) => x.id.compareTo(y.id));
    final right = [...b]..sort((x, y) => x.id.compareTo(y.id));
    for (var i = 0; i < left.length; i++) {
      final x = left[i];
      final y = right[i];
      if (x.id != y.id ||
          x.fullName != y.fullName ||
          x.businessAddress != y.businessAddress ||
          x.category != y.category ||
          x.contactNumber != y.contactNumber ||
          x.phoneNumbers.join('|') != y.phoneNumbers.join('|')) {
        return false;
      }
    }
    return true;
  }

  @override
  void dispose() {
    _poultryProvider?.removeListener(_handleProviderSupplierChange);
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<SupplierViewModel>(
        builder: (context, vm, _) {
          final isAdmin = context.select<PoultryProvider, bool>((p) => p.isAdmin);
          return _SupplierContent(viewModel: vm, isAdmin: isAdmin);
        },
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF3C5BE)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFB42318)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _SupplierContent extends StatelessWidget {
  const _SupplierContent({required this.viewModel, required this.isAdmin});

  final SupplierViewModel viewModel;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    if (viewModel.isLoading && viewModel.suppliers.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
      children: [
        _SearchAndActions(viewModel: viewModel, isAdmin: isAdmin),
        const SizedBox(height: 12),
        _ExportPanel(viewModel: viewModel),
        if (viewModel.error != null) ...[
          const SizedBox(height: 8),
          _ErrorBanner(message: viewModel.error!, onRetry: () => viewModel.load(force: true)),
        ],
        const SizedBox(height: 10),
        if (viewModel.filteredSuppliers.isEmpty)
          const AppCard(
            child: Padding(
              padding: EdgeInsets.all(22),
              child: Center(
                child: Text(
                  'No suppliers found.',
                  style: TextStyle(color: Color(0xFF75867D)),
                ),
              ),
            ),
          )
        else
          ...viewModel.filteredSuppliers.map(
            (supplier) => _SupplierCard(
              supplier: supplier,
              viewModel: viewModel,
              isAdmin: isAdmin,
            ),
          ),
      ],
    );
  }
}

class _SearchAndActions extends StatelessWidget {
  const _SearchAndActions({required this.viewModel, required this.isAdmin});

  final SupplierViewModel viewModel;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            onChanged: viewModel.setQuery,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search suppliers',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          onPressed: viewModel.isExporting
              ? null
              : () {
                  if (viewModel.selectionMode) {
                    viewModel.exitSelectionMode();
                  } else {
                    viewModel.enterSelectionMode();
                  }
                },
          icon: Icon(viewModel.selectionMode ? Icons.close : Icons.checklist_outlined),
          label: Text(viewModel.selectionMode ? 'Done' : 'Select'),
        ),
        if (isAdmin) ...[
          IconButton.filledTonal(
            tooltip: 'Add from phone contacts',
            onPressed: viewModel.isSaving ? null : () => _importDeviceContacts(context, viewModel),
            icon: const Icon(Icons.contacts_outlined),
          ),
          FilledButton.icon(
            onPressed: viewModel.isSaving ? null : () => _showSupplierEditor(context, viewModel),
            icon: const Icon(Icons.add),
            label: const Text('Add Supplier'),
          ),
        ],
      ],
    );
  }
}

class _ExportPanel extends StatelessWidget {
  const _ExportPanel({required this.viewModel});

  final SupplierViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final visible = viewModel.filteredSuppliers;
    final selected = viewModel.selectedSuppliers;
    final exportItems = selected.isEmpty ? visible : selected;

    return AppCard(
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          Text(
            viewModel.selectionMode
                ? (selected.isEmpty ? 'Select supplier contacts' : '${selected.length} selected')
                : 'Export supplier contacts',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (viewModel.selectionMode)
            TextButton.icon(
              onPressed: visible.isEmpty ? null : viewModel.selectAllVisible,
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('Select all'),
            ),
          SizedBox(
            width: 210,
            child: DropdownButtonFormField<String?>(
              value: viewModel.category,
              decoration: const InputDecoration(
                labelText: 'Category',
                isDense: true,
                prefixIcon: Icon(Icons.filter_alt_outlined),
              ),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('All categories')),
                ...viewModel.categories.map(
                  (category) => DropdownMenuItem<String?>(value: category, child: Text(category)),
                ),
              ],
              onChanged: viewModel.setCategory,
            ),
          ),
          OutlinedButton.icon(
            onPressed: viewModel.isExporting || exportItems.isEmpty
                ? null
                : () => _runExport(context, viewModel, exportItems),
            icon: const Icon(Icons.download_outlined),
            label: Text(selected.isEmpty ? 'Save VCF' : 'Save Selected'),
          ),
          OutlinedButton.icon(
            onPressed: viewModel.isExporting || exportItems.isEmpty
                ? null
                : () => _runWhatsApp(context, viewModel, exportItems),
            icon: const Icon(Icons.send_outlined),
            label: const Text('Send via WhatsApp'),
          ),
          if (selected.isNotEmpty)
            TextButton(
              onPressed: viewModel.isExporting ? null : viewModel.clearSelection,
              child: const Text('Clear selection'),
            ),
          if (viewModel.isExporting)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  Future<void> _runExport(BuildContext context, SupplierViewModel vm, List<Supplier> suppliers) async {
    try {
      await vm.exportToFile(suppliers);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${suppliers.length} contact(s) saved as VCF.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(vm.error ?? 'Unable to save contacts.')),
        );
      }
    }
  }

  Future<void> _runWhatsApp(BuildContext context, SupplierViewModel vm, List<Supplier> suppliers) async {
    try {
      await vm.sendToWhatsApp(suppliers);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(vm.error ?? 'Unable to open WhatsApp.')),
        );
      }
    }
  }
}

class _SupplierCard extends StatelessWidget {
  const _SupplierCard({required this.supplier, required this.viewModel, required this.isAdmin});

  final Supplier supplier;
  final SupplierViewModel viewModel;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final selected = viewModel.selectedIds.contains(supplier.id);
    final phones = supplier.phoneNumbers;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? const Color(0xFF087A4F) : const Color(0xFFE1EAE5),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (viewModel.selectionMode)
              Checkbox(
                value: selected,
                onChanged: (_) => viewModel.toggleSelection(supplier.id),
              ),
            CircleAvatar(
              radius: 25,
              backgroundColor: const Color(0xFFE6F5ED),
              child: Text(
                _initials(supplier.fullName),
                style: const TextStyle(
                  color: Color(0xFF087A4F),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        title: Text(supplier.fullName, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (phones.isNotEmpty) ...[
                for (final phone in phones)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(child: Text(phone)),
                      IconButton(
                        tooltip: 'Call',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _contact(phone, ContactAction.call),
                        icon: const Icon(Icons.call_outlined, size: 18),
                      ),
                      IconButton(
                        tooltip: 'SMS',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _contact(phone, ContactAction.sms),
                        icon: const Icon(Icons.sms_outlined, size: 18),
                      ),
                      IconButton(
                        tooltip: 'WhatsApp',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _contact(phone, ContactAction.whatsapp),
                        icon: const Icon(Icons.chat_outlined, size: 18),
                      ),
                    ],
                  ),
              ],
              if (supplier.businessAddress.isNotEmpty)
                Text(
                  supplier.businessAddress,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              if (supplier.category.isNotEmpty)
                Text(
                  supplier.category,
                  style: const TextStyle(
                    color: Color(0xFF087A4F),
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        trailing: isAdmin
            ? IconButton(
                tooltip: 'Edit supplier',
                onPressed: viewModel.isSaving
                    ? null
                    : () => _showSupplierEditor(context, viewModel, supplier),
                icon: const Icon(Icons.edit_outlined),
              )
            : null,
      ),
    );
  }

  Future<void> _contact(String phone, ContactAction action) async {
    final normalized = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = switch (action) {
      ContactAction.call => Uri(scheme: 'tel', path: normalized),
      ContactAction.sms => Uri(scheme: 'sms', path: normalized),
      ContactAction.whatsapp => Uri.https('wa.me', '/$normalized'),
    };
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toList();
    if (parts.isEmpty) return 'S';
    return (parts.first[0] + (parts.length > 1 ? parts.last[0] : '')).toUpperCase();
  }
}

enum ContactAction { call, sms, whatsapp }

Future<void> _importDeviceContacts(
  BuildContext context,
  SupplierViewModel viewModel,
) async {
  try {
    final contacts = await getDevicePhoneContacts();
    if (!context.mounted) return;
    if (contacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No contacts with phone numbers were found.')),
      );
      return;
    }

    final selected = await showDialog<List<PickedPhoneContact>>(
      context: context,
      builder: (dialogContext) => _DeviceContactSelectionDialog(contacts: contacts),
    );
    if (selected == null || selected.isEmpty || !context.mounted) return;

    final existingPhones = viewModel.suppliers
        .expand((supplier) => supplier.phoneNumbers)
        .map(_normalizePhone)
        .where((value) => value.isNotEmpty)
        .toSet();

    final suppliers = <Supplier>[];
    var skipped = 0;
    for (final contact in selected) {
      final phones = contact.phoneNumbers
          .map((number) => number.trim())
          .where((number) => number.isNotEmpty)
          .where((number) => !existingPhones.contains(_normalizePhone(number)))
          .toList(growable: false);
      if (phones.isEmpty) {
        skipped++;
        continue;
      }
      final name = contact.name.trim().isEmpty ? 'Unnamed Contact' : contact.name.trim();
      suppliers.add(
        Supplier(
          id: '',
          fullName: name,
          contactNumber: phones.first,
          contactNumbers: phones,
        ),
      );
      for (final phone in phones) {
        existingPhones.add(_normalizePhone(phone));
      }
    }

    if (suppliers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All selected contacts are already in the supplier list.')),
      );
      return;
    }

    await viewModel.addMany(suppliers);
    if (!context.mounted) return;
    final message = skipped == 0
        ? '${suppliers.length} supplier contact${suppliers.length == 1 ? '' : 's'} added.'
        : '${suppliers.length} added, $skipped already in the supplier list.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to import phone contacts: $e')),
      );
    }
  }
}

String _normalizePhone(String value) => value.replaceAll(RegExp(r'[^0-9+]'), '');

class _DeviceContactSelectionDialog extends StatefulWidget {
  const _DeviceContactSelectionDialog({required this.contacts});

  final List<PickedPhoneContact> contacts;

  @override
  State<_DeviceContactSelectionDialog> createState() => _DeviceContactSelectionDialogState();
}

class _DeviceContactSelectionDialogState extends State<_DeviceContactSelectionDialog> {
  final Set<int> _selected = <int>{};
  String _query = '';

  List<int> get _visibleIndexes => List<int>.generate(widget.contacts.length, (index) => index)
      .where((index) {
        final contact = widget.contacts[index];
        final query = _query.trim().toLowerCase();
        if (query.isEmpty) return true;
        return contact.name.toLowerCase().contains(query) ||
            contact.phoneNumbers.any((phone) => phone.toLowerCase().contains(query));
      })
      .toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final visible = _visibleIndexes;
    return AlertDialog(
      title: const Text('Add Phone Contacts'),
      content: SizedBox(
        width: 520,
        height: 560,
        child: Column(
          children: [
            TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search device contacts',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('${_selected.length} selected', style: const TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                TextButton(
                  onPressed: visible.isEmpty
                      ? null
                      : () => setState(() => _selected.addAll(visible)),
                  child: const Text('Select visible'),
                ),
                TextButton(
                  onPressed: _selected.isEmpty ? null : () => setState(_selected.clear),
                  child: const Text('Clear'),
                ),
              ],
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: visible.length,
                itemBuilder: (context, row) {
                  final index = visible[row];
                  final contact = widget.contacts[index];
                  return CheckboxListTile(
                    value: _selected.contains(index),
                    onChanged: (value) => setState(() {
                      if (value == true) {
                        _selected.add(index);
                      } else {
                        _selected.remove(index);
                      }
                    }),
                    title: Text(
                      contact.name.isEmpty ? 'Unnamed Contact' : contact.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(contact.phoneNumbers.join(' • ')),
                    secondary: const CircleAvatar(child: Icon(Icons.person_outline)),
                    controlAffinity: ListTileControlAffinity.leading,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.pop(
                    context,
                    _selected.map((index) => widget.contacts[index]).toList(growable: false),
                  ),
          child: Text('Add ${_selected.length}'),
        ),
      ],
    );
  }
}

Future<void> _showSupplierEditor(
  BuildContext context,
  SupplierViewModel viewModel, [
  Supplier? existing,
]) async {
  final name = TextEditingController(text: existing?.fullName ?? '');
  final address = TextEditingController(text: existing?.businessAddress ?? '');
  final phoneControllers = <TextEditingController>[
    ...((existing?.phoneNumbers ?? const <String>[])
        .map((value) => TextEditingController(text: value))),
  ];
  if (phoneControllers.isEmpty) phoneControllers.add(TextEditingController());
  var category = existing?.category ?? '';

  try {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            title: Text(existing == null ? 'Add Supplier' : 'Edit Supplier'),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Phone Numbers',
                        style: Theme.of(ctx)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...List.generate(phoneControllers.length, (index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: phoneControllers[index],
                                keyboardType: TextInputType.phone,
                                decoration: InputDecoration(
                                  labelText: index == 0 ? 'Primary phone' : 'Phone ${index + 1}',
                                  prefixIcon: const Icon(Icons.phone_outlined),
                                ),
                              ),
                            ),
                            if (phoneControllers.length > 1)
                              IconButton(
                                tooltip: 'Remove phone number',
                                onPressed: () => setLocal(() => phoneControllers.removeAt(index)),
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                          ],
                        ),
                      );
                    }),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => setLocal(
                          () => phoneControllers.add(TextEditingController()),
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('Add another phone number'),
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: address,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Business Address',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: category.isEmpty ? null : category,
                      decoration: const InputDecoration(
                        labelText: 'Category (Optional)',
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      items: [
                        const DropdownMenuItem<String>(value: '', child: Text('No category')),
                        ...ExpenseCategoryConfig.activeSubcategories.map(
                          (x) => DropdownMenuItem(value: x, child: Text(x)),
                        ),
                      ],
                      onChanged: (value) => setLocal(() => category = value ?? ''),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(existing == null ? 'Add' : 'Save'),
              ),
            ],
          );
        },
      ),
    );

    if (ok != true) return;

    final phones = phoneControllers
        .map((controller) => controller.text.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (name.text.trim().isEmpty) throw StateError('Supplier name is required.');
    if (phones.isEmpty) throw StateError('Add at least one phone number.');

    final supplier = Supplier(
      id: existing?.id ?? '',
      fullName: name.text.trim(),
      businessAddress: address.text.trim(),
      contactNumber: phones.first,
      contactNumbers: phones,
      category: category,
    );

    if (existing == null) {
      await viewModel.add(supplier);
    } else {
      await viewModel.update(supplier);
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(existing == null ? 'Supplier added.' : 'Supplier updated.')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save supplier: $e')),
      );
    }
  } finally {
    for (final controller in phoneControllers) {
      controller.dispose();
    }
    name.dispose();
    address.dispose();
  }
}
