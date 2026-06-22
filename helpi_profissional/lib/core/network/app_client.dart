import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/env.dart';

class ApiClient {
  // Singleton pattern — garante que só existe uma instância do Dio
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late Dio dio;

  ApiClient._internal() {
    dio = Dio(BaseOptions(
      baseUrl: Env.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    // Interceptor para injetar o Access Token
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('access_token');

        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        
        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        // Auto-refresh do token quando recebe 401
        if (e.response?.statusCode == 401 && e.requestOptions.path != '/auth/refresh' && e.requestOptions.path != '/login/profissionais') {
          try {
            final prefs = await SharedPreferences.getInstance();
            final refreshToken = prefs.getString('refresh_token');

            if (refreshToken != null && refreshToken.isNotEmpty) {
              final refreshDio = Dio(BaseOptions(baseUrl: Env.baseUrl));
              final refreshResponse = await refreshDio.post('/auth/refresh', data: {
                'refresh_token': refreshToken,
              });

              if (refreshResponse.statusCode == 200) {
                final novoToken = refreshResponse.data['access_token'];
                await prefs.setString('access_token', novoToken);

                e.requestOptions.headers['Authorization'] = 'Bearer $novoToken';
                final retryResponse = await dio.fetch(e.requestOptions);
                return handler.resolve(retryResponse);
              }
            }
          } catch (_) {
            // Se o refresh também falhar, propaga o erro original
          }
        }
        return handler.next(e);
      },
    ));
  }
}