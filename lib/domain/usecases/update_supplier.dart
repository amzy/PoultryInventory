import '../../models/supplier.dart';
import '../repositories/supplier_repository.dart';

final class UpdateSupplier {
  const UpdateSupplier(this._repository);
  final SupplierRepository _repository;

  Future<void> call(Supplier supplier) => _repository.updateSupplier(supplier);
}
