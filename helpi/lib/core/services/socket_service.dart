import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/env.dart';

class SocketService {
  // Singleton pattern
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  io.Socket? _socket;

  io.Socket? get socket => _socket;

  void conectar() {
    if (_socket != null && _socket!.connected) return;

    // A URL do Env.baseUrl geralmente tem '/api/v1'. Precisamos apenas da raiz.
    // Ex: 'http://192.168.3.94:3000/api/v1' -> 'http://192.168.3.94:3000'
    String serverUrl = Env.baseUrl.split('/api/v1').first;

    _socket = io.io(serverUrl, io.OptionBuilder()
      .setTransports(['websocket'])
      .disableAutoConnect()
      .build()
    );

    _socket!.connect();

    _socket!.onConnect((_) {
      print('[Socket] Conectado ao servidor: ${_socket!.id}');
    });

    _socket!.onDisconnect((_) {
      print('[Socket] Desconectado do servidor');
    });
  }

  void ficarOnline(String profissionalId) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('ficar_online', {'profissional_id': profissionalId});
    }
  }

  void desconectar() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket = null;
    }
  }
}
