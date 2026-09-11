import '../../models/supplier.dart';

/// Domain contract for supplier data.
///
/// The presentation layer depends only on this abstraction and never on
/// Firebase/Firestore details.
abstract interface class SupplierRepository {
  Future<List<Supplier>> getSuppliers();
  Future<String> addSupplier(Supplier supplier);
  Future<void> updateSupplier(Supplier supplier);
  Future<void> deleteSupplier(String supplierId);
}
