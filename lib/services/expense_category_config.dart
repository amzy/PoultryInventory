class ExpenseCategoryConfig {
  static const accounts = <String>[
    'Amzad Khan',
    'Sarfaraj Khan',
  ];

  static const mainCategories = <String>[
    'Poultry',
    'Layer Bird',
    'Chiks',
    'Renovation',
    'Augar Work',
    'Cashew',
    'Farm',
  ];

  // A subcategory belongs to a main category path. The same subcategory name
  // can intentionally appear under multiple main categories.
  static const subcategoriesByMain = <String, List<String>>{
    'Poultry': [
      'Feed', 'Medical', 'Grit', 'Electricity', 'Tray', 'Other Expenses', 'Egg Sales',
    ],
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
    'Cashew': [
      'Feed', 'Medical', 'Grit', 'Electricity', 'Tray', 'Vaccine', 'Labor', 'Materials', 'Other Expenses',
    ],
    'Farm': [
      'Feed', 'Medical', 'Grit', 'Electricity', 'Tray', 'Labor', 'Materials', 'Other Expenses',
    ],
  };

  static List<String> subcategoriesFor(String mainCategory) {
    final configured = subcategoriesByMain[mainCategory];
    if (configured != null) return configured;
    return const ['Feed', 'Medical', 'Grit', 'Electricity', 'Tray', 'Vaccine', 'Labor', 'Materials', 'Other Expenses'];
  }

  static String normalizeImportedSubcategory(String mainCategory, String source) {
    final value = source.trim();
    if (value.isEmpty) return mainCategory.trim().isEmpty ? 'Other Expenses' : mainCategory.trim();
    switch (value.toLowerCase()) {
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
      default:
        return value;
    }
  }
}
