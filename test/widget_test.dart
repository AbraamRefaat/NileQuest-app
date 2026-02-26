// This is a basic Flutter widget test for Nile Quest app.

import 'package:flutter_test/flutter_test.dart';

import 'package:nile_quest/main.dart';

void main() {
  testWidgets('Nile Quest app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const NileQuestApp());

    // Verify that the Welcome screen loads with "Nile Quest" text
    expect(find.text('Nile Quest'), findsOneWidget);
    
    // Verify the Log In button exists
    expect(find.text('Log In'), findsOneWidget);
    
    // Verify the Continue as Guest button exists
    expect(find.text('Continue as Guest'), findsOneWidget);
  });
}
