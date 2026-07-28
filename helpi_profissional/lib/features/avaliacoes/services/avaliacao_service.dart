import 'package:dio/dio.dart';
import '../../../core/network/app_client.dart';

class AvaliacaoService {
  final ApiClient _apiClient = ApiClient();

  Future<void> enviarAvaliacaoProfissional({
    required String chamadoId,
    required int nota,
    required List<String> tags,
    String? comentario,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/avaliacoes/profissional',
        data: {
          'chamado_id': chamadoId,
          'nota': nota,
          'tags': tags,
          'comentario': comentario,
        },
      );

      if (response.statusCode != 201) {
        throw Exception('Erro ao enviar avaliação: ${response.statusCode}');
      }
    } on DioException catch (e) {
      // ✅ Extrai a mensagem do backend diretamente — sem double-wrap
      if (e.response?.statusCode == 409) {
        throw Exception('Você já avaliou este serviço.');
      }
      final mensagem = e.response?.data?['erro'] ?? e.message ?? 'Erro desconhecido';
      throw Exception(mensagem);
    }
    // ✅ Removido catch (e) genérico que causava "Exception: Exception: ..."
  }
}

