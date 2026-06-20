import 'dart:io';
import 'package:flutter/foundation.dart';

class Env {
  // Configuração rápida para a App do Profissional sem dotenv por enquanto.
  // Mude este IP para o IP da sua máquina se testar num telemóvel real.
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000/api/v1';
    } else if (Platform.isAndroid) {
      // 10.0.2.2 é o localhost do emulador Android
      return 'http://192.168.3.94:3000/api/v1'; // IP fixo que usamos antes no backend
    } else {
      return 'http://localhost:3000/api/v1';
    }
  }
}
