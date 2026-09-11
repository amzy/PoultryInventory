class Supplier {
  final String id;
  final String fullName;
  final String businessAddress;
  final String contactNumber;
  final List<String> contactNumbers;
  final String category;

  const Supplier({
    required this.id,
    required this.fullName,
    this.businessAddress = '',
    this.contactNumber = '',
    this.contactNumbers = const [],
    this.category = '',
  });

  List<String> get phoneNumbers {
    final values = <String>[];
    void add(String value) {
      final normalized = value.trim();
      if (normalized.isNotEmpty && !values.contains(normalized)) values.add(normalized);
    }
    add(contactNumber);
    for (final number in contactNumbers) add(number);
    return values;
  }

  factory Supplier.fromFirestore(Map<String, dynamic> data, {required String id}) {
    final rawNumbers = data['contactNumbers'];
    final numbers = rawNumbers is List
        ? rawNumbers.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList()
        : <String>[];
    final legacy = data['contactNumber']?.toString().trim() ?? '';
    if (legacy.isNotEmpty && !numbers.contains(legacy)) numbers.insert(0, legacy);
    return Supplier(
      id: id,
      fullName: data['fullName']?.toString() ?? '',
      businessAddress: data['businessAddress']?.toString() ?? '',
      contactNumber: legacy,
      contactNumbers: numbers,
      category: data['category']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
    'fullName': fullName.trim(),
    'businessAddress': businessAddress.trim(),
    // Keep the legacy field for backward compatibility.
    'contactNumber': phoneNumbers.isNotEmpty ? phoneNumbers.first : '',
    'contactNumbers': phoneNumbers,
    'category': category.trim(),
  };

  Supplier copyWith({
    String? id,
    String? fullName,
    String? businessAddress,
    String? contactNumber,
    List<String>? contactNumbers,
    String? category,
  }) => Supplier(
    id: id ?? this.id,
    fullName: fullName ?? this.fullName,
    businessAddress: businessAddress ?? this.businessAddress,
    contactNumber: contactNumber ?? this.contactNumber,
    contactNumbers: contactNumbers ?? this.contactNumbers,
    category: category ?? this.category,
  );
}
