import 'package:dio/dio.dart';
import '../core/network/app_client.dart';

/// Service responsável por chamadas HTTP relacionadas a chamados.
/// Usa o [ApiClient] singleton que já injeta o JWT automaticamente.
class ChamadoService {
  final Dio _dio = ApiClient().dio;

  /// Aceita um chamado de emergência.
  /// Retorna os dados do chamado incluindo coordenadas do cliente.
  /// Lança exceção se o chamado já foi aceite por outro profissional.
  Future<Map<String, dynamic>> aceitarChamado(String chamadoId) async {
    try {
      final response = await _dio.put('/chamados/$chamadoId/aceitar');
      return Map<String, dynamic>.from(response.data['chamado']);
    } on DioException catch (e) {
      if (e.response != null) {
        final statusCode = e.response!.statusCode;
        final mensagem = e.response!.data['erro'] ?? 'Erro desconhecido';

        if (statusCode == 400) {
          // Outro profissional já aceitou (race condition tratada pelo backend)
          throw ChamadoJaAceitoException(mensagem);
        } else if (statusCode == 404) {
          throw ChamadoNaoEncontradoException(mensagem);
        }
        throw Exception(mensagem);
      }
      throw Exception('Erro de ligação ao servidor. Verifique a sua internet.');
    }
  }

  /// Regista a chegada do profissional ao local.
  Future<Map<String, dynamic>> registrarChegada(String chamadoId) async {
    try {
      final response = await _dio.put('/chamados/$chamadoId/chegada');
      return Map<String, dynamic>.from(response.data['chamado']);
    } on DioException catch (e) {
      final mensagem = e.response?.data['erro'] ?? 'Erro ao registar chegada';
      throw Exception(mensagem);
    }
  }
}

/// Exceção quando outro profissional já aceitou o chamado.
class ChamadoJaAceitoException implements Exception {
  final String mensagem;
  ChamadoJaAceitoException(this.mensagem);
  @override
  String toString() => mensagem;
}

/// Exceção quando o chamado não existe.
class ChamadoNaoEncontradoException implements Exception {
  final String mensagem;
  ChamadoNaoEncontradoException(this.mensagem);
  @override
  String toString() => mensagem;
}
