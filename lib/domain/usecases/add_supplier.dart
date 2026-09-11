import '../../models/supplier.dart';
import '../repositories/supplier_repository.dart';

final class AddSupplier {
  const AddSupplier(this._repository);
  final SupplierRepository _repository;

  Future<String> call(Supplier supplier) => _repository.addSupplier(supplier);
}
