// Teste básico de widget para verificar que a app Helpi arranca corretamente.

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:helpi/main.dart';
import 'package:helpi/core/providers/auth_provider.dart';

void main() {
  testWidgets('Helpi app arranca e mostra o logo', (WidgetTester tester) async {
    // A HelpiApp precisa de um Provider para funcionar
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider()..checkLoginStatus(),
        child: const HelpiApp(),
      ),
    );

    // Aguarda a verificação do token completar
    await tester.pumpAndSettle();

    // Verifica que a app arrancou (mostra o texto HELPI na splash ou no login)
    expect(find.text('HELPI'), findsOneWidget);
  });
}
