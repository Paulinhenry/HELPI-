import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../network/app_client.dart';

class AuthProvider with ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
  
  bool _isAuthenticated = false;
  int? _profissionalId;
  String? _nome;

  bool get isAuthenticated => _isAuthenticated;
  int? get profissionalId => _profissionalId;
  String? get nome => _nome;

  Future<void> checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token != null) {
      _isAuthenticated = true;
      _profissionalId = prefs.getInt('usuarioId'); // Lê o ID real do BD
      _nome = prefs.getString('nome');
    }
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
      final profissional = response.data['profissional']; // A API retorna 'profissional'

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);
      await prefs.setInt('usuarioId', profissional['id']);
      await prefs.setString('nome', profissional['nome']);

      _isAuthenticated = true;
      _profissionalId = profissional['id'];
      _nome = profissional['nome'];
      
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
    notifyListeners();
  }
}
