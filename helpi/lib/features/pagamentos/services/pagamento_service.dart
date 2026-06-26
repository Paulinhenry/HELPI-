import 'package:dio/dio.dart';
import '../../../core/network/app_client.dart';

class PagamentoService {
  final ApiClient _apiClient = ApiClient();

  Future<Map<String, dynamic>> estimarPreco(String categoria, String descricao) async {
    try {
      final response = await _apiClient.dio.post(
        '/pagamentos/estimar',
        data: {
          'categoria': categoria,
          'descricao': descricao,
        },
      );
      return response.data['estimativa'];
    } catch (e) {
      if (e is DioException) {
        throw Exception(e.response?.data['erro'] ?? 'Erro ao estimar preço do serviço');
      }
      throw Exception('Erro inesperado ao estimar preço do serviço');
    }
  }

  Future<Map<String, dynamic>> processarPagamento(String chamadoId, String metodo, {Map<String, dynamic>? dadosCartao}) async {
    try {
      final response = await _apiClient.dio.post(
        '/pagamentos/processar',
        data: {
          'chamado_id': chamadoId,
          'payment_method_id': metodo,
          'payer': {
            'email': 'cliente@helpi.com', // Placeholder para MVP, ideal pegar do AuthProvider
            'identification': {'type': 'CPF', 'number': '12345678909'}
          },
          ...?dadosCartao
        },
      );
      return response.data;
    } catch (e) {
      if (e is DioException) {
        throw Exception(e.response?.data['erro'] ?? 'Erro ao processar pagamento');
      }
      throw Exception('Falha ao conectar com o servidor para pagamento');
    }
  }
}
