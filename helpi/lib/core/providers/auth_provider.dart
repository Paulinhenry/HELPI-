import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import '../services/socket_service.dart';
import '../config/env.dart';

class AuthProvider with ChangeNotifier {
  bool _isLoggedIn = false;
  bool _isLoading = true; 
  String? _userId;

  // SEGURANÇA V13: Armazenamento seguro para tokens
  static const _storage = FlutterSecureStorage();

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
    final token = await _storage.read(key: 'access_token');

    if (token != null && token.isNotEmpty) {
      final decoded = _decodeJwt(token);
      final exp = decoded?['exp'];
      
      if (exp != null && DateTime.fromMillisecondsSinceEpoch(exp * 1000).isAfter(DateTime.now())) {
        _isLoggedIn = true;
        _userId = decoded?['id']?.toString();
      } else {
        // Token expirado - tentar refresh
        final refreshToken = await _storage.read(key: 'refresh_token');
        if (refreshToken != null && refreshToken.isNotEmpty) {
          try {
            final refreshDio = Dio(BaseOptions(baseUrl: Env.baseUrl));
            final refreshResponse = await refreshDio.post('/auth/refresh', data: {
              'refresh_token': refreshToken,
            });

            if (refreshResponse.statusCode == 200) {
              final novoToken = refreshResponse.data['access_token'];
              await _storage.write(key: 'access_token', value: novoToken);
              _isLoggedIn = true;
              final newDecoded = _decodeJwt(novoToken);
              _userId = newDecoded?['id']?.toString();
            } else {
              _isLoggedIn = false;
              _userId = null;
            }
          } catch (e) {
            _isLoggedIn = false;
            _userId = null;
          }
        } else {
          _isLoggedIn = false;
          _userId = null;
        }
      }
    } else {
      _isLoggedIn = false;
      _userId = null;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> login(String accessToken, String refreshToken) async {
    await _storage.write(key: 'access_token', value: accessToken);
    await _storage.write(key: 'refresh_token', value: refreshToken);

    _isLoggedIn = true;
    final decoded = _decodeJwt(accessToken);
    _userId = decoded?['id']?.toString();
    
    notifyListeners();
  }

  Future<void> logout() async {
    await _storage.delete(key: 'access_token'); 
    await _storage.delete(key: 'refresh_token'); 
    _isLoggedIn = false;
    _userId = null;
    
    // Disconnect socket properly
    SocketService().desconectar();
    
    notifyListeners();
  }
}
