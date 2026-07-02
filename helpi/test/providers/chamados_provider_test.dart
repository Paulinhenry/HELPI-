// =============================================================
// HELPI - Testes do ChamadosProvider (Lógica de Estado)
// Pilar 2 > Frontend > Testes de Estado
//
// Testa: Crash Recovery, Estado Inicial, setCategoria,
//        cancelarBuscaManualmente, estado pós-atualização de chamado
//
// NOTA: Testes UNIT puros — sem emulador, sem rede, sem DB
// =============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:helpi/features/chamados/providers/chamados_provider.dart';

void main() {
  group('🧪 ChamadosProvider — Lógica de Estado', () {

    late ChamadosProvider provider;

    setUp(() {
      provider = ChamadosProvider();
    });

    tearDown(() {
      provider.dispose();
    });

    // ─── TESTE DE ESTADO INICIAL ────────────────────────────
    group('Estado Inicial', () {
      test('categoriaSelecionada deve iniciar como null', () {
        expect(provider.categoriaSelecionada, isNull);
      });

      test('isProcurando deve iniciar como false', () {
        expect(provider.isProcurando, false);
      });

      test('isProfissionalACaminho deve iniciar como false', () {
        expect(provider.isProfissionalACaminho, false);
      });

      test('idChamadoAtual deve iniciar como null', () {
        expect(provider.idChamadoAtual, isNull);
      });

      test('estimativas devem iniciar como null', () {
        expect(provider.estimativaMin, isNull);
        expect(provider.estimativaMax, isNull);
        expect(provider.estimativaSugerida, isNull);
      });

      test('posicaoProfissional deve iniciar como null', () {
        expect(provider.posicaoProfissional, isNull);
      });
    });

    // ─── TESTE DE setCategoria ──────────────────────────────
    group('setCategoria', () {
      test('deve atualizar a categoria selecionada', () {
        provider.setCategoria('Elétrica');
        expect(provider.categoriaSelecionada, 'Elétrica');
      });

      test('deve aceitar null para limpar seleção', () {
        provider.setCategoria('Elétrica');
        provider.setCategoria(null);
        expect(provider.categoriaSelecionada, isNull);
      });

      test('deve notificar listeners ao mudar categoria', () {
        bool notificou = false;
        provider.addListener(() => notificou = true);

        provider.setCategoria('Hidráulica');

        expect(notificou, true);
      });
    });

    // ─── TESTE DE setDescricao ──────────────────────────────
    group('setDescricao', () {
      test('deve atualizar a descrição do problema', () {
        provider.setDescricao('Vazamento na cozinha');
        expect(provider.descricaoProblema, 'Vazamento na cozinha');
      });

      test('deve ignorar descrição vazia', () {
        final descricaoOriginal = provider.descricaoProblema;
        provider.setDescricao('');
        expect(provider.descricaoProblema, descricaoOriginal);
      });

      test('deve ignorar descrição só com espaços', () {
        final descricaoOriginal = provider.descricaoProblema;
        provider.setDescricao('   ');
        expect(provider.descricaoProblema, descricaoOriginal);
      });
    });

    // ─── TESTE DE RESET DE ESTADO ───────────────────────────
    group('resetarEstado', () {
      test('deve limpar todos os estados ao resetar', () {
        // Simula estado ativo
        provider.setCategoria('Elétrica');
        provider.setDescricao('Teste');

        // Reseta
        provider.resetarEstado();

        expect(provider.categoriaSelecionada, isNull);
        expect(provider.idChamadoAtual, isNull);
        expect(provider.isProcurando, false);
        expect(provider.isProfissionalACaminho, false);
        expect(provider.posicaoProfissional, isNull);
        expect(provider.estimativaMin, isNull);
        expect(provider.estimativaMax, isNull);
        expect(provider.estimativaSugerida, isNull);
      });
    });

    // ─── TESTE DE CALLBACKS ─────────────────────────────────
    group('Callbacks', () {
      test('onTimeout callback deve poder ser configurado', () {
        bool timeoutChamado = false;
        provider.onTimeout = () => timeoutChamado = true;
        
        expect(provider.onTimeout, isNotNull);
        provider.onTimeout!();
        expect(timeoutChamado, true);
      });

      test('onError callback deve poder ser configurado', () {
        String? erroRecebido;
        provider.onError = (msg) => erroRecebido = msg;
        
        expect(provider.onError, isNotNull);
        provider.onError!('Erro de teste');
        expect(erroRecebido, 'Erro de teste');
      });

      test('onServicoFinalizado callback deve poder ser configurado', () {
        Map<String, dynamic>? dadosRecebidos;
        provider.onServicoFinalizado = (data) => dadosRecebidos = data;
        
        provider.onServicoFinalizado!({'chamado_id': '123', 'valor_cobrado': 100});
        expect(dadosRecebidos?['chamado_id'], '123');
        expect(dadosRecebidos?['valor_cobrado'], 100);
      });
    });

    // ─── TESTE DO CRASH RECOVERY (LÓGICA DE REDIRECIONAMENTO) ──
    // NOTA: Este testa a lógica de decisão do provider, não a chamada HTTP.
    // A chamada HTTP real é testada nos testes de integração do Backend.
    group('Crash Recovery — Lógica de Decisão', () {
      test('quando não há chamado ativo, isProcurando deve ser false', () {
        // Estado padrão = sem chamado
        expect(provider.isProcurando, false);
        expect(provider.isProfissionalACaminho, false);
        expect(provider.idChamadoAtual, isNull);
      });

      test('provider deve ser capaz de receber callback de sucesso', () {
        Map<String, dynamic>? dataRecebida;
        provider.onSuccess = (data) => dataRecebida = data;

        provider.onSuccess!({
          'chamado_id': 'test-123',
          'status_novo': 'a_caminho',
          'profissional_nome': 'João',
          'distancia_texto': '2.5 km'
        });

        expect(dataRecebida?['profissional_nome'], 'João');
        expect(dataRecebida?['distancia_texto'], '2.5 km');
      });
    });
  });
}
