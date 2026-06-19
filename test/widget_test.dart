// Test minimale: la LoginPage si costruisce senza chiamate a Firebase nel build.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:RomagnaGO/login_page.dart';

void main() {
  testWidgets('LoginPage mostra slogan e link ospite', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginPage(),
      ),
    );

    expect(find.text('Muoversi in Romagna'), findsOneWidget);
    expect(find.text('Continua come ospite'), findsOneWidget);
  });
}
