// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poultry_inventory/screens/legal_documents_screen.dart';

void main() {
  testWidgets('Privacy Policy page renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PrivacyPolicyScreen(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Privacy Policy'), findsWidgets);
    expect(find.text('Poultry Inventory'), findsWidgets);
    expect(
      find.textContaining('amzy21@gmail.com'),
      findsOneWidget,
    );
  });

  testWidgets('Terms and Conditions page renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TermsAndConditionsScreen(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Terms & Conditions'), findsWidgets);
    expect(find.text('Poultry Inventory'), findsWidgets);
    expect(
      find.textContaining('amzy21@gmail.com'),
      findsOneWidget,
    );
  });
}