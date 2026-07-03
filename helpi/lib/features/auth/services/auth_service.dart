import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/network/app_client.dart';

class AuthService {
  // O motor de rede profissional que resolve o Localhost e o Interceptor JWT
  final ApiClient _apiClient = ApiClient();

  /// Efetua login de um cliente na API e devolve os Tokens JWT.
  /// Lança uma Exception com mensagem amigável se falhar.
  Future<Map<String, dynamic>?> loginCliente(String email, String senha) async {
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
        return {
          'access_token': response.data['access_token'],
          'refresh_token': response.data['refresh_token'],
        };
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
      debugPrint('Erro inesperado no loginCliente: $e');
      throw Exception('Ocorreu um erro inesperado.');
    }
  }

  /// Regista um novo cliente na API.
  Future<void> registrarCliente({
    required String nome,
    required String cpf,
    required String email,
    required String senha,
    required String telefone,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/clientes',
        data: {
          'nome': nome,
          'cpf': cpf,
          'email': email,
          'senha': senha,
          'telefone': telefone,
        },
      );

      if (response.statusCode != 201) {
        throw Exception('Não foi possível registrar o cliente.');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        throw Exception(e.response?.data['erro'] ?? 'Dados inválidos.');
      }
      if (e.response?.statusCode == 409) {
        throw Exception(e.response?.data['erro'] ?? 'E-mail ou CPF já cadastrado.');
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
