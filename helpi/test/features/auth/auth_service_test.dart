import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:helpi/features/auth/services/auth_service.dart';
import 'package:helpi/core/network/app_client.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late AuthService authService;
  late MockDio mockDio;

  setUp(() {
    mockDio = MockDio();
    ApiClient().dio = mockDio;
    authService = AuthService();
  });

  group('AuthService Tests', () {
    test('loginCliente deve retornar tokens em caso de sucesso (200)', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/login/clientes'),
          statusCode: 200,
          data: {
            'access_token': 'fake_access_token',
            'refresh_token': 'fake_refresh_token'
          },
        ),
      );

      final result = await authService.loginCliente('teste@helpi.com', '123456');

      expect(result, isNotNull);
      expect(result!['access_token'], 'fake_access_token');
      expect(result['refresh_token'], 'fake_refresh_token');
    });

    test('loginCliente deve lançar exception para e-mail/senha incorretos (401)', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/login/clientes'),
          response: Response(
            requestOptions: RequestOptions(path: '/login/clientes'),
            statusCode: 401,
          ),
        ),
      );

      expect(
        () => authService.loginCliente('teste@helpi.com', 'errada'),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('E-mail ou senha incorretos'))),
      );
    });

    test('registrarCliente deve concluir sem erros em caso de sucesso (201)', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/clientes'),
          statusCode: 201,
        ),
      );

      await expectLater(
        authService.registrarCliente(
          nome: 'João',
          cpf: '12345678900',
          email: 'joao@helpi.com',
          senha: 'senha',
          telefone: '11999999999'
        ),
        completes,
      );
    });

    test('registrarCliente deve lançar exception para e-mail duplicado (409)', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/clientes'),
          response: Response(
            requestOptions: RequestOptions(path: '/clientes'),
            statusCode: 409,
            data: {'erro': 'E-mail ou CPF já cadastrado.'},
          ),
        ),
      );

      expect(
        () => authService.registrarCliente(
          nome: 'João',
          cpf: '12345678900',
          email: 'joao@helpi.com',
          senha: 'senha',
          telefone: '11999999999'
        ),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('E-mail ou CPF já cadastrado'))),
      );
    });
  });
}
