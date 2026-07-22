// =============================================================
// HELPI CLIENT — Foreground Notification Service
// Gerencia a notificação persistente do cliente quando o
// app está minimizado e há um chamado em andamento.
//
// ESTADOS DA NOTIFICAÇÃO:
// 1. "🔎 Procurando Profissional..."
// 2. "🚨 Profissional a caminho! — [Nome]"
// =============================================================

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class ForegroundNotificationService {
  static final ForegroundNotificationService _instance =
      ForegroundNotificationService._internal();
  factory ForegroundNotificationService() => _instance;
  ForegroundNotificationService._internal();

  bool _isInitialized = false;

  /// Inicializa a configuração do foreground task (chamado uma vez).
  void _ensureInitialized() {
    if (_isInitialized) return;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'helpi_cliente_status',
        channelName: 'Status do Chamado',
        channelDescription:
            'Notificação persistente mostrando o andamento do seu chamado',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );

    _isInitialized = true;
    debugPrint('[ForegroundService] ✅ Configuração inicializada');
  }

  /// Inicializa e inicia o Foreground Service com notificação "Procurando Profissional".
  Future<void> iniciarProcurando() async {
    if (kIsWeb) return;
    
    try {
      _ensureInitialized();

      // 1. Pedir permissão de notificação (obrigatório Android 13+)
      final NotificationPermission notifPerm =
          await FlutterForegroundTask.checkNotificationPermission();
      if (notifPerm != NotificationPermission.granted) {
        final NotificationPermission result =
            await FlutterForegroundTask.requestNotificationPermission();
        if (result != NotificationPermission.granted) {
          debugPrint('[ForegroundService] ❌ Permissão de notificação negada');
          return;
        }
      }

    // 2. Verificar se já está rodando
    final bool isRunning = await FlutterForegroundTask.isRunningService;
    if (isRunning) {
      debugPrint('[ForegroundService] ⚠️ Serviço já está rodando, atualizando...');
      await _atualizarParaProcurando();
      return;
    }

    // 3. Iniciar o serviço
    final ServiceRequestResult result = await FlutterForegroundTask.startService(
      notificationTitle: '🔎 Procurando Profissional',
      notificationText: 'A aguardar que um profissional aceite o pedido...',
      callback: foregroundTaskCallback,
    );

      if (result is ServiceRequestSuccess) {
        debugPrint('[ForegroundService] ✅ Serviço iniciado — Status: Procurando');
      } else if (result is ServiceRequestFailure) {
        debugPrint('[ForegroundService] ❌ Erro ao iniciar serviço: ${result.error}');
      }
    } catch (e) {
      debugPrint('[ForegroundService] ⚠️ Erro ao iniciar (teste?): $e');
    }
  }

  /// Para o Foreground Service e remove a notificação.
  Future<void> parar() async {
    if (kIsWeb) return;
    
    try {
      final bool isRunning = await FlutterForegroundTask.isRunningService;
    if (!isRunning) {
      debugPrint('[ForegroundService] ⚠️ Serviço não está rodando');
      return;
    }

    final ServiceRequestResult result = await FlutterForegroundTask.stopService();

      if (result is ServiceRequestSuccess) {
        debugPrint('[ForegroundService] ⛔ Serviço parado');
      } else if (result is ServiceRequestFailure) {
        debugPrint('[ForegroundService] ❌ Erro ao parar serviço: ${result.error}');
      }
    } catch (e) {
      debugPrint('[ForegroundService] ⚠️ Erro ao parar (teste?): $e');
    }
  }

  /// Atualiza a notificação para mostrar que o profissional está a caminho.
  Future<void> atualizarParaACaminho(String nomeProfissional) async {
    if (kIsWeb) return;

    try {
      final bool isRunning = await FlutterForegroundTask.isRunningService;
    if (!isRunning) {
      // Caso o serviço tenha morrido, podemos tentar iniciar novamente
      await iniciarProcurando(); 
    }

      await FlutterForegroundTask.updateService(
        notificationTitle: '🚨 Profissional a caminho!',
        notificationText: '$nomeProfissional está a caminho da sua morada.',
      );

      debugPrint('[ForegroundService] 🚨 Notificação atualizada — A Caminho: $nomeProfissional');
    } catch (e) {
      debugPrint('[ForegroundService] ⚠️ Erro ao atualizar (teste?): $e');
    }
  }

  /// Interno: Restaura para Procurando (útil se já estiver rodando).
  Future<void> _atualizarParaProcurando() async {
    if (kIsWeb) return;

    try {
      await FlutterForegroundTask.updateService(
        notificationTitle: '🔎 Procurando Profissional',
        notificationText: 'A aguardar que um profissional aceite o pedido...',
      );
    } catch (e) {
      debugPrint('[ForegroundService] ⚠️ Erro ao atualizar (teste?): $e');
    }
  }
}

// ─── TASK HANDLER (top-level) ──────────────────────────────────────
// O flutter_foreground_task exige um callback top-level.
// Este callback mantém o serviço vivo.

@pragma('vm:entry-point')
void foregroundTaskCallback() {
  FlutterForegroundTask.setTaskHandler(_HelpiTaskHandler());
}

class _HelpiTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('[ForegroundTask] onStart — Serviço em background ativo');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Heartbeat — mantém o serviço vivo.
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    debugPrint('[ForegroundTask] onDestroy — Serviço em background terminado');
  }
}
