import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/providers/auth_provider.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_text_styles.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/chamados/screens/mapa_rota_screen.dart';
import 'services/chamado_service.dart';
import 'services/socket_service.dart';
import 'features/pagamentos/screens/pagamento_confirmado_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.bg1,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  final authProvider = AuthProvider();
  await authProvider.checkLoginStatus();

  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider.value(value: authProvider)],
      child: const HelpiProfissionalApp(),
    ),
  );
}

class HelpiProfissionalApp extends StatelessWidget {
  const HelpiProfissionalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Helpi Profissional',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          if (auth.isAuthenticated) {
            if (auth.chamadoAtivo != null) {
              final c = auth.chamadoAtivo!;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                auth.limparChamadoAtivo();
              });
              return MapaRotaScreen(
                chamadoId: c['id'].toString(),
                latitudeDestino:
                    double.parse(c['latitude_destino'].toString()),
                longitudeDestino:
                    double.parse(c['longitude_destino'].toString()),
                categoria: c['categoria_solicitada'] ?? '',
                descricao: c['problema_descricao'] ?? '',
                clienteId: c['cliente_id']?.toString(),
              );
            }
            return RadarScreen(profissionalId: auth.profissionalId!);
          }
          return const LoginScreen();
        },
      ),
    );
  }
}

// ─── RADAR SCREEN ─────────────────────────────────────────────────────────────
class RadarScreen extends StatefulWidget {
  final String profissionalId;

  const RadarScreen({super.key, required this.profissionalId});

  @override
  State<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends State<RadarScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final SocketService _socketService = SocketService();
  bool _isOnline = false;
  int _chamadosHoje = 0;
  double _ganhosDia = 0.0;

