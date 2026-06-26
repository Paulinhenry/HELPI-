import 'package:dio/dio.dart';
import '../../../core/network/app_client.dart';

class ChamadosService {
  final ApiClient _apiClient = ApiClient();

  Future<String> criarChamado({
    required String categoria,
    required String descricao,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/chamados',
        data: {
          'categoria_solicitada': categoria,
          'problema_descricao': descricao,
          'latitude_destino': latitude,
          'longitude_destino': longitude,
        },
      );

      if (response.statusCode == 201) {
        return response.data['chamado']['id'].toString();
      } else {
        throw Exception('Erro ao criar chamado. Tente novamente.');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception(e.response?.data['erro'] ?? 'Nenhum profissional encontrado.');
      }
      if (e.response?.statusCode == 400) {
         throw Exception(e.response?.data['erro'] ?? 'Dados inválidos.');
      }
      throw Exception('Erro de conexão ao servidor.');
    } catch (e) {
      throw Exception('Ocorreu um erro inesperado.');
    }
  }
  // Nova função para cancelar o pedido
  Future<void> cancelarChamado(String chamadoId) async {
    try {
      final response = await _apiClient.dio.patch('/chamados/$chamadoId/cancelar');
      
      if (response.statusCode != 200) {
        throw Exception('Falha ao cancelar o chamado no servidor.');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(e.response?.data['erro'] ?? 'Erro no servidor.');
      }
      throw Exception('Sem ligação à internet.');
    } catch (e) {
      throw Exception('Erro inesperado: $e');
    }
  }

  /// CRASH RECOVERY: Verifica se o cliente tem um chamado em andamento
  Future<Map<String, dynamic>?> verificarChamadoAtivo() async {
    try {
      final response = await _apiClient.dio.get('/chamados/meu-ativo');
      final chamadoAtivo = response.data['chamado_ativo'];
      if (chamadoAtivo != null) {
        return Map<String, dynamic>.from(chamadoAtivo);
      }
      return null;
    } on DioException {
      return null;
    }
  }
}
