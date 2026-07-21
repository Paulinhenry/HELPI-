import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:helpi/features/chamados/services/chamados_service.dart';
import 'package:helpi/core/network/app_client.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late ChamadosService chamadosService;
  late MockDio mockDio;

  setUp(() {
    mockDio = MockDio();
    ApiClient().dio = mockDio;
    chamadosService = ChamadosService();
  });

  group('ChamadosService Tests', () {
    test('criarChamado deve retornar ID do chamado em caso de sucesso (201)', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/chamados'),
          statusCode: 201,
          data: {
            'chamado': {
              'id': 'chamado-123'
            }
          },
        ),
      );

      final result = await chamadosService.criarChamado(
        categoria: 'Eletricista',
        descricao: 'Fio solto',
        latitude: -23.5,
        longitude: -46.6
      );

      expect(result, 'chamado-123');
    });

    test('criarChamado deve lançar exception se não encontrar profissionais (404)', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/chamados'),
          response: Response(
            requestOptions: RequestOptions(path: '/chamados'),
            statusCode: 404,
            data: {'erro': 'Nenhum profissional encontrado.'},
          ),
        ),
      );

      expect(
        () => chamadosService.criarChamado(
          categoria: 'Eletricista',
          descricao: 'Fio solto',
          latitude: -23.5,
          longitude: -46.6
        ),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Nenhum profissional encontrado'))),
      );
    });

    test('cancelarChamado deve concluir com sucesso (200)', () async {
      when(() => mockDio.patch(any())).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/chamados/chamado-123/cancelar'),
          statusCode: 200,
        ),
      );

      await expectLater(
        chamadosService.cancelarChamado('chamado-123'),
        completes,
      );
    });

    test('verificarChamadoAtivo deve retornar dados do chamado', () async {
      when(() => mockDio.get(any())).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/chamados/meu-ativo'),
          statusCode: 200,
          data: {
            'chamado_ativo': {
              'id': 'chamado-ativo-123',
              'status': 'procurando'
            }
          },
        ),
      );

      final result = await chamadosService.verificarChamadoAtivo();

      expect(result, isNotNull);
      expect(result!['id'], 'chamado-ativo-123');
      expect(result['status'], 'procurando');
    });

    test('verificarChamadoAtivo deve retornar nulo se não houver chamado ou erro (404)', () async {
      when(() => mockDio.get(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/chamados/meu-ativo'),
          response: Response(
            requestOptions: RequestOptions(path: '/chamados/meu-ativo'),
            statusCode: 404,
          ),
        ),
      );

      final result = await chamadosService.verificarChamadoAtivo();

      expect(result, isNull);
    });
  });
}
