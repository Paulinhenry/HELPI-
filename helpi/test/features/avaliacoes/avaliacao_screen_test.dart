import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helpi/features/avaliacoes/screens/avaliacao_screen.dart';
import 'package:helpi/features/avaliacoes/services/avaliacao_service.dart';

// Mock simples para não usar bibliotecas externas complexas
class MockAvaliacaoService implements AvaliacaoService {
  bool chamadaRealizada = false;

  @override
  Future<void> enviarAvaliacaoCliente({
    required String chamadoId,
    required int nota,
    required List<String> tags,
    String? comentario,
  }) async {
    chamadaRealizada = true;
    // Simula delay de rede
    await Future.delayed(const Duration(milliseconds: 100));
  }
}

void main() {
  group('🛡️ Pilar 3: AvaliacaoScreen (App Cliente)', () {
    late MockAvaliacaoService mockService;
    late Map<String, dynamic> mockData;

    setUp(() {
      mockService = MockAvaliacaoService();
      mockData = {
        'chamado_id': 'uuid-teste-123',
        'profissional_nome': 'Eletricista João',
      };
    });

    Widget _construirApp() {
      return MaterialApp(
        home: AvaliacaoScreen(
          data: mockData,
          avaliacaoService: mockService,
        ),
      );
    }

    testWidgets('Deve exibir o nome do profissional no ecrã', (tester) async {
      await tester.pumpWidget(_construirApp());

      expect(find.textContaining('Eletricista João'), findsOneWidget);
      expect(find.text('Como foi o serviço de Eletricista João?'), findsOneWidget);
    });

    testWidgets('UX Dinâmica: Clicar em 5 estrelas mostra Tags Verdes e Gorjeta', (tester) async {
      await tester.pumpWidget(_construirApp());

      // No início, as tags não estão visíveis
      expect(find.text('Excelente'), findsNothing);
      expect(find.text('Enviar Gorjeta?'), findsNothing);

      // Clica na 5ª estrela (A última da lista de 5)
      final estrelas = find.byIcon(Icons.star_outline_rounded);
      expect(estrelas, findsNWidgets(5));
      await tester.tap(estrelas.last);
      await tester.pumpAndSettle();

      // Verifica se a tag verde de excelência apareceu
      expect(find.text('Excelente'), findsOneWidget);
      expect(find.text('Muito Limpo'), findsOneWidget);

      // Verifica se a máquina de gorjeta apareceu
      expect(find.text('Enviar Gorjeta?'), findsOneWidget);
      expect(find.text('R\$ 5'), findsOneWidget);
      expect(find.text('R\$ 20'), findsOneWidget);
    });

    testWidgets('UX Dinâmica: Clicar em 1 estrela mostra Tags Vermelhas (Red Flags)', (tester) async {
      await tester.pumpWidget(_construirApp());

      // Clica na 1ª estrela
      final estrelas = find.byIcon(Icons.star_outline_rounded);
      await tester.tap(estrelas.first);
      await tester.pumpAndSettle();

      // Verifica as Red Flags
      expect(find.text('Atrasado'), findsOneWidget);
      expect(find.text('Trabalho Mal Feito'), findsOneWidget);
      expect(find.text('Grosseiro'), findsOneWidget);

      // Máquina de gorjeta NÃO deve aparecer
      expect(find.text('Enviar Gorjeta?'), findsNothing);
    });

    testWidgets('Deve permitir selecionar tags, gorjeta e enviar avaliação com sucesso', (tester) async {
      await tester.pumpWidget(_construirApp());

      // 1. Dar 5 estrelas
      await tester.tap(find.byIcon(Icons.star_outline_rounded).last);
      await tester.pumpAndSettle();

      // 2. Clicar numa Tag ("Rápido")
      await tester.tap(find.text('Rápido'));
      await tester.pumpAndSettle();

      // 3. Escolher Gorjeta (R$ 10)
      await tester.tap(find.text('R\$ 10'));
      await tester.pumpAndSettle();

      // 4. Escrever um comentário
      await tester.enterText(find.byType(TextField), 'Serviço 5 estrelas!');
      await tester.pumpAndSettle();

      // 5. Clicar em Enviar (fazendo scroll até o botão)
      final botaoEnviar = find.text('ENVIAR AVALIAÇÃO');
      await tester.ensureVisible(botaoEnviar);
      await tester.tap(botaoEnviar);
      await tester.pump(); // Inicia o future

      // Verifica se o botão está em loading (CircularProgressIndicator)
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Aguarda o delay do Mock e a resolução do Future
      await tester.pump(const Duration(milliseconds: 200)); 

      // Verifica se o serviço mock foi chamado
      expect(mockService.chamadaRealizada, isTrue);
    });
  });
}
