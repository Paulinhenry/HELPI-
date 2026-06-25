import 'package:dio/dio.dart';
import '../../../core/network/app_client.dart';

class CategoriasService {
  final ApiClient _apiClient = ApiClient();

  Future<List<Map<String, dynamic>>> obterCategorias() async {
    try {
      final response = await _apiClient.dio.get('/categorias');

      if (response.statusCode == 200) {
        final data = response.data['categorias'] as List;
        return data.map((e) => e as Map<String, dynamic>).toList();
      } else {
        throw Exception('Erro ao carregar categorias.');
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
}
