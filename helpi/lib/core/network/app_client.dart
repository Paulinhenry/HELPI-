import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  late Dio dio;

  ApiClient() {
    // ⚠️ TRUQUE DE ENGENHARIA MULTIPLATAFORMA:
    // - Web/iOS: usa 'localhost' normalmente
    // - Emulador Android: precisa de '10.0.2.2' para chegar ao PC
    String baseUrl = _resolverBaseUrl();


    dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    // A MÁGICA: O Interceptor
    // Antes de qualquer chamada sair do telemóvel para a internet, ele passa por aqui.
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Vai buscar o "crachá" guardado na memória do telemóvel
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('jwt_token');

        // Se o utilizador tiver um token, injeta-o no cabeçalho
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        
        return handler.next(options); // Continua a viagem
      },
      onError: (DioException e, handler) {
        // Se a API responder 401 (Não Autorizado), podemos forçar o logout aqui no futuro
        return handler.next(e);
      },
    ));
  }

  /// Resolve o endereço base da API de acordo com a plataforma:
  /// - Web: localhost (o browser acede diretamente)
  /// - Android Emulador: 10.0.2.2 (redireciona para o PC host)
  /// - iOS / Desktop: localhost
  static String _resolverBaseUrl() {
    if (kIsWeb) {
      return 'http://[IP_ADDRESS]/api';
    }

    // Importação condicional: só acede a dart:io em plataformas nativas
    try {
      // ignore: uri_does_not_exist
      final isAndroid = defaultTargetPlatform == TargetPlatform.android;
      if (isAndroid) {
        return 'http://[IP_ADDRESS]/api';
      }
    } catch (_) {}

    return 'http://[IP_ADDRESS]/api';
  }
}