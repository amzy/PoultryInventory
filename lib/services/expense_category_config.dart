class ExpenseCategoryConfig {
  static const accounts = <String>[
    'Amzad Khan',
    'Sarfaraj Khan',
  ];

  static List<String> runtimeAccounts = List<String>.from(accounts);

  static List<String> get activeAccounts =>
      List.unmodifiable(runtimeAccounts.isEmpty ? accounts : runtimeAccounts);

  static void setAccounts(List<String> values) {
    final cleaned = values
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    runtimeAccounts =
        cleaned.isEmpty ? List<String>.from(accounts) : cleaned;
  }

  /// Only these four main categories are part of the current financial model.
  static const mainCategories = <String>[
    'Layer Bird',
    'Chiks',
    'Renovation',
    'Augar Work',
  ];

  /// Global subcategory catalog. Subcategories are independent of the main
  /// category and contain only canonical names used by the current app.
  static const defaultSubcategories = <String>[
    'Feed',
    'Medical',
    'Vaccine',
    'Tray',
    'Egg',
    'Electricity',
    'Grit',
    'Preparation',
    'Water',
    'Labor',
    'Material',
    'Other Expenses',
  ];

  static List<String> runtimeSubcategories =
      List<String>.from(defaultSubcategories);

  static List<String> get activeSubcategories => List.unmodifiable(
        runtimeSubcategories.isEmpty
            ? defaultSubcategories
            : runtimeSubcategories,
      );

  static void setSubcategories(List<String> values) {
    final cleaned = values
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    runtimeSubcategories = cleaned.isEmpty
        ? List<String>.from(defaultSubcategories)
        : cleaned;
  }

  static bool isValidMainCategory(String value) =>
      mainCategories.contains(value.trim());

  static bool isValidSubcategory(String mainCategory, String subcategory) =>
      activeSubcategories.contains(subcategory.trim());
}
