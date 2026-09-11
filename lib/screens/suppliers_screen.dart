import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/repositories/firebase_supplier_repository.dart';
import '../models/supplier.dart';
import '../presentation/viewmodels/supplier_view_model.dart';
import '../providers/poultry_provider.dart';
import '../services/expense_category_config.dart';
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

  @override
  void initState() {
    super.initState();
    _viewModel = SupplierViewModel(
      repository: FirebaseSupplierRepository(FirebaseService()),
    )..load();
  }

  @override
  void dispose() {
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
        if (isAdmin)
          FilledButton.icon(
            onPressed: viewModel.isSaving ? null : () => _showSupplierEditor(context, viewModel),
            icon: const Icon(Icons.add),
            label: const Text('Add Supplier'),
          ),
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
