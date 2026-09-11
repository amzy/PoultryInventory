import '../../models/supplier.dart';
import '../../services/firebase_service.dart';
import '../../domain/repositories/supplier_repository.dart';

/// Firebase implementation of the supplier repository.
///
/// All Firestore access stays in the data layer. This keeps the UI and
/// business logic independent from Firebase.
final class FirebaseSupplierRepository implements SupplierRepository {
  FirebaseSupplierRepository(this._service);

  final FirebaseService _service;

  @override
  Future<List<Supplier>> getSuppliers() => _service.fetchSuppliers();

  @override
  Future<String> addSupplier(Supplier supplier) => _service.addSupplier(supplier);

  @override
  Future<void> updateSupplier(Supplier supplier) => _service.updateSupplier(supplier);

  @override
  Future<void> deleteSupplier(String supplierId) => _service.deleteSupplier(supplierId);
}
