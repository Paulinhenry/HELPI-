// =============================================================
// HELPI Profissional — Home Map Screen
// Padrão "Uber/Rappi": o mapa é a tela. Tudo o resto flutua por cima.
//
// Substitui a antiga RadarScreen (botão simples + mapa só depois).
// Aqui o GoogleMap ocupa 100% da tela desde o primeiro frame, com
// heatmap de surge pricing, dimming quando offline, e um bottom
// sheet animado que controla o estado ONLINE/OFFLINE.
// =============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/map_style.dart';
import '../../../core/services/location_service.dart';
import '../../../core/network/app_client.dart';
import '../../../services/socket_service.dart';
import '../../../services/chamado_service.dart';
import '../../../services/push_notification_service.dart';
import '../../../services/foreground_notification_service.dart';
import '../../chamados/screens/mapa_rota_screen.dart';
import '../../pagamentos/screens/pagamento_confirmado_screen.dart';

class HomeMapScreen extends StatefulWidget {
  final String profissionalId;
  const HomeMapScreen({super.key, required this.profissionalId});

  @override
  State<HomeMapScreen> createState() => _HomeMapScreenState();
}

class _HomeMapScreenState extends State<HomeMapScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // ─── Chaves e serviços ────────────────────────────────────────
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final SocketService _socketService = SocketService();
  final PushNotificationService _pushService = PushNotificationService();
  final ForegroundNotificationService _foregroundService =
      ForegroundNotificationService();
  final ChamadoService _chamadoService = ChamadoService();

  // ─── Mapa ─────────────────────────────────────────────────────
  GoogleMapController? _mapController;
  static const LatLng _fallbackPosition = LatLng(-23.550520, -46.633308);
  LatLng _currentPosition = _fallbackPosition;
  bool _localizacaoPronta = false;
  final Set<Circle> _heatCircles = {};

  // ─── Estado ───────────────────────────────────────────────────
  bool _isOnline = false;
  bool _isAlertShowing = false;
  int _chamadosHoje = 0;
  double _ganhosDia = 0.0;

  // ─── Timers ───────────────────────────────────────────────────
  Timer? _heatmapTimer;
  Timer? _gpsTimer;

  // ─── Animações ────────────────────────────────────────────────
  /// Ondas concêntricas do radar (repeat quando online)
  late final AnimationController _radarController;

  /// Slide-up do painel inferior na primeira abertura
  late final AnimationController _panelController;
  late final Animation<double> _panelCurve;

  // ─────────────────────────────────────────────────────────────
  // LIFECYCLE
  // ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _panelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _panelCurve = CurvedAnimation(
      parent: _panelController,
      curve: Curves.easeOutCubic,
    );
    _panelController.forward();

    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _obterLocalizacaoInicial();
    unawaited(_carregarDashboard());
    unawaited(_fetchHeatmap());
    _heatmapTimer =
        Timer.periodic(const Duration(seconds: 30), (_) => _fetchHeatmap());
    unawaited(_inicializarPush());
  }

  Future<void> _inicializarPush() async {
    await _pushService.inicializar();
    _pushService.onNovoChamadoForeground = _mostrarAlertaDeTrabalho;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _carregarDashboard();
      if (_isOnline && mounted) {
        _socketService.ligarRadar(
          widget.profissionalId,
          _mostrarAlertaDeTrabalho,
          onPagamentoConfirmado: (_) {},
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _heatmapTimer?.cancel();
    _gpsTimer?.cancel();
    _radarController.dispose();
    _panelController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // LOCALIZAÇÃO
  // ─────────────────────────────────────────────────────────────
  Future<void> _obterLocalizacaoInicial() async {
    try {
      final pos = await LocationService.obterLocalizacaoAtual();
      if (!mounted) return;
      setState(() {
        _currentPosition = LatLng(pos.latitude, pos.longitude);
        _localizacaoPronta = true;
      });
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_currentPosition, 15.5),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _localizacaoPronta = true);
    }
  }

  Future<void> _atualizarLocalizacaoContinua() async {
    try {
      final pos = await LocationService.obterLocalizacaoAtual();
      if (!mounted) return;
      setState(() => _currentPosition = LatLng(pos.latitude, pos.longitude));
    } catch (_) {
      // Silencioso — mantém a última posição conhecida
    }
  }

  // ─────────────────────────────────────────────────────────────
  // DADOS REMOTOS
  // ─────────────────────────────────────────────────────────────
  Future<void> _carregarDashboard() async {
    try {
      final response =
          await ApiClient().dio.get('/profissionais/dashboard/me');
      if (!mounted) return;
      setState(() {
        _chamadosHoje = response.data['chamados_hoje'] ?? 0;
        _ganhosDia = (response.data['ganhos_hoje'] ?? 0.0).toDouble();
      });
    } catch (e) {
      debugPrint('[HomeMap] Erro ao carregar dashboard: $e');
    }
  }

  Future<void> _fetchHeatmap() async {
    try {
      final response = await ApiClient().dio.get('/radar/heatmap');
      final zonas = (response.data['zonas'] as List?) ?? [];
      final novosCirculos = <Circle>{};

      for (final zona in zonas) {
        final lat = double.parse(zona['centro_lat'].toString());
        final lng = double.parse(zona['centro_lng'].toString());
        final raio = double.parse(zona['raio_metros'].toString());
        final mult = double.parse(zona['multiplicador'].toString());

        final bool altaDemanda = mult >= 1.3;
        final Color cor = altaDemanda
            ? AppColors.error.withValues(alpha: 0.32)
            : AppColors.warning.withValues(alpha: 0.26);

        novosCirculos.add(
          Circle(
            circleId: CircleId('zona_${lat}_$lng'),
            center: LatLng(lat, lng),
            radius: raio,
            fillColor: cor,
            strokeColor: cor.withValues(alpha: 0.9),
            strokeWidth: 2,
            consumeTapEvents: false,
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _heatCircles
          ..clear()
          ..addAll(novosCirculos);
      });
    } catch (e) {
      debugPrint('[HomeMap] Erro ao buscar heatmap: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // TOGGLE ONLINE / OFFLINE
  // ─────────────────────────────────────────────────────────────
  void _toggleModoTrabalho() {
    HapticFeedback.heavyImpact();
    setState(() => _isOnline = !_isOnline);

    if (_isOnline) {
      _radarController.repeat();
      WakelockPlus.enable();
      _foregroundService.iniciar();

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

      _gpsTimer = Timer.periodic(
        const Duration(seconds: 8),
        (_) => _atualizarLocalizacaoContinua(),
      );
    } else {
      _radarController.stop();
      _radarController.reset();
      WakelockPlus.disable();
      _foregroundService.parar();
      _socketService.desligarRadar();
      _gpsTimer?.cancel();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // ALERTA DE NOVO CHAMADO
  // ─────────────────────────────────────────────────────────────
  void _mostrarAlertaDeTrabalho(Map<String, dynamic> dados) async {
    final chamadoId = dados['chamado_id']?.toString() ?? '';
    _pushService.marcarChamadoRecebido(chamadoId);

    final categoria = dados['categoria']?.toString() ?? 'Serviço';
    _foregroundService.atualizarParaNovoChamado(categoria);

    if (!mounted || _isAlertShowing) return;
    setState(() => _isAlertShowing = true);

    FlutterRingtonePlayer().playAlarm();
    HapticFeedback.heavyImpact();
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      Vibration.vibrate(pattern: [0, 400, 200, 400, 200, 400]);
    }

    if (!mounted) {
      _isAlertShowing = false;
      return;
    }

    await showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (dialogContext) =>
          _buildAlertaSheet(dialogContext, dados, chamadoId),
    );

    if (mounted) {
      setState(() => _isAlertShowing = false);
      _foregroundService.restaurarStatusOnline();
    }
  }

  Future<void> _aceitarChamado(
    BuildContext dialogContext,
    Map<String, dynamic> dados,
    String chamadoId,
  ) async {
    FlutterRingtonePlayer().stop();
    Navigator.pop(dialogContext);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text('A aceitar chamado...',
                style: GoogleFonts.inter(color: Colors.white)),
          ],
        ),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 10),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );

    try {
      final chamado = await _chamadoService.aceitarChamado(chamadoId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      final finished = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MapaRotaScreen(
            chamadoId: chamado['id'].toString(),
            latitudeDestino:
                double.parse(chamado['latitude_destino'].toString()),
            longitudeDestino:
                double.parse(chamado['longitude_destino'].toString()),
            categoria:
                chamado['categoria_solicitada'] ?? dados['categoria'] ?? '',
            descricao:
                chamado['problema_descricao'] ?? dados['descricao'] ?? '',
            clienteId: chamado['cliente_id']?.toString(),
            nomeCliente: chamado['cliente_nome']?.toString(),
            valorEstimadoMin: dados['valor_estimado_min'] != null
                ? double.tryParse(dados['valor_estimado_min'].toString())
                : null,
            valorEstimadoMax: dados['valor_estimado_max'] != null
                ? double.tryParse(dados['valor_estimado_max'].toString())
                : null,
          ),
        ),
      );

      if (finished == true && mounted) {
        setState(() => _chamadosHoje++);
      }
    } on ChamadoJaAceitoException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD PRINCIPAL
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final nome = context.read<AuthProvider>().nome ?? 'Profissional';

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.bg0,
      extendBodyBehindAppBar: true,
      drawer: _buildDrawer(nome),
      body: Stack(
        children: [
          // ── 1. MAPA — fundo absoluto ──────────────────────────
          Positioned.fill(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 500),
              opacity: _localizacaoPronta ? 1.0 : 0.0,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _currentPosition,
                  zoom: 15.5,
                ),
                style: kMapStyleDarkPremium,
                circles: _heatCircles,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                compassEnabled: false,
                // Deixa espaço para a top bar e o painel inferior
                padding: const EdgeInsets.only(bottom: 260, top: 90),
                onMapCreated: (controller) => _mapController = controller,
              ),
            ),
          ),

          // ── 2. DIMMING de "offline" ───────────────────────────
          // Container preto semitransparente por cima do mapa.
          // Não usa ColorFiltered (instável em PlatformView no Android).
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 450),
                opacity: _isOnline ? 0.0 : 0.55,
                child: Container(color: AppColors.bg0),
              ),
            ),
          ),

          // ── 3. LOADING enquanto o GPS ainda não chegou ─────────
          if (!_localizacaoPronta)
            const Positioned.fill(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),

          // ── 4. BARRA SUPERIOR ─────────────────────────────────
          _buildTopBar(nome),

          // ── 5. BOTÃO DE RECENTRAR ─────────────────────────────
          _buildRecenterButton(),

          // ── 6. PAINEL INFERIOR ────────────────────────────────
          _buildBottomPanel(),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // DRAWER LATERAL
  // ─────────────────────────────────────────────────────────────
  Widget _buildDrawer(String nome) {
    return Drawer(
      backgroundColor: AppColors.bg1,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.engineering_rounded,
                        color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      nome,
                      style: AppTextStyles.h3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.border, height: 1),
            _drawerTile(Icons.receipt_long_rounded, 'Histórico de Chamados'),
            _drawerTile(Icons.account_balance_wallet_rounded, 'Carteira'),
            _drawerTile(Icons.star_rounded, 'Minhas Avaliações'),
            _drawerTile(Icons.settings_rounded, 'Configurações'),
            const Spacer(),
            const Divider(color: AppColors.border, height: 1),
            _drawerTile(
              Icons.logout_rounded,
              'Terminar sessão',
              color: AppColors.error,
              onTap: () {
                _socketService.desligarRadar();
                context.read<AuthProvider>().logout();
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _drawerTile(
    IconData icon,
    String label, {
    Color? color,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppColors.textSecondary),
      title: Text(label, style: AppTextStyles.bodyL.copyWith(color: color)),
      onTap: onTap ?? () => Navigator.pop(context),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // BARRA SUPERIOR FLUTUANTE
  // ─────────────────────────────────────────────────────────────
  Widget _buildTopBar(String nome) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              _glassButton(
                icon: Icons.menu_rounded,
                onTap: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              const Spacer(),
              _statusPill(),
              const SizedBox(width: 10),
              _saldoBadge(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusPill() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bg2.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isOnline
              ? AppColors.online.withValues(alpha: 0.4)
              : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isOnline ? AppColors.online : AppColors.offline,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            _isOnline ? 'ONLINE' : 'OFFLINE',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: _isOnline ? AppColors.online : AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _saldoBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bg2.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.payments_rounded,
              color: AppColors.success, size: 16),
          const SizedBox(width: 6),
          Text(
            'R\$ ${_ganhosDia.toStringAsFixed(2)}',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: AppColors.bg2.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: AppColors.cardShadow,
        ),
        child: Icon(icon, color: AppColors.textPrimary, size: 22),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // BOTÃO DE RECENTRAR
  // ─────────────────────────────────────────────────────────────
  Widget _buildRecenterButton() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      right: 16,
      // Sobe um pouco quando online para não cobrir o painel maior
      bottom: _isOnline ? 300 : 260,
      child: GestureDetector(
        onTap: () => _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(_currentPosition, 16),
        ),
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.bg2.withValues(alpha: 0.9),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border),
            boxShadow: AppColors.cardShadow,
          ),
          child: const Icon(Icons.my_location_rounded,
              color: AppColors.primary, size: 20),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // PAINEL INFERIOR ANIMADO
  // ─────────────────────────────────────────────────────────────
  Widget _buildBottomPanel() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(_panelCurve),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
          decoration: BoxDecoration(
            color: AppColors.bg1,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: AppColors.border),
            boxShadow: AppColors.floatingShadow,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle visual
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 18),
                // Transição suave entre painel offline e online
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SizeTransition(sizeFactor: anim, child: child),
                  ),
                  child: _isOnline
                      ? _buildPainelOnline()
                      : _buildPainelOffline(),
                ),
                const SizedBox(height: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPainelOffline() {
    return Column(
      key: const ValueKey('offline'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _buildMetricChip(
              icon: Icons.assignment_turned_in_rounded,
              label: '$_chamadosHoje chamados hoje',
            ),
            const SizedBox(width: 10),
            _buildMetricChip(
              icon: Icons.wb_twilight_rounded,
              label: 'Radar desligado',
              color: AppColors.offline,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Você está offline', style: AppTextStyles.h2),
        const SizedBox(height: 4),
        Text(
          'Toque no botão para começar a receber chamados na sua área.',
          style: AppTextStyles.bodyM,
        ),
        const SizedBox(height: 18),
        _buildToggleButton(),
      ],
    );
  }

  Widget _buildPainelOnline() {
    return Column(
      key: const ValueKey('online'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _buildRadarIcon(),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Radar ativo', style: AppTextStyles.h3),
                  const SizedBox(height: 2),
                  Text(
                    'Procurando chamados na sua área...',
                    style: AppTextStyles.bodyS,
                  ),
                ],
              ),
            ),
            _buildMetricChip(
              icon: Icons.payments_rounded,
              label: 'R\$ ${_ganhosDia.toStringAsFixed(0)}',
              color: AppColors.success,
            ),
          ],
        ),
        const SizedBox(height: 18),
        _buildToggleButton(),
      ],
    );
  }

  Widget _buildMetricChip({
    required IconData icon,
    required String label,
    Color? color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.bg3,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color ?? AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.labelS.copyWith(color: color),
          ),
        ],
      ),
    );
  }

  /// Ícone animado com ondas concêntricas — pulsa enquanto o radar está ativo.
  Widget _buildRadarIcon() {
    return SizedBox(
      width: 44,
      height: 44,
      child: AnimatedBuilder(
        animation: _radarController,
        builder: (context, _) {
          final rings = List.generate(2, (index) {
            final delay = index * 0.5;
            var progress = _radarController.value - delay;
            if (progress < 0) progress += 1.0;
            final opacity = (1.0 - progress).clamp(0.0, 1.0);
            return Opacity(
              opacity: opacity * 0.6,
              child: Container(
                width: 44 * progress + 22,
                height: 44 * progress + 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.online, width: 1.5),
                ),
              ),
            );
          });

          return Stack(
            alignment: Alignment.center,
            children: [
              ...rings,
              Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.onlineGradient,
                ),
                child: const Icon(Icons.radar_rounded,
                    color: Colors.white, size: 14),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Botão principal ONLINE / OFFLINE.
  /// Verde com glow quando offline (convida à ação), vermelho quando ativo.
  Widget _buildToggleButton() {
    return GestureDetector(
      onTap: _toggleModoTrabalho,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        height: 62,
        decoration: BoxDecoration(
          gradient: _isOnline
              ? const LinearGradient(
                  colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
                )
              : AppColors.onlineGradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: _isOnline
              ? [
                  BoxShadow(
                    color: AppColors.error.withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ]
              : AppColors.onlineGlowShadow,
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isOnline
                    ? Icons.pause_circle_filled_rounded
                    : Icons.play_circle_fill_rounded,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 10),
              Text(
                _isOnline ? 'FICAR OFFLINE' : 'FICAR ONLINE',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SHEET DE ALERTA (NOVO CHAMADO)
  // ─────────────────────────────────────────────────────────────
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
            offset: const Offset(0, -8),
          ),
          ...AppColors.floatingShadow,
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Cabeçalho
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
              Container(height: 1, color: AppColors.border),
              const SizedBox(height: 16),

              // Detalhes do chamado
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.bg3,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _linhaDetalhe(
                      icon: Icons.description_outlined,
                      label: 'Problema',
                      value: dados['descricao'] ?? '---',
                    ),
                    const SizedBox(height: 12),
                    _linhaDetalhe(
                      icon: Icons.near_me_rounded,
                      label: 'Distância',
                      value: '${dados['distancia_metros'] ?? '?'}m',
                      valueColor: AppColors.info,
                    ),
                  ],
                ),
              ),

              // Valor estimado (opcional)
              if (dados['valor_estimado_min'] != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.25)),
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
                              style: AppTextStyles.h4
                                  .copyWith(color: AppColors.success),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // Botões RECUSAR / ACEITAR
              Row(
                children: [
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
                        onPressed: () =>
                            _aceitarChamado(dialogContext, dados, chamadoId),
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

  Widget _linhaDetalhe({
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
}
