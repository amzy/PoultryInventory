import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../../core/services/supplier_share_service.dart';
import '../../core/utils/vcard_generator.dart';
import '../../domain/repositories/supplier_repository.dart';
import '../../domain/usecases/add_supplier.dart';
import '../../domain/usecases/delete_supplier.dart';
import '../../domain/usecases/get_suppliers.dart';
import '../../domain/usecases/update_supplier.dart';
import '../../models/supplier.dart';
import '../../services/vcard_file_saver.dart';

/// MVVM state holder for the Suppliers feature.
///
/// Filtering/selection is kept in memory and is derived from one source list,
/// so Firestore is not queried on every search/filter change.
final class SupplierViewModel extends ChangeNotifier {
  SupplierViewModel({required SupplierRepository repository})
      : _getSuppliers = GetSuppliers(repository),
        _addSupplier = AddSupplier(repository),
        _updateSupplier = UpdateSupplier(repository),
        _deleteSupplier = DeleteSupplier(repository);

  final GetSuppliers _getSuppliers;
  final AddSupplier _addSupplier;
  final UpdateSupplier _updateSupplier;
  final DeleteSupplier _deleteSupplier;
  final VCardGenerator _vCardGenerator = const VCardGenerator();
  final SupplierShareService _shareService = const SupplierShareService();

  List<Supplier> _suppliers = const [];
  String _query = '';
  String? _category;
  final Set<String> _selectedIds = <String>{};
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isExporting = false;
  String? _error;

  List<Supplier> get suppliers => _suppliers;
  String get query => _query;
  String? get category => _category;
  Set<String> get selectedIds => Set.unmodifiable(_selectedIds);
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get isExporting => _isExporting;
  String? get error => _error;

  List<String> get categories {
    final values = _suppliers
        .map((s) => s.category.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return values;
  }

  List<Supplier> get filteredSuppliers {
    final query = _query.toLowerCase();
    return _suppliers.where((supplier) {
      if (_category != null && supplier.category != _category) return false;
      if (query.isEmpty) return true;
      return supplier.fullName.toLowerCase().contains(query) ||
          supplier.phoneNumbers.any((phone) => phone.toLowerCase().contains(query)) ||
          supplier.businessAddress.toLowerCase().contains(query) ||
          supplier.category.toLowerCase().contains(query);
    }).toList(growable: false);
  }

  List<Supplier> get selectedSuppliers => _suppliers
      .where((supplier) => _selectedIds.contains(supplier.id))
      .toList(growable: false);

  Future<void> load({bool force = false}) async {
    if (_isLoading && !force) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final suppliers = await _getSuppliers();
      _suppliers = _sort(suppliers);
      _pruneSelection();
    } catch (e) {
      _error = 'Unable to load suppliers: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setQuery(String value) {
    if (_query == value) return;
    _query = value;
    _pruneSelection();
    notifyListeners();
  }

  void setCategory(String? value) {
    if (value == _category) return;
    _category = value;
    _pruneSelection();
    notifyListeners();
  }

  void toggleSelection(String id) {
    if (!_selectedIds.add(id)) _selectedIds.remove(id);
    notifyListeners();
  }

  void clearSelection() {
    if (_selectedIds.isEmpty) return;
    _selectedIds.clear();
    notifyListeners();
  }

  Future<void> add(Supplier supplier) async {
    await _runSave(() async {
      final id = await _addSupplier(supplier);
      _suppliers = _sort([..._suppliers, supplier.copyWith(id: id)]);
    });
  }

  Future<void> update(Supplier supplier) async {
    await _runSave(() async {
      _suppliers = _sort(_suppliers.map((item) => item.id == supplier.id ? supplier : item).toList());
      await _updateSupplier(supplier);
    }, rollback: () async => load(force: true));
  }

  Future<void> delete(String supplierId) async {
    await _runSave(() async {
      await _deleteSupplier(supplierId);
      _suppliers = _suppliers.where((item) => item.id != supplierId).toList(growable: false);
      _selectedIds.remove(supplierId);
    });
  }

  Future<void> exportToFile(Iterable<Supplier> suppliers) async {
    final list = suppliers.toList(growable: false);
    if (list.isEmpty) return;
    _isExporting = true;
    _error = null;
    notifyListeners();
    try {
      final fileName = list.length == 1 ? '${_safeName(list.first.fullName)}.vcf' : 'supplier_contacts.vcf';
      await saveVCardFile(Uint8List.fromList(_vCardGenerator.bytes(list)), fileName);
    } catch (e) {
      _error = 'Unable to export contacts: $e';
      rethrow;
    } finally {
      _isExporting = false;
      notifyListeners();
    }
  }

  Future<void> sendToWhatsApp(Iterable<Supplier> suppliers) async {
    final list = suppliers.toList(growable: false);
    if (list.isEmpty) return;
    _isExporting = true;
    _error = null;
    notifyListeners();
    try {
      await _shareService.sendViaWhatsApp(list);
    } catch (e) {
      _error = 'Unable to send contacts via WhatsApp: $e';
      rethrow;
    } finally {
      _isExporting = false;
      notifyListeners();
    }
  }

  Future<void> _runSave(Future<void> Function() operation, {Future<void> Function()? rollback}) async {
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      await operation();
    } catch (e) {
      if (rollback != null) await rollback();
      _error = 'Unable to save supplier: $e';
      rethrow;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  List<Supplier> _sort(Iterable<Supplier> values) {
    return values.toList(growable: false)
      ..sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
  }

  void _pruneSelection() {
    final visibleIds = filteredSuppliers.map((s) => s.id).toSet();
    _selectedIds.removeWhere((id) => !visibleIds.contains(id));
  }

  String _safeName(String value) {
    final name = value.trim().replaceAll(RegExp(r'[^a-zA-Z0-9 _-]+'), '_').trim();
    return name.isEmpty ? 'supplier_contact' : name.replaceAll(RegExp(r'\s+'), '_');
  }
}
