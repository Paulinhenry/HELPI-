import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  // Em produção, mude para a URL real da sua API
  static String get baseUrl {
    // Tenta carregar do arquivo .env primeiro
    final apiUrl = dotenv.env['API_URL'];
    if (apiUrl != null && apiUrl.isNotEmpty) {
      return apiUrl;
    }

    // Fallbacks padrão caso não exista arquivo .env ou a variável não esteja definida
    if (kIsWeb) {
      return 'http://localhost:3000/api/v1';
    }
    
    if (Platform.isAndroid) {
      // 10.0.2.2 é o alias do Emulador Android para o localhost do PC
      return 'http://10.0.2.2:3000/api/v1';
    } else {
      // iOS Simulator, Windows App, macOS, etc.
      return 'http://localhost:3000/api/v1';
    }
  }
}
