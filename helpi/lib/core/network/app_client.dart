import 'dart:io';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  late Dio dio;

  ApiClient() {
    // ⚠️ ATENÇÃO - TRUQUE DE ENGENHARIA MOBILE:
    // O emulador do Android não entende 'localhost' (ele acha que o localhost é o próprio telemóvel).
    // Para aceder ao Node.js que está a rodar no teu computador, temos de usar '10.0.2.2'.
    // Se for iOS ou Web, usa 'localhost'.
    String baseUrl = Platform.isAndroid 
        ? 'http://10.0.2.2:3000/api' 
        : 'http://localhost:3000/api';

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
}