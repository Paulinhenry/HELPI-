// =============================================================
// HELPI — Foreground Notification Service
// Gerencia a notificação persistente do profissional quando o
// app está minimizado. Usa flutter_foreground_task para manter
// um Android Foreground Service ativo.
//
// ESTADOS DA NOTIFICAÇÃO:
// 1. "🟢 Online — Aguardando chamados"
// 2. "🚨 Novo Chamado! — [categoria]"
// 3. "⚫ Offline — Radar desligado" (antes de parar)
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
        channelId: 'helpi_profissional_status',
        channelName: 'Status do Profissional',
        channelDescription:
            'Notificação persistente mostrando o status online do profissional',
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

  /// Inicializa e inicia o Foreground Service com notificação "Online".
  Future<void> iniciar() async {
    _ensureInitialized();

    // 1. Pedir permissão de notificação (obrigatório Android 13+)
    final NotificationPermission notifPerm =
        await FlutterForegroundTask.checkNotificationPermission();
    if (notifPerm != NotificationPermission.granted) {
      final NotificationPermission result =
          await FlutterForegroundTask.requestNotificationPermission();
      if (result != NotificationPermission.granted) {
        debugPrint(
            '[ForegroundService] ❌ Permissão de notificação negada');
        return;
      }
    }

    // 2. Verificar se já está rodando (evita ServiceAlreadyStartedException)
    final bool isRunning = await FlutterForegroundTask.isRunningService;
    if (isRunning) {
      debugPrint(
          '[ForegroundService] ⚠️ Serviço já está rodando, atualizando...');
      await restaurarStatusOnline();
      return;
    }

    // 3. Iniciar o serviço
    final ServiceRequestResult result =
        await FlutterForegroundTask.startService(
      notificationTitle: '🟢 Online',
      notificationText: 'Aguardando chamados na sua área',
      callback: foregroundTaskCallback,
    );

    if (result is ServiceRequestSuccess) {
      debugPrint('[ForegroundService] ✅ Serviço iniciado — Status: Online');
    } else if (result is ServiceRequestFailure) {
      debugPrint(
          '[ForegroundService] ❌ Erro ao iniciar serviço: ${result.error}');
    }
  }

  /// Para o Foreground Service e remove a notificação.
  Future<void> parar() async {
    final bool isRunning = await FlutterForegroundTask.isRunningService;
    if (!isRunning) {
      debugPrint('[ForegroundService] ⚠️ Serviço não está rodando');
      return;
    }

    final ServiceRequestResult result =
        await FlutterForegroundTask.stopService();

    if (result is ServiceRequestSuccess) {
      debugPrint('[ForegroundService] ⛔ Serviço parado');
    } else if (result is ServiceRequestFailure) {
      debugPrint(
          '[ForegroundService] ❌ Erro ao parar serviço: ${result.error}');
    }
  }

  /// Atualiza a notificação para mostrar que chegou um novo chamado.
  Future<void> atualizarParaNovoChamado(String categoria) async {
    final bool isRunning = await FlutterForegroundTask.isRunningService;
    if (!isRunning) return;

    await FlutterForegroundTask.updateService(
      notificationTitle: '🚨 Novo Chamado!',
      notificationText: categoria.isNotEmpty
          ? '$categoria — Toque para abrir'
          : 'Toque para ver os detalhes',
    );

    debugPrint(
        '[ForegroundService] 🚨 Notificação atualizada — Novo chamado: $categoria');
  }

  /// Restaura a notificação para o status "Online" (após aceitar/recusar chamado).
  Future<void> restaurarStatusOnline() async {
    final bool isRunning = await FlutterForegroundTask.isRunningService;
    if (!isRunning) return;

    await FlutterForegroundTask.updateService(
      notificationTitle: '🟢 Online',
      notificationText: 'Aguardando chamados na sua área',
    );

    debugPrint('[ForegroundService] 🟢 Notificação restaurada — Status: Online');
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
    // Pode ser usado futuramente para enviar localização periodicamente.
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    debugPrint('[ForegroundTask] onDestroy — Serviço em background terminado');
  }
}
