// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planazo/models/models.dart';
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

  test('los puntos avanzan por los cuatro niveles de confianza', () {
    expect(NivelConfianza.desdePuntos(0), NivelConfianza.nuevo);
    expect(NivelConfianza.desdePuntos(99), NivelConfianza.nuevo);
    expect(NivelConfianza.desdePuntos(100), NivelConfianza.regular);
    expect(NivelConfianza.desdePuntos(249), NivelConfianza.regular);
    expect(NivelConfianza.desdePuntos(250), NivelConfianza.confiable);
    expect(NivelConfianza.desdePuntos(399), NivelConfianza.confiable);
    expect(NivelConfianza.desdePuntos(400), NivelConfianza.lider);
    expect(NivelConfianza.regular.progreso(175), closeTo(0.5, 0.001));
  });

  test('un chat directo sin título usa el nombre del otro integrante', () {
    final chat = Chat(
      id: 'chat-1',
      esGrupal: false,
      contactoNombre: 'Camila Pérez',
      contactoFoto: 'https://example.com/camila.png',
      creadoEn: DateTime.utc(2026),
    );

    expect(chat.displayTitle, 'Camila Pérez');
  });
}
