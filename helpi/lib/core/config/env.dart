import 'dart:io';
import 'package:flutter/foundation.dart';

class Env {
  // Em produção, mude para a URL real da sua API
  static String get baseUrl {
    // Se estiver a usar um telemóvel físico (conectado por cabo/Wi-Fi), 
    // substitua as linhas abaixo pelo seu IP da rede local. Exemplo:
    // return 'http://192.168.1.15:3000/api/v1';

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
