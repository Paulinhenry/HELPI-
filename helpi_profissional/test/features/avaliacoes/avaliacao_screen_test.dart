import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helpi_profissional/features/avaliacoes/screens/avaliacao_screen.dart';
import 'package:helpi_profissional/features/avaliacoes/services/avaliacao_service.dart';

// Mock simples
class MockAvaliacaoService implements AvaliacaoService {
  bool chamadaRealizada = false;

  @override
  Future<void> enviarAvaliacaoProfissional({
    required String chamadoId,
    required int nota,
    required List<String> tags,
    String? comentario,
  }) async {
    chamadaRealizada = true;
    await Future.delayed(const Duration(milliseconds: 100));
  }
}

void main() {
  group('🛡️ Pilar 4: AvaliacaoScreen (App Profissional)', () {
    late MockAvaliacaoService mockService;
    
    setUp(() {
      mockService = MockAvaliacaoService();
    });

    Widget construirApp() {
      return MaterialApp(
        home: AvaliacaoScreen(
          chamadoId: 'uuid-teste-123',
          nomeCliente: 'Sr. Antônio',
          avaliacaoService: mockService,
        ),
      );
    }

    testWidgets('Deve exibir o nome do cliente no ecrã', (tester) async {
      await tester.pumpWidget(construirApp());

      expect(find.textContaining('Sr. Antônio'), findsOneWidget);
    });

    testWidgets('UX Profissional: Clicar em 5 estrelas mostra Tags Verdes de Bom Cliente', (tester) async {
      await tester.pumpWidget(construirApp());

      // No início, as tags não estão visíveis
      expect(find.text('Ótimo Cliente'), findsNothing);

      // Clica na 5ª estrela
      final estrelas = find.byIcon(Icons.star_outline_rounded);
      await tester.tap(estrelas.last);
      await tester.pumpAndSettle();

      // Verifica as tags verdes
      expect(find.text('Ótimo Cliente'), findsOneWidget);
      expect(find.text('Pagou Rápido'), findsOneWidget);
    });

    testWidgets('UX Profissional: Clicar em 1 estrela mostra Tags Vermelhas (Proteção)', (tester) async {
      await tester.pumpWidget(construirApp());

      // Clica na 1ª estrela
      final estrelas = find.byIcon(Icons.star_outline_rounded);
      await tester.tap(estrelas.first);
      await tester.pumpAndSettle();

      // Verifica as tags vermelhas de alerta
      expect(find.text('Cliente Grosseiro'), findsOneWidget);
      expect(find.text('Atrasado'), findsOneWidget);
      expect(find.text('Cancelou no Local'), findsOneWidget);
    });

    testWidgets('Deve permitir avaliar o cliente e enviar para o Motor de Confiança', (tester) async {
      await tester.pumpWidget(construirApp());

      // 1. Dar 5 estrelas
      await tester.tap(find.byIcon(Icons.star_outline_rounded).last);
      await tester.pumpAndSettle();

      // 2. Selecionar uma tag
      await tester.tap(find.text('Pagou Rápido'));
      await tester.pumpAndSettle();

      // 3. Clicar em Enviar
      final botaoEnviar = find.text('ENVIAR AVALIAÇÃO');
      await tester.ensureVisible(botaoEnviar);
      await tester.tap(botaoEnviar);
      await tester.pump();

      // Verifica se entrou em loading
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle(); // Aguarda o delay

      // Verifica sucesso
      expect(mockService.chamadaRealizada, isTrue);
    });
  });
}
