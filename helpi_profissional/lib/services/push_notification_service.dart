// =============================================================
// HELPI — Push Notification Service (Firebase Cloud Messaging)
// Gerencia o ciclo de vida de push notifications no Flutter:
// - Permissões (Android 13+)
// - Token FCM (registo e refresh)
// - Handlers (foreground, background, app terminada)
//
// ARQUITECTURA:
// - Singleton para uso global
// - Background handler é top-level function (requisito do Firebase)
// - Foreground messages delegam para o callback do RadarScreen
// - Deduplicação com Socket.IO via chamado_id
// =============================================================

import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../core/network/app_client.dart';
import 'foreground_notification_service.dart';

/// Handler de mensagens em background — OBRIGATÓRIO ser top-level function.
/// Chamado quando a app está fechada ou em background.
/// Não pode aceder a UI, apenas processa dados.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] 📩 Background message recebida: ${message.messageId}');
  debugPrint('[FCM] Data: ${message.data}');
  // O sistema operativo já mostra a notification bar automaticamente.
  // Quando o utilizador toca, o onMessageOpenedApp é chamado.
}

class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Callback para quando chega um chamado com a app em foreground.
  /// Definido pelo RadarScreen para mostrar o bottom sheet de alerta.
  Function(Map<String, dynamic>)? onNovoChamadoForeground;

  /// Callback para quando chega uma atualização de chamado (app cliente).
  Function(Map<String, dynamic>)? onAtualizacaoChamadoForeground;

  /// IDs de chamados já recebidos via Socket.IO (para deduplicação).
  final Set<String> _chamadosJaRecebidos = {};

  /// Marca um chamado como já recebido (chamado pelo SocketService).
  void marcarChamadoRecebido(String chamadoId) {
    _chamadosJaRecebidos.add(chamadoId);
    // Limpa IDs antigos para não crescer indefinidamente
    if (_chamadosJaRecebidos.length > 100) {
      final lista = _chamadosJaRecebidos.toList();
      _chamadosJaRecebidos.clear();
      _chamadosJaRecebidos.addAll(lista.skip(50));
    }
  }

  /// Inicializa o serviço de push notifications.
  /// Deve ser chamado após o login do utilizador.
  Future<void> inicializar() async {
    // 1. Pedir permissão (Android 13+ e iOS)
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: true,
      badge: true,
      carPlay: false,
      criticalAlert: true, // Para emergências (iOS)
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('[FCM] ❌ Permissão de notificações NEGADA pelo utilizador');
      return;
    }

    debugPrint(
        '[FCM] ✅ Permissão de notificações: ${settings.authorizationStatus}');

    // 2. Obter e registar o token FCM
    await _registarToken();

    // 3. Escutar refresh de token (o Firebase pode rotar a qualquer momento)
    _messaging.onTokenRefresh.listen((novoToken) {
      debugPrint('[FCM] 🔄 Token FCM renovado');
      _enviarTokenParaBackend(novoToken);
    });

    // 4. Configurar handler de foreground
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 5. Configurar handler de quando o utilizador toca na notificação
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // 6. Verificar se a app foi aberta a partir de uma notificação
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('[FCM] 🚀 App aberta via notificação');
      _handleMessageOpenedApp(initialMessage);
    }

    debugPrint('[FCM] 🔔 Push Notification Service inicializado');
  }

  /// Obtém o token FCM e envia para o backend.
  Future<void> _registarToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        debugPrint('[FCM] Token obtido: ${token.substring(0, 30)}...');
        await _enviarTokenParaBackend(token);
      }
    } catch (e) {
      debugPrint('[FCM] ❌ Erro ao obter token FCM: $e');
    }
  }

  /// Envia o token FCM para o backend via PUT /profissionais/fcm-token.
  Future<void> _enviarTokenParaBackend(String token) async {
    try {
      final dio = ApiClient().dio;
      await dio.put('/profissionais/fcm-token', data: {
        'fcm_token': token,
      });
      debugPrint('[FCM] ✅ Token FCM registado no backend');
    } catch (e) {
      debugPrint('[FCM] ❌ Erro ao enviar token FCM ao backend: $e');
    }
  }

  /// Handler para mensagens recebidas com a app em FOREGROUND.
  /// O sistema NÃO mostra notificação automática neste caso.
  /// Delegamos para o callback do RadarScreen.
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('[FCM] 📩 Foreground message: ${message.data}');

    final data = message.data;
    final tipo = data['tipo'] ?? '';

    if (tipo == 'novo_chamado') {
      final chamadoId = data['chamado_id'] ?? '';

      // Deduplicação: se já recebemos via Socket.IO, ignorar
      if (_chamadosJaRecebidos.contains(chamadoId)) {
        debugPrint(
            '[FCM] ⏭️ Chamado $chamadoId já recebido via Socket.IO, ignorando push');
        return;
      }

      // Atualiza a notificação persistente do foreground service
      final categoria = data['categoria'] ?? 'Serviço';
      ForegroundNotificationService().atualizarParaNovoChamado(categoria);

      if (onNovoChamadoForeground != null) {
        onNovoChamadoForeground!(_converterDataParaMapa(data));
      }
    } else if (tipo == 'atualizacao_chamado') {
      if (onAtualizacaoChamadoForeground != null) {
        onAtualizacaoChamadoForeground!(Map<String, dynamic>.from(data));
      }
    }
  }

  /// Handler para quando o utilizador toca na notificação e abre a app.
  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('[FCM] 👆 Utilizador tocou na notificação: ${message.data}');
    // A navegação para o ecrã correto será tratada pelo RadarScreen
    // quando verificar o estado na próxima vez que o widget carregar.

    final data = message.data;
    final tipo = data['tipo'] ?? '';

    if (tipo == 'novo_chamado' && onNovoChamadoForeground != null) {
      final chamadoId = data['chamado_id'] ?? '';
      if (!_chamadosJaRecebidos.contains(chamadoId)) {
        onNovoChamadoForeground!(_converterDataParaMapa(data));
      }
    }
  }

  /// Converte o data payload do FCM (tudo strings) para o formato
  /// que o RadarScreen espera (com números).
  Map<String, dynamic> _converterDataParaMapa(Map<String, dynamic> data) {
    return {
      'chamado_id': data['chamado_id'] ?? '',
      'categoria': data['categoria'] ?? '',
      'descricao': data['descricao'] ?? '',
      'distancia_metros': int.tryParse(data['distancia_metros'] ?? '0') ?? 0,
      'valor_sugerido': double.tryParse(data['valor_sugerido'] ?? '0') ?? 0.0,
      'valor_estimado_min':
          double.tryParse(data['valor_estimado_min'] ?? '0') ?? 0.0,
      'valor_estimado_max':
          double.tryParse(data['valor_estimado_max'] ?? '0') ?? 0.0,
    };
  }

  /// Limpa o serviço (chamado no logout).
  Future<void> limpar() async {
    onNovoChamadoForeground = null;
    onAtualizacaoChamadoForeground = null;
    _chamadosJaRecebidos.clear();
  }
}
