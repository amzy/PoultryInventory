class ExpenseCategoryConfig {
  static const accounts = <String>[
    'Amzad Khan',
    'Sarfaraj Khan',
  ];

  /// Only these four main categories are part of the current financial model.
  static const mainCategories = <String>[
    'Layer Bird',
    'Chiks',
    'Renovation',
    'Augar Work',
  ];

  static const subcategoriesByMain = <String, List<String>>{
    'Layer Bird': [
      'Feed', 'Medical', 'Vaccine', 'Tray', 'Egg', 'Electricity', 'Grit', 'Other Expenses',
    ],
    'Chiks': [
      'Feed', 'Vaccine', 'Medical', 'Preparation', 'Water', 'Other Expenses',
    ],
    'Renovation': [
      'Labor', 'Materials', 'Other Expenses',
    ],
    'Augar Work': [
      'Labor', 'Material', 'Other Expenses',
    ],
  };

  static bool isValidMainCategory(String value) => mainCategories.contains(value.trim());

  static bool isValidSubcategory(String mainCategory, String subcategory) =>
      subcategoriesFor(mainCategory).contains(subcategory.trim());

  static List<String> subcategoriesFor(String mainCategory) {
    final configured = subcategoriesByMain[mainCategory.trim()];
    return configured ?? const [];
  }

  /// Maps the source Cashew top-level category to the current financial model.
  /// Electricity was a source top-level category, but is represented by
  /// Layer Bird -> Electricity in the new model.
  static String normalizeImportedMainCategory(String source) {
    final value = source.trim();
    switch (value.toLowerCase()) {
      case 'layer bird':
        return 'Layer Bird';
      case 'chiks':
        return 'Chiks';
      case 'renovation':
        return 'Renovation';
      case 'augar work':
        return 'Augar Work';
      case 'electricity':
        return 'Layer Bird';
      default:
        throw FormatException('Unsupported Cashew main category: $value');
    }
  }

  /// Maps Cashew's source subcategory names to the current subcategory set.
  /// If a source transaction has no real subcategory and the source category
  /// itself is one of the four main categories, it is retained as Other Expenses
  /// rather than inventing a more specific category.
  static String normalizeImportedSubcategory(String mainCategory, String source) {
    final value = source.trim();
    final main = mainCategory.trim();
    final lower = value.toLowerCase();

    if (main.toLowerCase() == 'electricity' && value.isEmpty) {
      return 'Electricity';
    }

    switch (lower) {
      case 'layer feed':
        return 'Feed';
      case 'stone':
        return 'Grit';
      case 'health':
      case 'dr fee':
      case 'healthcare':
        return 'Medical';
      case 'vaccine':
        return 'Vaccine';
      case 'construction labor':
      case 'steel labor':
      case 'labor work':
        return 'Labor';
      case 'construction materials':
        return 'Materials';
      case 'material':
        return 'Material';
      case 'electricity':
        return 'Electricity';
    }

    // A top-level Cashew category can also appear as the subcategory when the
    // source transaction has no separate subcategory. Preserve that fact in
    // originalCategory and use the neutral current bucket.
    if (value.isEmpty || value.toLowerCase() == main.toLowerCase()) {
      return 'Other Expenses';
    }

    if (subcategoriesFor(main).contains(value)) return value;

    throw FormatException(
      'Unsupported Cashew subcategory "$value" for main category "$main".',
    );
  }
}
