import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:helpi_profissional/services/chamado_service.dart';
import 'package:helpi_profissional/core/network/app_client.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late ChamadoService chamadoService;
  late MockDio mockDio;

  setUp(() {
    mockDio = MockDio();
    ApiClient().dio = mockDio;
    chamadoService = ChamadoService();
  });

  group('ChamadoService Tests (Profissional)', () {
    test('aceitarChamado deve retornar dados do chamado (200)', () async {
      when(() => mockDio.put(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/chamados/chamado-123/aceitar'),
          statusCode: 200,
          data: {
            'chamado': {
              'id': 'chamado-123',
              'status': 'aceite'
            }
          },
        ),
      );

      final result = await chamadoService.aceitarChamado('chamado-123');
      
      expect(result['id'], 'chamado-123');
      expect(result['status'], 'aceite');
    });

    test('aceitarChamado deve lançar ChamadoJaAceitoException (400)', () async {
      when(() => mockDio.put(any(), data: any(named: 'data'))).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/chamados/chamado-123/aceitar'),
          response: Response(
            requestOptions: RequestOptions(path: '/chamados/chamado-123/aceitar'),
            statusCode: 400,
            data: {'erro': 'Chamado já aceite por outro profissional.'},
          ),
        ),
      );

      expect(
        () => chamadoService.aceitarChamado('chamado-123'),
        throwsA(isA<ChamadoJaAceitoException>()),
      );
    });

    test('registrarChegada deve retornar dados do chamado (200)', () async {
      when(() => mockDio.put(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/chamados/chamado-123/chegada'),
          statusCode: 200,
          data: {
            'chamado': {
              'id': 'chamado-123',
              'status': 'em_local'
            }
          },
        ),
      );

      final result = await chamadoService.registrarChegada('chamado-123');
      
      expect(result['id'], 'chamado-123');
      expect(result['status'], 'em_local');
    });

    test('finalizarChamado deve retornar dados do chamado (200)', () async {
      when(() => mockDio.put(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/chamados/chamado-123/finalizar'),
          statusCode: 200,
          data: {
            'chamado': {
              'id': 'chamado-123',
              'status': 'finalizado',
              'valor_cobrado': 150.0
            }
          },
        ),
      );

      final result = await chamadoService.finalizarChamado('chamado-123', valorCobrado: 150.0);
      
      expect(result['id'], 'chamado-123');
      expect(result['status'], 'finalizado');
      expect(result['valor_cobrado'], 150.0);
    });

    test('verificarChamadoAtivo deve retornar dados se existir chamado', () async {
      when(() => mockDio.get(any())).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/chamados/em-andamento'),
          statusCode: 200,
          data: {
            'chamado_ativo': {
              'id': 'chamado-ativo-123',
              'status': 'aceite'
            }
          },
        ),
      );

      final result = await chamadoService.verificarChamadoAtivo();
      
      expect(result, isNotNull);
      expect(result!['id'], 'chamado-ativo-123');
    });

    test('verificarChamadoAtivo deve retornar null em caso de erro', () async {
      when(() => mockDio.get(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/chamados/em-andamento'),
          response: Response(
            requestOptions: RequestOptions(path: '/chamados/em-andamento'),
            statusCode: 404,
          ),
        ),
      );

      final result = await chamadoService.verificarChamadoAtivo();
      
      expect(result, isNull);
    });
  });
}
