import '../../models/supplier.dart';
import '../repositories/supplier_repository.dart';

final class GetSuppliers {
  const GetSuppliers(this._repository);
  final SupplierRepository _repository;

  Future<List<Supplier>> call() => _repository.getSuppliers();
}
