class Supplier {
  final String id;
  final String fullName;
  final String businessAddress;
  final String contactNumber;
  final String category;

  const Supplier({
    required this.id,
    required this.fullName,
    this.businessAddress = '',
    this.contactNumber = '',
    this.category = '',
  });

  factory Supplier.fromFirestore(Map<String, dynamic> data, {required String id}) {
    return Supplier(
      id: id,
      fullName: data['fullName']?.toString() ?? '',
      businessAddress: data['businessAddress']?.toString() ?? '',
      contactNumber: data['contactNumber']?.toString() ?? '',
      category: data['category']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
    'fullName': fullName.trim(),
    'businessAddress': businessAddress.trim(),
    'contactNumber': contactNumber.trim(),
    'category': category.trim(),
  };

  Supplier copyWith({
    String? id,
    String? fullName,
    String? businessAddress,
    String? contactNumber,
    String? category,
  }) => Supplier(
    id: id ?? this.id,
    fullName: fullName ?? this.fullName,
    businessAddress: businessAddress ?? this.businessAddress,
    contactNumber: contactNumber ?? this.contactNumber,
    category: category ?? this.category,
  );
}
