import 'package:dio/dio.dart';
import '../../../core/network/app_client.dart';

class AuthService {
  // O motor de rede profissional que resolve o Localhost e o Interceptor JWT
  final ApiClient _apiClient = ApiClient();

  /// Efetua login de um cliente na API e devolve o Token JWT.
  /// Lança uma Exception com mensagem amigável se falhar.
  Future<String?> loginCliente(String email, String senha) async {
    try {
      // Chamada limpa: sem localhost, sem jsonEncode — o Dio trata de tudo
      final response = await _apiClient.dio.post(
        '/login/clientes',
        data: {
          'email': email,
          'senha': senha,
        },
      );

      if (response.statusCode == 200) {
        return response.data['token']; // Devolve o token JWT
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('E-mail ou senha incorretos.');
      }
      if (e.response?.statusCode == 400) {
        throw Exception('E-mail ou senha incorretos.');
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception('O servidor demorou demasiado a responder.');
      }
      if (e.type == DioExceptionType.connectionError) {
        throw Exception('Não foi possível ligar ao servidor. Verifique a sua internet.');
      }
      throw Exception('Erro de ligação ao servidor. Tente novamente.');
    } catch (e) {
      throw Exception('Ocorreu um erro inesperado.');
    }
  }
}
