import 'package:flutter_test/flutter_test.dart';

import 'package:poultry_inventory/main.dart';

void main() {
  testWidgets('shows poultry inventory sign in screen', (tester) async {
    await tester.pumpWidget(const PoultryInventoryApp());

    expect(find.text('Poultry Inventory Dashboard'), findsOneWidget);
    expect(find.text('Sign in with Google'), findsOneWidget);
  });
}
