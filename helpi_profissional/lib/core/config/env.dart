import 'dart:io';
import 'package:flutter/foundation.dart';

class Env {
  // Em produção, mude para a URL real da sua API (ex: https://api.helpi.com.br/api/v1)
  // Para testar num telemóvel real na rede local, use o IP da sua máquina (ex: http://192.168.X.X:3000/api/v1)
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000/api/v1';
    } else if (Platform.isAndroid) {
      // 10.0.2.2 é o alias do localhost do PC no emulador Android
      return 'http://10.0.2.2:3000/api/v1';
    } else {
      // iOS Simulator, Windows, macOS, etc.
      return 'http://localhost:3000/api/v1';
    }
  }
}
