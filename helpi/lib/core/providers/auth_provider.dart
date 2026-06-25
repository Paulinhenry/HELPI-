import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider with ChangeNotifier {
  bool _isLoggedIn = false;
  bool _isLoading = true; 
  String? _userId;

  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  String? get userId => _userId;

  // Função auxiliar para descodificar JWT
  Map<String, dynamic>? _decodeJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      return json.decode(decoded);
    } catch (e) {
      return null;
    }
  }

  Future<void> checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    if (token != null && token.isNotEmpty) {
      _isLoggedIn = true;
      final decoded = _decodeJwt(token);
      _userId = decoded?['id']?.toString();
    } else {
      _isLoggedIn = false;
      _userId = null;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> login(String accessToken, String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('access_token', accessToken);
    await prefs.setString('refresh_token', refreshToken);

    _isLoggedIn = true;
    final decoded = _decodeJwt(accessToken);
    _userId = decoded?['id']?.toString();
    
    notifyListeners();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token'); 
    await prefs.remove('refresh_token'); 
    _isLoggedIn = false;
    _userId = null;
    notifyListeners();
  }
}
