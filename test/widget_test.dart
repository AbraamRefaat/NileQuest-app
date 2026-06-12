// Widget tests for the Nile Quest welcome screen.
//
// The full app (NileQuestApp) boots into a splash screen and runs an async
// Firebase auth check, which cannot run in the widget test environment.
// Instead we pump WelcomeScreen directly — it has no Firebase dependency.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nile_quest/screens/welcome_screen.dart';
import 'package:nile_quest/theme.dart';

void main() {
  Widget buildWelcomeScreen({
    VoidCallback? onLogin,
    VoidCallback? onGuest,
  }) {
    return MaterialApp(
      theme: AppTheme.theme,
      home: WelcomeScreen(
        onLogin: onLogin ?? () {},
        onGuest: onGuest ?? () {},
      ),
    );
  }

  testWidgets('Welcome screen shows title and action buttons',
      (WidgetTester tester) async {
    await tester.pumpWidget(buildWelcomeScreen());
    // Let the entrance animations finish.
    await tester.pumpAndSettle();

    expect(find.text('Nile Quest'), findsOneWidget);
    expect(find.text('Discover the Magic of Egypt'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
    expect(find.text('Continue as Guest'), findsOneWidget);
  });

  testWidgets('Log In button invokes onLogin callback',
      (WidgetTester tester) async {
    var loginTapped = false;
    await tester.pumpWidget(
      buildWelcomeScreen(onLogin: () => loginTapped = true),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Log In'));
    expect(loginTapped, isTrue);
  });

  testWidgets('Continue as Guest button invokes onGuest callback',
      (WidgetTester tester) async {
    var guestTapped = false;
    await tester.pumpWidget(
      buildWelcomeScreen(onGuest: () => guestTapped = true),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue as Guest'));
    expect(guestTapped, isTrue);
  });
}
