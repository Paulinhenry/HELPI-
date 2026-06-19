// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:helpi_profissional/main.dart';

void main() {
  testWidgets('App start smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // Como a app precisa do Provider para arrancar, injetamos aqui se fosse um teste completo.
    // Por agora, apenas testamos se a classe base arranca sem dar crash
    await tester.pumpWidget(const HelpiProfissionalApp());

    // Verifica se a app não dá crash ao inicializar.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
