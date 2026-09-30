// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planazo/theme/app_theme.dart';

void main() {
  testWidgets('Planazo aplica la identidad visual',
      (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: PlanazoTheme.lightTheme,
      home: const Scaffold(
        body: Center(child: Text('Planazo')),
      ),
    ));

    expect(find.text('Planazo'), findsOneWidget);
    expect(PlanazoTheme.lightTheme.colorScheme.primary, PlanazoColors.amarillo);
  });
}
