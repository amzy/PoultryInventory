import '../repositories/supplier_repository.dart';

final class DeleteSupplier {
  const DeleteSupplier(this._repository);
  final SupplierRepository _repository;

  Future<void> call(String supplierId) => _repository.deleteSupplier(supplierId);
}
