// =============================================================
// HELPI - Testes do CheckoutScreen (Widget Tests)
// Pilar 2 > Frontend > Testes de Interface
//
// Testa: Renderização do ecrã, valores visíveis, botão PAGAR
// =============================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:helpi/features/chamados/providers/chamados_provider.dart';
import 'package:helpi/features/pagamentos/screens/checkout_screen.dart';

void main() {
  group('🧾 CheckoutScreen — Widget Tests', () {

    // Helper para criar o widget com Provider
    Widget criarCheckoutScreen(Map<String, dynamic> data) {
      return MaterialApp(
        home: ChangeNotifierProvider<ChamadosProvider>(
          create: (_) {
            final provider = ChamadosProvider();
            provider.setCategoria('Elétrica');
            return provider;
          },
          child: CheckoutScreen(data: data),
        ),
      );
    }

    testWidgets('deve exibir "Serviço Concluído!" no ecrã', (tester) async {
      await tester.pumpWidget(criarCheckoutScreen({
        'chamado_id': 'test-123',
        'valor_cobrado': '100.00',
      }));

      expect(find.text('Serviço Concluído!'), findsOneWidget);
    });

    testWidgets('deve exibir o valor cobrado R\$ 100.00', (tester) async {
      await tester.pumpWidget(criarCheckoutScreen({
        'chamado_id': 'test-123',
        'valor_cobrado': '100.00',
      }));

      expect(find.text('R\$ 100.00'), findsWidgets);
    });

    testWidgets('deve exibir a categoria do serviço', (tester) async {
      await tester.pumpWidget(criarCheckoutScreen({
        'chamado_id': 'test-123',
        'valor_cobrado': '100.00',
      }));

      expect(find.text('Elétrica'), findsOneWidget);
    });

    testWidgets('deve ter botão "PAGAR"', (tester) async {
      await tester.pumpWidget(criarCheckoutScreen({
        'chamado_id': 'test-123',
        'valor_cobrado': '100.00',
      }));

      expect(find.text('PAGAR'), findsOneWidget);
    });

    testWidgets('deve exibir "Resumo do Serviço" no AppBar', (tester) async {
      await tester.pumpWidget(criarCheckoutScreen({
        'chamado_id': 'test-123',
        'valor_cobrado': '150.00',
      }));

      expect(find.text('Resumo do Serviço'), findsOneWidget);
    });

    testWidgets('deve mostrar "---" quando valor é null', (tester) async {
      await tester.pumpWidget(criarCheckoutScreen({
        'chamado_id': 'test-123',
      }));

      expect(find.text('---'), findsWidgets);
    });

    testWidgets('deve ter ícone de check verde', (tester) async {
      await tester.pumpWidget(criarCheckoutScreen({
        'chamado_id': 'test-123',
        'valor_cobrado': '200.00',
      }));

      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('deve ter labels "Categoria", "Profissional" e "Total a pagar"', (tester) async {
      await tester.pumpWidget(criarCheckoutScreen({
        'chamado_id': 'test-123',
        'valor_cobrado': '100.00',
      }));

      expect(find.text('Categoria'), findsOneWidget);
      expect(find.text('Profissional'), findsOneWidget);
      expect(find.text('Total a pagar'), findsOneWidget);
    });
  });
}
