import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';

import '../../../core/services/location_service.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../services/chamado_service.dart';
import '../../../services/socket_service.dart';
import '../../avaliacoes/screens/avaliacao_screen.dart';

/// Tela de Mapa — App Profissional
/// Mostra rota em tempo real até o cliente + controles de serviço.
class MapaRotaScreen extends StatefulWidget {
  final String chamadoId;
  final double latitudeDestino;
  final double longitudeDestino;
  final String categoria;
  final String descricao;
  final String? clienteId;
  final double? valorEstimadoMin;
  final double? valorEstimadoMax;

  const MapaRotaScreen({
    super.key,
    required this.chamadoId,
    required this.latitudeDestino,
    required this.longitudeDestino,
    required this.categoria,
    required this.descricao,
    this.clienteId,
    this.valorEstimadoMin,
    this.valorEstimadoMax,
  });

  @override
  State<MapaRotaScreen> createState() => _MapaRotaScreenState();
}

class _MapaRotaScreenState extends State<MapaRotaScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final SocketService _socketService = SocketService();
  final ChamadoService _chamadoService = ChamadoService();

  LatLng? _posicaoAtual;
  List<LatLng> _pontosRota = [];
  String _distanciaTexto = '...';
  String _tempoTexto = '...';

  bool _carregandoRota = true;
  bool _registrandoChegada = false;
  bool _chegou = false;
  bool _finalizandoServico = false;

  Timer? _gpsTimer;

  // Animação de pulso no marker
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Animação de entrada do painel
  late AnimationController _panelController;
  late Animation<Offset> _panelSlideAnim;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _panelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _panelSlideAnim = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _panelController,
      curve: Curves.easeOutCubic,
    ));

    _inicializar();
  }

  Future<void> _inicializar() async {
    await _obterLocalizacao();
    await _buscarRota();
    _panelController.forward();

    _gpsTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _obterLocalizacao();
    });
  }

  Future<void> _obterLocalizacao() async {
    try {
      final position = await LocationService.obterLocalizacaoAtual();
      if (mounted) {
        setState(() {
          _posicaoAtual = LatLng(position.latitude, position.longitude);
        });

        if (widget.clienteId != null) {
          final profissionalId =
              context.read<AuthProvider>().profissionalId;
          if (profissionalId != null) {
            _socketService.emitirLocalizacao(
              profissionalId: profissionalId,
              clienteId: widget.clienteId!,
              latitude: position.latitude,
              longitude: position.longitude,
            );
          }
        }
      }
    } catch (e) {
      if (mounted && _posicaoAtual == null) {
        setState(() {
          _posicaoAtual = const LatLng(-23.550520, -46.633308);
        });
      }
    }
  }

  Future<void> _buscarRota() async {
    if (_posicaoAtual == null) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (_posicaoAtual == null) return;
    }

    try {
      final origem = _posicaoAtual!;
      final destino =
          LatLng(widget.latitudeDestino, widget.longitudeDestino);

      final url =
          'https://router.project-osrm.org/route/v1/driving/'
          '${origem.longitude},${origem.latitude};'
          '${destino.longitude},${destino.latitude}'
          '?overview=full&geometries=geojson';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final routes = data['routes'] as List;

        if (routes.isNotEmpty) {
          final route = routes[0];
          final coordinates = route['geometry']['coordinates'] as List;

          final pontos = coordinates
              .map<LatLng>(
                (coord) => LatLng(
                  (coord[1] as num).toDouble(),
                  (coord[0] as num).toDouble(),
                ),
              )
              .toList();

          final distancia = (route['distance'] as num).toDouble();
          final duracao = (route['duration'] as num).toDouble();

          if (mounted) {
            setState(() {
              _pontosRota = pontos;
              _distanciaTexto = _formatarDistancia(distancia);
              _tempoTexto = _formatarTempo(duracao);
              _carregandoRota = false;
            });
            _ajustarZoom(origem, destino);
          }
        }
      }
    } catch (e) {
      debugPrint('Erro ao buscar rota OSRM: $e');
      if (mounted) {
        setState(() => _carregandoRota = false);
        if (_posicaoAtual != null) {
          _ajustarZoom(
            _posicaoAtual!,
            LatLng(widget.latitudeDestino, widget.longitudeDestino),
          );
        }
      }
    }
  }

  void _ajustarZoom(LatLng origem, LatLng destino) {
    try {
      final bounds = LatLngBounds.fromPoints([origem, destino]);
      _mapController.fitCamera(
        CameraFit.bounds(
            bounds: bounds, padding: const EdgeInsets.all(90)),
      );
    } catch (e) {
      debugPrint('Erro ao ajustar zoom: $e');
    }
  }

  String _formatarDistancia(double metros) {
    if (metros >= 1000) {
      return '${(metros / 1000).toStringAsFixed(1)} km';
    }
    return '${metros.toInt()} m';
  }

  String _formatarTempo(double segundos) {
    final minutos = (segundos / 60).ceil();
    if (minutos >= 60) {
      final horas = minutos ~/ 60;
      final mins = minutos % 60;
      return '${horas}h ${mins}min';
    }
    return '$minutos min';
  }

  Future<void> _abrirNavegacaoExterna() async {
    final lat = widget.latitudeDestino;
    final lng = widget.longitudeDestino;
    final googleMapsUrl =
        Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    final googleMapsWeb = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');

    try {
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl);
      } else {
        await launchUrl(googleMapsWeb,
            mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Não foi possível abrir o app de navegação'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          ),
        );
      }
    }
  }

  Future<void> _registrarChegada() async {
    HapticFeedback.mediumImpact();
    setState(() => _registrandoChegada = true);

    try {
      await _chamadoService.registrarChegada(widget.chamadoId);

      if (mounted) {
        setState(() {
          _chegou = true;
          _registrandoChegada = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded,
                    color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Text('Chegada registada! Cliente notificado.',
                    style: GoogleFonts.inter(color: Colors.white)),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _registrandoChegada = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          ),
        );
      }
    }
  }

  void _abrirDialogoPreco() {
    final TextEditingController precoController =
        TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            decoration: BoxDecoration(
              color: AppColors.bg2,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.border),
            ),
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.payments_rounded,
                          color: AppColors.success, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Definir valor final',
                              style: AppTextStyles.h3),
                          Text('O serviço foi concluído.',
                              style: AppTextStyles.bodyS),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Estimate reference
                if (widget.valorEstimadoMin != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            color: AppColors.success, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Estimativa: R\$ ${widget.valorEstimadoMin} – R\$ ${widget.valorEstimadoMax}',
                          style: AppTextStyles.labelM
                              .copyWith(color: AppColors.success),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Price input
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.bg3,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'R\$',
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: precoController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          autofocus: true,
                          style: GoogleFonts.inter(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText: '0,00',
                            hintStyle: GoogleFonts.inter(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDisabled,
                            ),
                            border: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textTertiary,
                            side: const BorderSide(
                                color: AppColors.border, width: 1.5),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text('CANCELAR',
                              style: GoogleFonts.inter(
                                  fontSize: 13, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () {
                            final valorStr =
                                precoController.text.replaceAll(',', '.');
                            final valor = double.tryParse(valorStr);
                            if (valor == null || valor <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Insira um valor válido.'),
                                  backgroundColor: AppColors.error,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                ),
                              );
                              return;
                            }
                            Navigator.pop(context);
                            _finalizarServico(valor);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          child: Text('COBRAR AGORA',
                              style: GoogleFonts.inter(
                                  fontSize: 14, fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _finalizarServico(double valorCobrado) async {
    setState(() => _finalizandoServico = true);

    try {
      await _chamadoService.finalizarChamado(widget.chamadoId,
          valorCobrado: valorCobrado);

      if (mounted) {
        setState(() => _finalizandoServico = false);

        HapticFeedback.heavyImpact();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.celebration_rounded,
                    color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Text('Serviço finalizado! Excelente trabalho!',
                    style: GoogleFonts.inter(color: Colors.white)),
              ],
            ),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            duration: const Duration(seconds: 3),
          ),
        );

        context.read<AuthProvider>().limparChamadoAtivo();

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AvaliacaoScreen(
              chamadoId: widget.chamadoId,
              nomeCliente: 'o cliente',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _finalizandoServico = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao finalizar: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _gpsTimer?.cancel();
    _pulseController.dispose();
    _panelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final destinoLatLng =
        LatLng(widget.latitudeDestino, widget.longitudeDestino);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.bg0,
        body: Stack(
          children: [
            // ── MAPA ──────────────────────────────────────────────────
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _posicaoAtual ??
                    const LatLng(-23.550520, -46.633308),
                initialZoom: 14.0,
              ),
              children: [
                // Tile layer — dark style
                TileLayer(
                  urlTemplate:
                      'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.helpi.profissional',
                  retinaMode: RetinaMode.isHighDensity(context),
                  tileProvider: CancellableNetworkTileProvider(),
                  tileBuilder: (context, tileWidget, tile) {
                    return ColorFiltered(
                      colorFilter: const ColorFilter.mode(
                        Color(0xFF0B1120),
                        BlendMode.modulate,
                      ),
                      child: tileWidget,
                    );
                  },
                ),

                // Polyline da rota
                if (_pontosRota.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _pontosRota,
                        strokeWidth: 4.5,
                        color: AppColors.primary,
                        borderColor:
                            AppColors.primary.withValues(alpha: 0.3),
                        borderStrokeWidth: 10,
                      ),
                    ],
                  ),

                // Markers
                MarkerLayer(
                  markers: [
                    // Marker CLIENTE (destino)
                    Marker(
                      point: destinoLatLng,
                      width: 56,
                      height: 56,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppColors.error.withValues(alpha: 0.4),
                              width: 2),
                        ),
                        child: const Icon(
                          Icons.home_rounded,
                          color: AppColors.error,
                          size: 28,
                        ),
                      ),
                    ),

                    // Marker PROFISSIONAL (posição atual)
                    if (_posicaoAtual != null)
                      Marker(
                        point: _posicaoAtual!,
                        width: 56,
                        height: 56,
                        child: AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                // Pulse ring
                                Container(
                                  width: 56 * _pulseAnimation.value,
                                  height: 56 * _pulseAnimation.value,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.primary.withValues(
                                      alpha: 0.2 *
                                          (1 - _pulseAnimation.value),
                                    ),
                                    border: Border.all(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.4 *
                                            (1 - _pulseAnimation.value),
                                      ),
                                    ),
                                  ),
                                ),
                                // Core dot
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    gradient: AppColors.primaryGradient,
                                    shape: BoxShape.circle,
                                    boxShadow: AppColors.primaryGlowShadow,
                                  ),
                                  child: const Icon(
                                    Icons.navigation_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ],
            ),

            // ── TOP HEADER (Glassmorphism) ────────────────────────────
            _buildTopHeader(),

            // ── BOTTOM PANEL ─────────────────────────────────────────
            SlideTransition(
              position: _panelSlideAnim,
              child: Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildBottomPanel(),
              ),
            ),

            // ── LOADING OVERLAY ───────────────────────────────────────
            if (_carregandoRota)
              Positioned(
                top: MediaQuery.of(context).size.height * 0.45,
                left: 0,
                right: 0,
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.bg3.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary
                                    .withValues(alpha: 0.8),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text('A calcular rota...',
                                style: AppTextStyles.labelM),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── TOP HEADER ─────────────────────────────────────────────────────────────
  Widget _buildTopHeader() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.bg0.withValues(alpha: 0.92),
                  AppColors.bg0.withValues(alpha: 0.5),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                child: Row(
                  children: [
                    // Back button
                    _buildHeaderButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 12),
                    // Job info
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.bg3.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.work_rounded,
                                  color: Colors.white, size: 18),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.categoria.toUpperCase(),
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  Text(
                                    widget.descricao,
                                    style: AppTextStyles.labelM.copyWith(
                                        color: AppColors.textPrimary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // GPS button
                    _buildHeaderButton(
                      icon: Icons.navigation_rounded,
                      onTap: _abrirNavegacaoExterna,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderButton({
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.bg3.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(icon,
                color: color ?? AppColors.textSecondary, size: 20),
          ),
        ),
      ),
    );
  }

  // ─── BOTTOM PANEL ────────────────────────────────────────────────────────────
  Widget _buildBottomPanel() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                AppColors.bg0.withValues(alpha: 0.96),
                AppColors.bg0.withValues(alpha: 0.85),
                AppColors.bg0.withValues(alpha: 0.4),
                Colors.transparent,
              ],
              stops: const [0.0, 0.35, 0.65, 1.0],
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── ETA CARD ────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.bg2.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildEtaItem(
                            icon: Icons.straighten_rounded,
                            label: 'DISTÂNCIA',
                            value: _distanciaTexto,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 44,
                          color: AppColors.border,
                        ),
                        Expanded(
                          child: _buildEtaItem(
                            icon: Icons.timer_rounded,
                            label: 'CHEGADA',
                            value: _tempoTexto,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 44,
                          color: AppColors.border,
                        ),
                        Expanded(
                          child: _buildEtaItem(
                            icon: Icons.location_on_rounded,
                            label: 'STATUS',
                            value: _chegou ? 'No local' : 'Em rota',
                            valueColor: _chegou
                                ? AppColors.success
                                : AppColors.info,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── ACTION BUTTONS ───────────────────────────────────
                  Row(
                    children: [
                      // GPS button
                      _buildActionButton(
                        icon: Icons.directions_rounded,
                        label: 'ABRIR GPS',
                        isOutlined: true,
                        onTap: _abrirNavegacaoExterna,
                        flex: 1,
                      ),
                      const SizedBox(width: 10),
                      // Main action button
                      _buildMainActionButton(),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEtaItem({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: AppColors.textTertiary,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 4),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, anim) =>
              FadeTransition(opacity: anim, child: child),
          child: Text(
            value,
            key: ValueKey<String>(value),
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: valueColor ?? AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required bool isOutlined,
    required VoidCallback? onTap,
    int flex = 1,
  }) {
    return Expanded(
      flex: flex,
      child: SizedBox(
        height: 54,
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 18),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary, width: 1.5),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            textStyle: GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5),
          ),
        ),
      ),
    );
  }

  Widget _buildMainActionButton() {
    final isLoading = _registrandoChegada || _finalizandoServico;
    final isChegar = !_chegou;

    return Expanded(
      flex: 2,
      child: GestureDetector(
        onTap: isLoading
            ? null
            : (_chegou ? _abrirDialogoPreco : _registrarChegada),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: 54,
          decoration: BoxDecoration(
            gradient: isChegar
                ? AppColors.onlineGradient
                : AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: isChegar
                ? AppColors.onlineGlowShadow
                : AppColors.primaryGlowShadow,
          ),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _chegou
                            ? Icons.payments_rounded
                            : Icons.location_on_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _chegou ? 'FINALIZAR' : 'CHEGUEI!',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
