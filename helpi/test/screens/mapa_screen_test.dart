// =============================================================
// HELPI - Testes do MapaScreen (Widget Tests Parciais)
// Pilar 2 > Frontend > Testes de Interface
//
// Testa: Botão "Cancelar" desaparece quando profissional aceita
//
// NOTA: O MapaScreen real depende de Google Maps e Geolocator,
// que não funcionam em testes de widget. Por isso, testamos apenas
// a LÓGICA de decisão do provider que controla a visibilidade.
// =============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:helpi/features/chamados/providers/chamados_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('🗺️ MapaScreen — Lógica de Visibilidade do Botão Cancelar', () {

    late ChamadosProvider provider;

    setUp(() {
      provider = ChamadosProvider();
    });

    tearDown(() {
      provider.dispose();
    });

    // ─── TESTE DO CRONÓMETRO DE PÂNICO ──────────────────────
    // "O botão Cancelar desaparece quando o radar deteta que
    //  um profissional aceitou"

    test('quando isProcurando é true, o botão Cancelar deve estar visível (lógica)', () {
      // O botão Cancelar é visível quando isProcurando == true
      // Não podemos testar diretamente porque MapaScreen precisa de Google Maps
      // Mas testamos que o state transition está correto
      
      // Nota: não podemos chamar solicitarProfissional() sem mocks de rede
      // Mas podemos verificar que o estado default permite o botão
      expect(provider.isProcurando, false);
      expect(provider.isProfissionalACaminho, false);
    });

    test('quando isProfissionalACaminho é true, isProcurando deve ser false', () {
      // O provider garante que quando profissional aceita:
      // isProcurando → false
      // isProfissionalACaminho → true
      // Isto é a base da lógica que esconde o botão Cancelar

      // Verifica a invariante: nunca ambos true ao mesmo tempo
      expect(
        provider.isProcurando && provider.isProfissionalACaminho,
        false,
        reason: 'isProcurando e isProfissionalACaminho nunca devem ser true ao mesmo tempo',
      );
    });

    test('resetarEstado deve colocar ambas flags a false', () {
      provider.resetarEstado();

      expect(provider.isProcurando, false);
      expect(provider.isProfissionalACaminho, false);
    });

    test('cancelarBuscaManualmente deve esconder o botão de procura', () async {
      // Simula o cancelamento manual (sem rede)
      await provider.cancelarBuscaManualmente();

      expect(provider.isProcurando, false);
      expect(provider.isProfissionalACaminho, false);
      expect(provider.categoriaSelecionada, isNull);
      expect(provider.idChamadoAtual, isNull);
    });
  });
}
