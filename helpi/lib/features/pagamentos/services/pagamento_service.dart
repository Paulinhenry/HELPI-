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
  Future<String> gerarTokenCartao(Map<String, dynamic> cardData) async {
    try {
      final response = await Dio().post(
        'https://api.mercadopago.com/v1/card_tokens',
        queryParameters: {
          'public_key': 'APP_USR-30a5176d-932b-46d0-a06e-0d2bd532c95f',
        },
        data: cardData,
      );
      return response.data['id'];
    } catch (e) {
      if (e is DioException) {
        throw Exception(e.response?.data['message'] ?? 'Erro ao gerar token do cartão. Verifique os dados inseridos.');
      }
      throw Exception('Erro de rede ao validar cartão');
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
