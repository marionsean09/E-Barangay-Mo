import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:e_barangay_mo/features/auth/login_page.dart';

void main() {
  testWidgets('Login page shows the log in and sign up actions',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));

    expect(find.widgetWithText(ElevatedButton, 'Log in'), findsOneWidget);
    expect(find.text('Create an account'), findsOneWidget);
  });
}
