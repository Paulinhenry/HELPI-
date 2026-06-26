import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import '../core/config/env.dart';
import '../core/services/location_service.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  io.Socket? _socket;

  Future<void> ligarRadar(
    String profissionalId, 
    Function(Map<String, dynamic>) onAlertaTrabalho,
    {Function(Map<String, dynamic>)? onPagamentoConfirmado}
  ) async {
    if (_socket != null && _socket!.connected) return;

    // Obtém URL do Env (remove /api/v1 para os websockets)
    String serverUrl = Env.baseUrl.split('/api/v1').first;

    _socket = io.io(serverUrl, io.OptionBuilder()
      .setTransports(['websocket'])
      .disableAutoConnect()
      .build()
    );

    _socket!.connect();

    _socket!.onConnect((_) async {
      debugPrint('[Radar] Conectado ao servidor! ID: ${_socket!.id}');
      
      double? lat;
      double? lng;
      
      // Import do location_service.dart deverá estar no topo (vou garantir isto adicionando manualmente).
      // Tenta apanhar o GPS real se tiver permissão usando o LocationService igual ao do cliente
      try {
        Position position = await LocationService.obterLocalizacaoAtual();
        lat = position.latitude;
        lng = position.longitude;
      } catch (e) {
        debugPrint("Aviso: GPS não disponível: $e");
        // Em ambiente de testes, podemos passar um dummy de SP
        lat = -23.550520;
        lng = -46.633308;
      }

      // Emite o evento real com o GPS e ID do profissional para o Node.js
      _socket!.emit('ficar_online', {
        'profissional_id': profissionalId,
        'latitude': lat,
        'longitude': lng,
      });
    });

    // Ouve a sirene vinda do Node.js
    _socket!.on('novo_chamado_emergencia', (data) {
      debugPrint('[Radar] 🚨 NOVO CHAMADO RECEBIDO: $data');
      final Map<String, dynamic> mapaAviso = Map<String, dynamic>.from(data);
      onAlertaTrabalho(mapaAviso);
    });

    _socket!.on('pagamento_confirmado', (data) {
      debugPrint('[Radar] 💰 PAGAMENTO CONFIRMADO: $data');
      if (onPagamentoConfirmado != null) {
        onPagamentoConfirmado(Map<String, dynamic>.from(data));
      }
    });

    _socket!.onDisconnect((_) {
      debugPrint('[Radar] Desconectado do servidor');
    });
  }

  /// Emite a localização atual do profissional para o cliente via WebSocket.
  /// O backend retransmite apenas para a sala do cliente (cliente:${clienteId}).
  void emitirLocalizacao({
    required String profissionalId,
    required String clienteId,
    required double latitude,
    required double longitude,
  }) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('atualizar_localizacao', {
        'profissional_id': profissionalId,
        'cliente_id': clienteId,
        'latitude': latitude,
        'longitude': longitude,
      });
    }
  }

  void desligarRadar() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket = null;
      debugPrint('[Radar] Radar desligado manualmente.');
    }
  }
}
