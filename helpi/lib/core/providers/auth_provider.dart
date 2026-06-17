import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider with ChangeNotifier {
  bool _isLoggedIn = false;
  bool _isLoading = true; // Para mostrar um ecrã de carregamento enquanto verifica o token

  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;

  // 1. Função que corre assim que a App abre
  Future<void> checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    
    // Se encontrou um token na memória, o utilizador está logado!
    if (token != null && token.isNotEmpty) {
      _isLoggedIn = true;
    } else {
      _isLoggedIn = false;
    }
    
    _isLoading = false;
    notifyListeners(); // Avisa o Flutter para redesenhar o ecrã
  }

  // 2. O Victor vai chamar esta função quando a API responder com sucesso
  Future<void> login(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token); // Guarda o crachá
    _isLoggedIn = true;
    notifyListeners();
  }

  // 3. Função para o botão de "Sair da Conta"
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token'); // Destrói o crachá
    _isLoggedIn = false;
    notifyListeners();
  }
}
