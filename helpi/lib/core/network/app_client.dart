import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  late Dio dio;

  ApiClient() {
    // Vai buscar a URL base com o teu IP da rede Wi-Fi
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

  static String _resolverBaseUrl() {
    // ⚠️ PASSO ÚNICO PARA TESTAR NO TELEMÓVEL FÍSICO:
    // Substitui o IP abaixo pelo "Endereço IPv4" real que apareceu no teu CMD (ipconfig)
    const String ipDoMeuComputador = '192.168.3.94'; // <--- MUDA APENAS ISTO
    
    // A porta onde o teu servidor Node.js está a correr
    const String porta = '3000';

    // Como o teu telemóvel físico e o computador estão na MESMA REDE Wi-Fi,
    // esta URL vai funcionar perfeitamente sem precisares de lógicas complexas.
    return 'http://$ipDoMeuComputador:$porta/api';
  }
}