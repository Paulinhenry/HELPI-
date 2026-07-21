// =============================================================
// HELPI Cliente — Push Notification Service (Firebase Cloud Messaging)
// Recebe notificações de atualização do chamado:
// - "O profissional aceitou!" (a_caminho)
// - "O profissional chegou!" (em_servico)
// - "Serviço finalizado!" (finalizado)
//
// Funciona mesmo com a app em background ou fechada.
// =============================================================

import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../network/app_client.dart';

/// Handler de mensagens em background — OBRIGATÓRIO ser top-level function.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM Cliente] 📩 Background message: ${message.messageId}');
  debugPrint('[FCM Cliente] Data: ${message.data}');
}

class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Callback para atualizações de chamado recebidas via push (foreground).
  Function(Map<String, dynamic>)? onAtualizacaoChamado;

  /// Inicializa o serviço de push notifications do cliente.
  Future<void> inicializar() async {
    // 1. Pedir permissão (Android 13+ e iOS)
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('[FCM Cliente] ❌ Permissão de notificações NEGADA');
      return;
    }

    debugPrint(
        '[FCM Cliente] ✅ Permissão: ${settings.authorizationStatus}');

    // 2. Obter e registar o token FCM
    await _registarToken();

    // 3. Escutar refresh de token
    _messaging.onTokenRefresh.listen((novoToken) {
      debugPrint('[FCM Cliente] 🔄 Token renovado');
      _enviarTokenParaBackend(novoToken);
    });

    // 4. Handler de foreground
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 5. Handler de toque na notificação
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // 6. Verificar se a app foi aberta via notificação
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('[FCM Cliente] 🚀 App aberta via notificação');
      _handleMessageOpenedApp(initialMessage);
    }

    debugPrint('[FCM Cliente] 🔔 Push Service inicializado');
  }

  Future<void> _registarToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        debugPrint('[FCM Cliente] Token: ${token.substring(0, 30)}...');
        await _enviarTokenParaBackend(token);
      }
    } catch (e) {
      debugPrint('[FCM Cliente] ❌ Erro ao obter token: $e');
    }
  }

  Future<void> _enviarTokenParaBackend(String token) async {
    try {
      final dio = ApiClient().dio;
      await dio.put('/profissionais/fcm-token', data: {
        'fcm_token': token,
      });
      debugPrint('[FCM Cliente] ✅ Token registado no backend');
    } catch (e) {
      debugPrint('[FCM Cliente] ❌ Erro ao enviar token: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('[FCM Cliente] 📩 Foreground: ${message.data}');

    final data = message.data;
    final tipo = data['tipo'] ?? '';

    if (tipo == 'atualizacao_chamado' && onAtualizacaoChamado != null) {
      onAtualizacaoChamado!(Map<String, dynamic>.from(data));
    }
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('[FCM Cliente] 👆 Toque na notificação: ${message.data}');

    final data = message.data;
    final tipo = data['tipo'] ?? '';

    if (tipo == 'atualizacao_chamado' && onAtualizacaoChamado != null) {
      onAtualizacaoChamado!(Map<String, dynamic>.from(data));
    }
  }

  Future<void> limpar() async {
    onAtualizacaoChamado = null;
  }
}
