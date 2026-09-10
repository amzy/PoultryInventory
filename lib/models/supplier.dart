class Supplier {
  final String id;
  final String fullName;
  final String businessAddress;
  final String contactNumber;

  const Supplier({
    required this.id,
    required this.fullName,
    this.businessAddress = '',
    this.contactNumber = '',
  });

  factory Supplier.fromFirestore(Map<String, dynamic> data, {required String id}) {
    return Supplier(
      id: id,
      fullName: data['fullName']?.toString() ?? '',
      businessAddress: data['businessAddress']?.toString() ?? '',
      contactNumber: data['contactNumber']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
    'fullName': fullName.trim(),
    'businessAddress': businessAddress.trim(),
    'contactNumber': contactNumber.trim(),
  };

  Supplier copyWith({
    String? id,
    String? fullName,
    String? businessAddress,
    String? contactNumber,
  }) => Supplier(
    id: id ?? this.id,
    fullName: fullName ?? this.fullName,
    businessAddress: businessAddress ?? this.businessAddress,
    contactNumber: contactNumber ?? this.contactNumber,
  );
}
