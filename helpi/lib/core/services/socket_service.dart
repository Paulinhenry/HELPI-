import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter/foundation.dart';
import '../config/env.dart';

class SocketService {
  // Singleton pattern
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  io.Socket? _socket;

  io.Socket? get socket => _socket;
  bool get isConnected => _socket != null && _socket!.connected;

  /// Conecta ao servidor WebSocket e junta-se à sala do cliente
  void conectar(String clienteId) {
    if (_socket != null && _socket!.connected) return;

    // A URL do Env.baseUrl geralmente tem '/api/v1'. Precisamos apenas da raiz.
    String serverUrl = Env.baseUrl.split('/api/v1').first;

    _socket = io.io(serverUrl, io.OptionBuilder()
      .setTransports(['websocket'])
      .disableAutoConnect()
      .build()
    );

    _socket!.connect();

    _socket!.onConnect((_) {
      debugPrint('[Socket Cliente] Conectado ao servidor: ${_socket!.id}');
      // Junta-se à sala do cliente para receber notificações direcionadas
      _socket!.emit('entrar_sala_cliente', {'cliente_id': clienteId});
    });

    _socket!.onDisconnect((_) {
      debugPrint('[Socket Cliente] Desconectado do servidor');
    });
  }

  /// Escuta atualizações do chamado (profissional aceitou, chegou, finalizou)
  void ouvirAtualizacoesChamado(Function(Map<String, dynamic>) onAtualizacao) {
    if (_socket == null) return;

    // Remove listener antigo para evitar duplicação
    _socket!.off('atualizacao_chamado');

    _socket!.on('atualizacao_chamado', (data) {
      debugPrint('[Socket Cliente] 📩 Atualização recebida: $data');
      final Map<String, dynamic> mapa = Map<String, dynamic>.from(data);
      onAtualizacao(mapa);
    });
  }

  /// Para de escutar atualizações
  void pararDeOuvir() {
    _socket?.off('atualizacao_chamado');
  }

  /// Escuta a localização em tempo real do profissional
  void ouvirLocalizacaoProfissional(Function(Map<String, dynamic>) onLocalizacao) {
    if (_socket == null) return;
    _socket!.off('localizacao_profissional');
    _socket!.on('localizacao_profissional', (data) {
      final Map<String, dynamic> mapa = Map<String, dynamic>.from(data);
      onLocalizacao(mapa);
    });
  }

  void pararDeOuvirLocalizacao() {
    _socket?.off('localizacao_profissional');
  }

  void desconectar() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket = null;
    }
  }
}
