import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../network/app_client.dart';
import '../../services/chamado_service.dart';

class AuthProvider with ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
  
  bool _isAuthenticated = false;
  String? _profissionalId;
  String? _nome;

  // CRASH RECOVERY: Guarda o chamado ativo (se existir) para o roteador
  Map<String, dynamic>? _chamadoAtivo;

  bool get isAuthenticated => _isAuthenticated;
  String? get profissionalId => _profissionalId;
  String? get nome => _nome;
  Map<String, dynamic>? get chamadoAtivo => _chamadoAtivo;

  Future<void> checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token != null) {
      _isAuthenticated = true;
      _profissionalId = prefs.getString('usuarioId'); // Lê o ID real do BD
      _nome = prefs.getString('nome');

      // CRASH RECOVERY: Pergunta ao servidor se há corrida ativa
      // Se o profissional tinha um chamado quando a bateria morreu,
      // o roteador vai atirá-lo direto para o MapaRotaScreen
      try {
        final chamadoService = ChamadoService();
        _chamadoAtivo = await chamadoService.verificarChamadoAtivo();
      } catch (e) {
        // Se falhar (offline, timeout), deixa ir para o Radar normalmente
        _chamadoAtivo = null;
        debugPrint('[CrashRecovery] Não foi possível verificar chamado ativo: $e');
      }
    }
    notifyListeners();
  }

  /// Limpa o chamado ativo (quando o profissional volta ao Radar após finalizar)
  void limparChamadoAtivo() {
    _chamadoAtivo = null;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    try {
      // NOTA: Ajusta esta rota para a rota exata de login de profissionais do teu Node.js!
      final response = await _apiClient.dio.post(
        '/login/profissionais', // A rota do backend é /api/v1/login/profissionais (o dio já tem base url com /api/v1)
        data: {'email': email, 'senha': password},
      );

      final token = response.data['access_token'];
      final profissional = response.data['usuario']; // A API retorna 'usuario'

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', token);
      await prefs.setString('usuarioId', profissional['id']);
      await prefs.setString('nome', profissional['nome']);

      _isAuthenticated = true;
      _profissionalId = profissional['id'];
      _nome = profissional['nome'];
      _chamadoAtivo = null; // Login fresco, sem chamado ativo
      
      notifyListeners();
    } on DioException catch (e) {
      throw Exception(e.response?.data['erro'] ?? 'Erro de ligação ao servidor');
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _isAuthenticated = false;
    _profissionalId = null;
    _nome = null;
    _chamadoAtivo = null;
    notifyListeners();
  }
}
