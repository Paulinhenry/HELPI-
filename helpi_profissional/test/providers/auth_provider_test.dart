import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:helpi_profissional/core/providers/auth_provider.dart';
import 'package:helpi_profissional/core/network/app_client.dart';
import 'package:dio/dio.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AuthProvider authProvider;
  late MockDio mockDio;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockDio = MockDio();
    ApiClient().dio = mockDio;
    authProvider = AuthProvider();
  });

  group('AuthProvider Tests (Profissional)', () {
    test('estado inicial deve ser não logado', () {
      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.profissionalId, isNull);
      expect(authProvider.nome, isNull);
    });

    test('login deve atualizar estado e guardar no SharedPreferences', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/login/profissionais'),
          statusCode: 200,
          data: {
            'access_token': 'fake_access_token',
            'refresh_token': 'fake_refresh_token',
            'usuario': {
              'id': 'prof-123',
              'nome': 'Carlos Silva'
            }
          },
        ),
      );

      await authProvider.login('carlos@helpi.com', '123456');

      expect(authProvider.isAuthenticated, isTrue);
      expect(authProvider.profissionalId, 'prof-123');
      expect(authProvider.nome, 'Carlos Silva');
      
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('access_token'), 'fake_access_token');
      expect(prefs.getString('refresh_token'), 'fake_refresh_token');
      expect(prefs.getString('usuarioId'), 'prof-123');
    });

    test('logout deve limpar SharedPreferences e estado', () async {
      SharedPreferences.setMockInitialValues({
        'access_token': 'token',
        'usuarioId': 'prof-123'
      });
      
      await authProvider.checkLoginStatus(); // mockChamadoService will fail but it's handled
      expect(authProvider.isAuthenticated, isTrue);
      
      await authProvider.logout();
      
      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.profissionalId, isNull);
      
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('access_token'), isNull);
    });

    test('checkLoginStatus deve recuperar login do SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'access_token': 'token',
        'usuarioId': 'prof-123',
        'nome': 'João'
      });
      
      await authProvider.checkLoginStatus();
      
      expect(authProvider.isAuthenticated, isTrue);
      expect(authProvider.profissionalId, 'prof-123');
      expect(authProvider.nome, 'João');
    });
  });
}
