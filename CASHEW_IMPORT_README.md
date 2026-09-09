# Cashew import

The Cashew importer preserves the original hierarchy and payer account.

## Imported transaction fields

- Main Category = Cashew main category/phase (for example Layer Bird, Chiks, Renovation, Augar Work)
- Subcategory = normalized editable subcategory
- Original Category = original Cashew subcategory, retained for audit/history
- Account = Cashew wallet/account (Amzad Khan or Sarfaraj Khan)

## Requested mappings

- Layer Feed -> Feed
- Stone -> Grit
- Health -> Medical
- Dr Fee -> Medical
- Healthcare -> Medical
- Vaccine -> Vaccine
- Construction Labor -> Labor
- Steel Labor -> Labor
- Labor work -> Labor
- Construction Materials -> Materials
- Material -> Material

The same subcategory name is allowed under multiple main categories. This lets reports group all Feed, Vaccine, Labor, etc. transactions while preserving the phase/main-category path.
