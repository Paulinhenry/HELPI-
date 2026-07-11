import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/env.dart';

class ApiClient {
  // Singleton pattern — garante que só existe uma instância do Dio
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late Dio dio;

  // SEGURANÇA V13: Tokens armazenados no KeyStore/Keychain (não em SharedPreferences plaintext)
  static const _storage = FlutterSecureStorage();

  ApiClient._internal() {
    dio = Dio(BaseOptions(
      baseUrl: Env.baseUrl,
      // SEGURANÇA V14: Timeouts reduzidos para melhor UX
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    // Interceptor para injetar o Access Token
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'access_token');

        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        
        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        // ARCH 2: Auto-refresh do token quando recebe 401
        if (e.response?.statusCode == 401 && e.requestOptions.path != '/auth/refresh' && e.requestOptions.path != '/login/clientes') {
          try {
            final refreshToken = await _storage.read(key: 'refresh_token');

            if (refreshToken != null && refreshToken.isNotEmpty) {
              // Tenta renovar o access token usando o refresh token
              final refreshDio = Dio(BaseOptions(baseUrl: Env.baseUrl));
              final refreshResponse = await refreshDio.post('/auth/refresh', data: {
                'refresh_token': refreshToken,
              });

              if (refreshResponse.statusCode == 200) {
                final novoToken = refreshResponse.data['access_token'];
                await _storage.write(key: 'access_token', value: novoToken);

                // Repete a request original com o novo token
                e.requestOptions.headers['Authorization'] = 'Bearer $novoToken';
                final retryResponse = await dio.fetch(e.requestOptions);
                return handler.resolve(retryResponse);
              } else {
                // Falhou o refresh, limpa os tokens para forçar relogin na próxima vez
                await _storage.delete(key: 'access_token');
                await _storage.delete(key: 'refresh_token');
              }
            }
          } catch (_) {
            // Se o refresh também falhar, propaga o erro original e limpa
            await _storage.delete(key: 'access_token');
            await _storage.delete(key: 'refresh_token');
          }
        }
        return handler.next(e);
      },
    ));
  }
}