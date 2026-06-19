import 'package:dio/dio.dart';
import '../../../core/network/app_client.dart';

class ChamadosService {
  final ApiClient _apiClient = ApiClient();

  Future<void> criarChamado({
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
        return; // Sucesso
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
}