  late AnimationController _radarController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _radarController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isOnline && mounted) {
      _socketService.ligarRadar(
        widget.profissionalId,
        _mostrarAlertaDeTrabalho,
        onPagamentoConfirmado: (dados) {},
      );
    }
  }

  void _toggleModoTrabalho() {
    HapticFeedback.heavyImpact();
    setState(() {
      _isOnline = !_isOnline;
      if (_isOnline) {
        _radarController.repeat();
      } else {
        _radarController.stop();
        _radarController.reset();
      }
    });

    if (_isOnline) {
      WakelockPlus.enable();
      _socketService.ligarRadar(
        widget.profissionalId,
        _mostrarAlertaDeTrabalho,
        onPagamentoConfirmado: (dados) {
          if (!mounted) return;
          final rawValor = dados['valor_cobrado'] ?? dados['valor'] ?? '0';
          final valor = double.tryParse(rawValor.toString()) ?? 0.0;
          setState(() => _ganhosDia += valor);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PagamentoConfirmadoScreen(valor: valor),
            ),
          );
        },
      );
    } else {
      WakelockPlus.disable();
      _socketService.desligarRadar();
    }
  }

  void _mostrarAlertaDeTrabalho(Map<String, dynamic> dados) async {
    // Feedback sensorial
    FlutterRingtonePlayer().playAlarm();
    HapticFeedback.heavyImpact();
    bool? hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      Vibration.vibrate(pattern: [0, 400, 200, 400, 200, 400]);
    }

    if (!mounted) return;

    final chamadoId = dados['chamado_id']?.toString() ?? '';

    // Premium bottom sheet em vez de AlertDialog
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (dialogContext) =>
          _buildAlertaSheet(dialogContext, dados, chamadoId),
    );
  }

  Widget _buildAlertaSheet(
    BuildContext dialogContext,
    Map<String, dynamic> dados,
    String chamadoId,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.warning.withValues(alpha: 0.15),
            blurRadius: 40,
            spreadRadius: 0,
            offset: const Offset(0, -8),
          ),
          ...AppColors.floatingShadow,
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header urgente
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.notifications_active_rounded,
                      color: AppColors.warning,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NOVO PEDIDO DE SERVIÇO',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.warning,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dados['categoria'] ?? 'Serviço',
                          style: AppTextStyles.h3,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Divider
              Container(height: 1, color: AppColors.border),
              const SizedBox(height: 16),

              // Job details
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.bg3,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _buildDetailRow(
                      icon: Icons.description_outlined,
                      label: 'Problema',
                      value: dados['descricao'] ?? '—',
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      icon: Icons.near_me_rounded,
                      label: 'Distância',
                      value: '${dados['distancia_metros'] ?? '?'}m',
                      valueColor: AppColors.info,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Earnings card
              if (dados['valor_estimado_min'] != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.payments_rounded,
                            color: AppColors.success, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Valor estimado',
                                style: AppTextStyles.labelXS),
                            const SizedBox(height: 2),
                            Text(
                              'R\$ ${dados['valor_estimado_min']} – R\$ ${dados['valor_estimado_max']}',
                              style: AppTextStyles.h4.copyWith(
                                  color: AppColors.success),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),

              // Action buttons
              Row(
                children: [
                  // Recusar
                  Expanded(
                    child: SizedBox(
                      height: 54,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        label: const Text('RECUSAR'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(
                              color: AppColors.error, width: 1.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          textStyle: GoogleFonts.inter(
                              fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        onPressed: () {
                          FlutterRingtonePlayer().stop();
                          Navigator.pop(dialogContext);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Aceitar
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 54,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check_rounded, size: 20),
                        label: const Text('ACEITAR PEDIDO'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          textStyle: GoogleFonts.inter(
                              fontSize: 14, fontWeight: FontWeight.w800),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          FlutterRingtonePlayer().stop();
                          Navigator.pop(dialogContext);

                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const SizedBox(
                                    width: 18, height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text('A aceitar chamado...',
                                      style: GoogleFonts.inter(
                                          color: Colors.white)),
                                ],
                              ),
                              backgroundColor: AppColors.primary,
                              duration: const Duration(seconds: 10),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            ),
                          );

                          try {
                            final chamadoService = ChamadoService();
                            final chamado =
                                await chamadoService.aceitarChamado(chamadoId);

                            if (!mounted) return;
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();

                            final finished = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MapaRotaScreen(
                                  chamadoId: chamado['id'].toString(),
                                  latitudeDestino: double.parse(
                                      chamado['latitude_destino'].toString()),
                                  longitudeDestino: double.parse(
                                      chamado['longitude_destino'].toString()),
                                  categoria:
                                      chamado['categoria_solicitada'] ??
                                          dados['categoria'] ??
                                          '',
                                  descricao:
                                      chamado['problema_descricao'] ??
                                          dados['descricao'] ??
                                          '',
                                  clienteId:
                                      chamado['cliente_id']?.toString(),
                                  valorEstimadoMin: dados[
                                              'valor_estimado_min'] !=
                                          null
                                      ? double.tryParse(dados[
                                              'valor_estimado_min']
                                          .toString())
                                      : null,
                                  valorEstimadoMax: dados[
                                              'valor_estimado_max'] !=
                                          null
                                      ? double.tryParse(dados[
                                              'valor_estimado_max']
                                          .toString())
                                      : null,
                                ),
                              ),
                            );

                            if (finished == true && mounted) {
                              setState(() => _chamadosHoje++);
                            }
                          } on ChamadoJaAceitoException catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context)
                                .hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('$e'),
                                backgroundColor: AppColors.warning,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                margin:
                                    const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              ),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context)
                                .hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Erro: $e'),
                                backgroundColor: AppColors.error,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                margin:
                                    const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.textTertiary, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.labelXS),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTextStyles.bodyM.copyWith(
                  color: valueColor ?? AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final nome = context.read<AuthProvider>().nome ?? 'Profissional';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.bg0,
        body: Container(
          decoration: const BoxDecoration(gradient: AppColors.bgGradient),
          child: SafeArea(
            child: Column(
              children: [
                // ── HEADER ──────────────────────────────────────────────
                _buildHeader(nome),
                const SizedBox(height: 16),

                // ── METRIC CARDS ─────────────────────────────────────────
                _buildMetricCards(),
                const SizedBox(height: 12),

                const Spacer(),

                // ── RADAR BUTTON ─────────────────────────────────────────
                _buildRadarButton(),

                const Spacer(),

                // ── STATUS BANNER ─────────────────────────────────────────
                _buildStatusBanner(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String nome) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppColors.primaryGlowShadow,
            ),
            child: const Icon(Icons.engineering_rounded,
                color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Olá, $nome!', style: AppTextStyles.h3),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: _isOnline ? AppColors.online : AppColors.offline,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isOnline
                            ? 'Disponível para chamados'
                            : 'Offline — radar desligado',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: _isOnline
                              ? AppColors.online
                              : AppColors.textTertiary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Logout
          GestureDetector(
            onTap: () {
              _socketService.desligarRadar();
              context.read<AuthProvider>().logout();
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.bg3,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.logout_rounded,
                  color: AppColors.textTertiary, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _buildMetricCard(
              icon: Icons.assignment_turned_in_rounded,
              iconColor: AppColors.warning,
              label: 'Chamados hoje',
              value: '$_chamadosHoje',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildMetricCard(
              icon: Icons.payments_rounded,
              iconColor: AppColors.success,
              label: 'Ganhos hoje',
              value: 'R\$ ${_ganhosDia.toStringAsFixed(2)}',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildMetricCard(
              icon: Icons.satellite_alt_rounded,
              iconColor: _isOnline ? AppColors.online : AppColors.offline,
              label: 'Status',
              value: _isOnline ? 'Online' : 'Offline',
              valueColor: _isOnline ? AppColors.online : AppColors.offline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(height: 10),
          Text(label, style: AppTextStyles.labelXS),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: valueColor ?? AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadarButton() {
    return GestureDetector(
      onTap: _toggleModoTrabalho,
      child: AnimatedBuilder(
        animation: _radarController,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Radar rings
              if (_isOnline)
                ...List.generate(3, (index) {
                  final delay = index * 0.33;
                  var progress = _radarController.value - delay;
                  if (progress < 0) progress += 1.0;
                  final opacity = (1.0 - progress).clamp(0.0, 1.0);
                  return Opacity(
                    opacity: opacity * 0.5,
                    child: Container(
                      width: 200 + (progress * 200),
                      height: 200 + (progress * 200),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.online,
                          width: 1.5,
                        ),
                        color: AppColors.online.withValues(
                          alpha: 0.04 * (1.0 - progress),
                        ),
                      ),
                    ),
                  );
                }),

              // Core button
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _isOnline
                      ? AppColors.onlineGradient
                      : const LinearGradient(
                          colors: [AppColors.bg2, AppColors.bg3],
                        ),
                  border: Border.all(
                    color: _isOnline
                        ? AppColors.online.withValues(alpha: 0.4)
                        : AppColors.border,
                    width: 2,
                  ),
                  boxShadow: _isOnline ? AppColors.onlineGlowShadow : AppColors.cardShadow,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.radar_rounded,
                      size: 52,
                      color: _isOnline
                          ? Colors.white
                          : AppColors.textTertiary,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _isOnline ? 'ONLINE' : 'OFFLINE',
                      style: GoogleFonts.inter(
                        color: _isOnline
                            ? Colors.white
                            : AppColors.textSecondary,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isOnline ? 'Toque para parar' : 'Toque para iniciar',
                      style: GoogleFonts.inter(
                        color: _isOnline
                            ? Colors.white.withValues(alpha: 0.7)
                            : AppColors.textDisabled,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.bg2,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _isOnline
                ? AppColors.online.withValues(alpha: 0.3)
                : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _isOnline
                    ? AppColors.online.withValues(alpha: 0.12)
                    : AppColors.bg3,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _isOnline
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_off_rounded,
                color: _isOnline ? AppColors.online : AppColors.textDisabled,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, anim) =>
                    FadeTransition(opacity: anim, child: child),
                child: Text(
                  _isOnline
                      ? 'Radar ativo! Você receberá alertas de chamados na sua área.'
                      : 'Radar inativo. Toque no botão para começar a receber chamados.',
                  key: ValueKey(_isOnline),
                  style: AppTextStyles.bodyS.copyWith(
                    color: _isOnline
                        ? AppColors.textSecondary
                        : AppColors.textDisabled,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
