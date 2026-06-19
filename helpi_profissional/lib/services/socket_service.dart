import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:geolocator/geolocator.dart';
import '../core/config/env.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  io.Socket? _socket;

  Future<void> ligarRadar(String profissionalId, Function(Map<String, dynamic>) onAlertaTrabalho) async {
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
      print('[Radar] Conectado ao servidor! ID: ${_socket!.id}');
      
      double? lat;
      double? lng;
      
      // Tenta apanhar o GPS real se tiver permissão
      try {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
          Position position = await Geolocator.getCurrentPosition();
          lat = position.latitude;
          lng = position.longitude;
        }
      } catch (e) {
        print("Aviso: GPS não disponível: $e");
        // Em ambiente de testes, podemos passar um dummy de SP
        lat = -23.550520;
        lng = -46.633308;
      }

      // Emite o evento real com o GPS e ID do profissional para o Node.js
      _socket!.emit('ficar_online', {
        'profissional_id': profissionalId,
        'latitude': lat ?? -23.550520,
        'longitude': lng ?? -46.633308,
      });
    });

    // Ouve a sirene vinda do Node.js
    _socket!.on('novo_chamado_emergencia', (data) {
      print('[Radar] 🚨 NOVO CHAMADO RECEBIDO: $data');
      // Converte o objeto dinâmico do socket num mapa do Dart
      final Map<String, dynamic> mapaAviso = Map<String, dynamic>.from(data);
      onAlertaTrabalho(mapaAviso);
    });

    _socket!.onDisconnect((_) {
      print('[Radar] Desconectado do servidor');
    });
  }

  void desligarRadar() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket = null;
      print('[Radar] Radar desligado manualmente.');
    }
  }
}
