import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider with ChangeNotifier {
  bool _isLoggedIn = false;
  bool _isLoading = true; 

  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;

  // Verifica o Token REAL na memória do telemóvel
  Future<void> checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    
    if (token != null && token.isNotEmpty) {
      _isLoggedIn = true;
    } else {
      _isLoggedIn = false;
    }
    
    _isLoading = false;
    notifyListeners(); 
  }

  // O Victor vai chamar esta função quando a API responder com sucesso
  Future<void> login(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token); 
    _isLoggedIn = true;
    notifyListeners();
  }

  // Função para o botão de "Sair da Conta"
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token'); 
    _isLoggedIn = false;
    notifyListeners();
  }
}
