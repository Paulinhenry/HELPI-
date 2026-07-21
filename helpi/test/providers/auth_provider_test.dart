import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:helpi/core/providers/auth_provider.dart';
import 'dart:convert';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AuthProvider authProvider;

  String generateMockJwt({bool expired = false}) {
    final header = base64Url.encode(utf8.encode(json.encode({"alg": "HS256", "typ": "JWT"})));
    final exp = expired
        ? DateTime.now().subtract(const Duration(days: 1)).millisecondsSinceEpoch ~/ 1000
        : DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch ~/ 1000;
        
    final payload = base64Url.encode(utf8.encode(json.encode({
      "id": "123-abc",
      "tipo": "cliente",
      "exp": exp
    })));
    return "$header.$payload.signature";
  }

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    authProvider = AuthProvider();
  });

  group('AuthProvider Tests', () {
    test('estado inicial deve ser não logado', () {
      expect(authProvider.isLoggedIn, isFalse);
      expect(authProvider.isLoading, isTrue); // initial value is true
      expect(authProvider.userId, isNull);
    });

    test('login deve atualizar estado e guardar tokens', () async {
      final token = generateMockJwt();
      
      await authProvider.login(token, 'refresh-token');
      
      expect(authProvider.isLoggedIn, isTrue);
      expect(authProvider.userId, '123-abc');
      
      final storage = FlutterSecureStorage();
      final storedToken = await storage.read(key: 'access_token');
      expect(storedToken, token);
    });

    test('logout deve limpar tokens e atualizar estado', () async {
      final token = generateMockJwt();
      await authProvider.login(token, 'refresh-token');
      
      await authProvider.logout();
      
      expect(authProvider.isLoggedIn, isFalse);
      expect(authProvider.userId, isNull);
      
      final storage = FlutterSecureStorage();
      final storedToken = await storage.read(key: 'access_token');
      expect(storedToken, isNull);
    });

    test('checkLoginStatus deve validar token não expirado', () async {
      final token = generateMockJwt(expired: false);
      FlutterSecureStorage.setMockInitialValues({
        'access_token': token,
        'refresh_token': 'refresh-token'
      });
      
      await authProvider.checkLoginStatus();
      
      expect(authProvider.isLoggedIn, isTrue);
      expect(authProvider.isLoading, isFalse);
      expect(authProvider.userId, '123-abc');
    });

    test('checkLoginStatus deve falhar para token inválido/expirado sem refresh disponível', () async {
      final token = generateMockJwt(expired: true);
      FlutterSecureStorage.setMockInitialValues({
        'access_token': token,
        // sem refresh_token
      });
      
      await authProvider.checkLoginStatus();
      
      expect(authProvider.isLoggedIn, isFalse);
      expect(authProvider.isLoading, isFalse);
      expect(authProvider.userId, isNull);
    });
  });
}
