import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart' hide Marker;
import 'package:google_fonts/google_fonts.dart';

import '../../../core/services/socket_service.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/map_style.dart';
import '../../../core/config/env.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../providers/chamados_provider.dart';
import '../../pagamentos/screens/checkout_screen.dart';
import 'chat_screen.dart';

class MapaScreen extends StatelessWidget {
  const MapaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ChamadosProvider()..inicializar(),
      child: const MapaScreenView(),
    );
  }
}

class MapaScreenView extends StatefulWidget {
  const MapaScreenView({super.key});

  @override
  State<MapaScreenView> createState() => _MapaScreenViewState();
}

class _MapaScreenViewState extends State<MapaScreenView>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  GoogleMapController? mapController;
  final TextEditingController _descricaoController =
      TextEditingController(text: "Emergência urgente solicitada via Helpi App");

  // Bottom Sheet controller — fix para o bug de ficar preso
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  // Animações
  late AnimationController _pulseController;

  late AnimationController _btnController;
  late Animation<double> _btnScaleAnim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Pulse para marcadores no mapa (controller usado para feedback visual futuro)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Scale para o botão CTA
    _btnController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _btnScaleAnim = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _btnController, curve: Curves.easeInOut),
    );

    Future.microtask(() {
      if (!mounted) return;
      final authProvider = context.read<AuthProvider>();
      if (authProvider.userId != null) {
        SocketService().conectar(authProvider.userId!);
      }

      final chamadosProvider = context.read<ChamadosProvider>();

      chamadosProvider.onTimeout = () {
        if (!mounted) return;
        showModalBottomSheet(
          context: context,
          isDismissible: false,
          enableDrag: false,
          backgroundColor: AppColors.bg2,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          builder: (context) => _buildNaoEncontradoSheet(chamadosProvider),
        );
      };

      chamadosProvider.onSuccess = (data) {
        if (!mounted) return;
        showModalBottomSheet(
          context: context,
          isDismissible: false,
          enableDrag: false,
          backgroundColor: AppColors.bg2,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          builder: (context) => _buildSucessoSheet(
            chamadosProvider,
            nome: data['profissional_nome'] ?? 'O Profissional',
            distancia: data['distancia_texto'] ?? 'a caminho',
          ),
        );
      };

      chamadosProvider.onError = (erro) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(erro),
            backgroundColor: AppColors.error,
          ),
        );
      };

      chamadosProvider.onServicoFinalizado = (data) {
        if (!mounted) return;
        Navigator.popUntil(context, (route) => route.isFirst);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChangeNotifierProvider.value(
              value: chamadosProvider,
              child: CheckoutScreen(data: data),
            ),
          ),
        );
      };

      chamadosProvider.addListener(_onProviderUpdate);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    mapController?.dispose();
    _descricaoController.dispose();
    _sheetController.dispose();
    _pulseController.dispose();
    _btnController.dispose();
    SocketService().desconectar();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (mounted) {
        final provider = context.read<ChamadosProvider>();
        provider.sincronizarEstadoServidor();
        final authProvider = context.read<AuthProvider>();
        if (authProvider.userId != null) {
          SocketService().conectar(authProvider.userId!);
        }
      }
    }
  }

  void _onProviderUpdate() {
    if (!mounted) return;
    final provider = context.read<ChamadosProvider>();
    if (provider.isProfissionalACaminho && provider.posicaoProfissional != null) {
      _ajustarCameraParaAmbos(provider);
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  void _ajustarCameraParaAmbos(ChamadosProvider provider) {
    if (mapController == null ||
        provider.posicaoAtual == null ||
        provider.posicaoProfissional == null) {
      return;
    }

    final p1 = LatLng(
        provider.posicaoAtual!.latitude, provider.posicaoAtual!.longitude);
    final p2 = LatLng(provider.posicaoProfissional!.latitude,
        provider.posicaoProfissional!.longitude);

    LatLngBounds bounds;
    if (p1.latitude > p2.latitude && p1.longitude > p2.longitude) {
      bounds = LatLngBounds(southwest: p2, northeast: p1);
    } else if (p1.longitude > p2.longitude) {
      bounds = LatLngBounds(
          southwest: LatLng(p1.latitude, p2.longitude),
          northeast: LatLng(p2.latitude, p1.longitude));
    } else if (p1.latitude > p2.latitude) {
      bounds = LatLngBounds(
          southwest: LatLng(p2.latitude, p1.longitude),
          northeast: LatLng(p1.latitude, p2.longitude));
    } else {
      bounds = LatLngBounds(southwest: p1, northeast: p2);
    }
    mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 90.0));
  }

  Set<Marker> _getMarkers(ChamadosProvider provider) {
    final Set<Marker> markers = {};
    if (provider.posicaoAtual != null) {
      markers.add(Marker(
        markerId: const MarkerId('cliente'),
        position: LatLng(
            provider.posicaoAtual!.latitude, provider.posicaoAtual!.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(210), // azul premium
        anchor: const Offset(0.5, 1.0),
      ));
    }
    if (provider.isProfissionalACaminho &&
        provider.posicaoProfissional != null) {
      markers.add(Marker(
        markerId: const MarkerId('profissional'),
        position: LatLng(provider.posicaoProfissional!.latitude,
            provider.posicaoProfissional!.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(140), // verde
        anchor: const Offset(0.5, 1.0),
      ));
    }
    return markers;
  }

  String _formatarTempo(int segundos) {
    final minutos = segundos ~/ 60;
    final restante = segundos % 60;
    return '${minutos.toString().padLeft(2, '0')}:${restante.toString().padLeft(2, '0')}';
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'electrical_services':
        return Icons.electrical_services_rounded;
      case 'plumbing':
        return Icons.plumbing_rounded;
      case 'key':
        return Icons.key_rounded;
      case 'cleaning_services':
        return Icons.cleaning_services_rounded;
      case 'handyman':
        return Icons.handyman_rounded;
      default:
        return Icons.build_rounded;
    }
  }

  Color _getCategoryColor(String iconName) {
    switch (iconName) {
      case 'electrical_services':
        return AppColors.catElectric;
      case 'plumbing':
        return AppColors.catPlumbing;
      case 'key':
        return AppColors.catKey;
      case 'cleaning_services':
        return AppColors.catCleaning;
      case 'handyman':
        return AppColors.catHandyman;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChamadosProvider>();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.bg0,
        extendBodyBehindAppBar: true,
        body: provider.carregando
            ? _buildLoadingState()
            : provider.posicaoAtual == null
                ? _buildLocationError()
                : Stack(
                    children: [
                      // ── MAPA ──────────────────────────────────────────
                      GoogleMap(
                        onMapCreated: _onMapCreated,
                        style: MapStyle.darkStyle,
                        initialCameraPosition: CameraPosition(
                          target: LatLng(provider.posicaoAtual!.latitude,
                              provider.posicaoAtual!.longitude),
                          zoom: 16.5,
                        ),
                        markers: _getMarkers(provider),
                        myLocationEnabled: !provider.isProfissionalACaminho,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                        mapToolbarEnabled: false,
                        compassEnabled: false,
                      ),

                      // ── TOP OVERLAY (Glassmorphism Header) ──────────
                      _buildTopHeader(provider),

                      // ── FLOATING ACTION BUTTONS ──────────────────────
                      if (!provider.isProfissionalACaminho &&
                          !provider.isProcurando)
                        _buildFloatingActions(),

                      // ── BOTTOM PANELS ─────────────────────────────────
                      if (provider.isProfissionalACaminho)
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 400),
                            transitionBuilder:
                                (Widget child, Animation<double> animation) {
                              return SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 1),
                                  end: Offset.zero,
                                ).animate(CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeOutCubic,
                                )),
                                child: child,
                              );
                            },
                            child: _buildTrackingPanel(provider),
                          ),
                        )
                      else if (provider.isProcurando)
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 400),
                            transitionBuilder:
                                (Widget child, Animation<double> animation) {
                              return SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 1),
                                  end: Offset.zero,
                                ).animate(CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeOutCubic,
                                )),
                                child: child,
                              );
                            },
                            child: _buildBuscandoPanel(provider),
                          ),
                        )
                      else
                      // ── DRAGGABLE SHEET (FIX COMPLETO) ──────────────
                        NotificationListener<ScrollNotification>(
                          onNotification: (_) => false,
                          child: DraggableScrollableSheet(
                            controller: _sheetController,
                            initialChildSize: 0.45,
                            minChildSize: 0.15,
                            maxChildSize: 0.78,
                            snap: true,
                            snapSizes: const [0.15, 0.45, 0.78],
                            snapAnimationDuration:
                                const Duration(milliseconds: 320),
                            builder:
                                (context, scrollController) {
                              return _buildSolicitacaoSheet(
                                  provider, scrollController);
                            },
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }

  // ─── LOADING STATE ─────────────────────────────────────────────────────────
  Widget _buildLoadingState() {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.bgGradient),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(22),
                boxShadow: AppColors.primaryGlowShadow,
              ),
              child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primary.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            Text('A obter localização...', style: AppTextStyles.bodyM),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationError() {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.bgGradient),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.location_off_rounded,
                    color: AppColors.error, size: 40),
              ),
              const SizedBox(height: 20),
              Text('Localização não disponível', style: AppTextStyles.h2),
              const SizedBox(height: 8),
              Text(
                'Verifique as permissões de localização do dispositivo.',
                style: AppTextStyles.bodyM,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── TOP HEADER (Glassmorphism) ────────────────────────────────────────────
  Widget _buildTopHeader(ChamadosProvider provider) {
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
                  AppColors.bg0.withValues(alpha: 0.85),
                  AppColors.bg0.withValues(alpha: 0.4),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    // Logo badge
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: AppColors.primaryGlowShadow,
                      ),
                      child: const Icon(Icons.bolt_rounded,
                          color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'HELPI',
                            style: GoogleFonts.inter(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 2.5,
                            ),
                          ),
                          Text(
                            provider.isProfissionalACaminho
                                ? 'Profissional a caminho'
                                : provider.isProcurando
                                    ? 'Procurando especialista...'
                                    : 'Pronto para ajudar',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: provider.isProfissionalACaminho
                                  ? AppColors.success
                                  : provider.isProcurando
                                      ? AppColors.warning
                                      : AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Logout button
                    _buildGlassButton(
                      icon: Icons.logout_rounded,
                      onTap: () => context.read<AuthProvider>().logout(),
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

  Widget _buildGlassButton({
    required IconData icon,
    required VoidCallback onTap,
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
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
            child: Icon(icon, color: Colors.white70, size: 20),
          ),
        ),
      ),
    );
  }

  // ─── FLOATING ACTION BUTTONS ───────────────────────────────────────────────
  Widget _buildFloatingActions() {
    return Positioned(
      right: 16,
      bottom: MediaQuery.of(context).size.height * 0.48,
      child: Column(
        children: [
          _buildFAB(
            icon: Icons.my_location_rounded,
            onTap: () {
              final provider = context.read<ChamadosProvider>();
              if (provider.posicaoAtual != null && mapController != null) {
                mapController!.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(
                      target: LatLng(provider.posicaoAtual!.latitude,
                          provider.posicaoAtual!.longitude),
                      zoom: 16.5,
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFAB({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.bg3.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
              boxShadow: AppColors.cardShadow,
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
        ),
      ),
    );
  }

  // ─── SOLICITAÇÃO SHEET (FIX BOTTOM SHEET) ─────────────────────────────────
  Widget _buildSolicitacaoSheet(
      ChamadosProvider provider, ScrollController scrollController) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: AppColors.floatingShadow,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Column(
        children: [
          // ── DRAG HANDLE (não scroll) ────────────────────────────────
          GestureDetector(
            onVerticalDragUpdate: (details) {
              // Força o DraggableScrollableSheet a reagir ao drag
              // mesmo quando o scroll está no topo
            },
            child: Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
          // ── SCROLLABLE CONTENT ──────────────────────────────────────
          Expanded(
            child: CustomScrollView(
              controller: scrollController,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 8),

                        // ── LOCATION CARD ─────────────────────────────
                        _buildLocationCard(provider),
                        const SizedBox(height: 20),

                        // ── CATEGORIES SECTION ────────────────────────
                        Row(
                          children: [
                            Text('Serviços', style: AppTextStyles.h4),
                            const Spacer(),
                            if (provider.categorias.isNotEmpty)
                              Text(
                                '${provider.categorias.length} disponíveis',
                                style: AppTextStyles.labelS.copyWith(
                                  color: AppColors.primary,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildCategoriasGrid(provider),
                        const SizedBox(height: 20),

                        // ── DESCRIPTION FIELD ─────────────────────────
                        _buildDescriptionField(provider),
                        const SizedBox(height: 16),

                        // ── ESTIMATE CARD ─────────────────────────────
                        if (provider.categoriaSelecionada != null) ...[
                          _buildEstimateCard(provider),
                          const SizedBox(height: 16),
                        ],

                        // ── CTA BUTTON ────────────────────────────────
                        _buildCtaButton(provider),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard(ChamadosProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bg3,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.location_on_rounded,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sua localização', style: AppTextStyles.labelS),
                const SizedBox(height: 2),
                Text(
                  provider.enderecoAtual,
                  style: AppTextStyles.h4,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriasGrid(ChamadosProvider provider) {
    if (provider.categorias.isEmpty) {
      return SizedBox(
        height: 100,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 8),
              Text('A carregar serviços...', style: AppTextStyles.bodyS),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: provider.categorias.length,
        itemBuilder: (context, index) {
          final cat = provider.categorias[index];
          final isSelected = provider.categoriaSelecionada == cat['nome'];
          final color = _getCategoryColor(cat['icone'] ?? '');
          final icon = _getIconData(cat['icone'] ?? '');

          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              provider.setCategoria(cat['nome']);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.only(right: 12),
              width: 82,
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withValues(alpha: 0.15)
                    : AppColors.bg3,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected
                      ? color.withValues(alpha: 0.6)
                      : AppColors.border,
                  width: isSelected ? 1.5 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : [],
              ),
              child: AnimatedScale(
                scale: isSelected ? 1.02 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        icon,
                        color: isSelected ? color : AppColors.textTertiary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      cat['nome'],
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected ? color : AppColors.textTertiary,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDescriptionField(ChamadosProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg3,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: _descricaoController,
        style: GoogleFonts.inter(
          fontSize: 14,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w400,
        ),
        maxLines: 2,
        minLines: 1,
        decoration: InputDecoration(
          labelText: 'Qual é o problema?',
          labelStyle: GoogleFonts.inter(
            color: AppColors.textTertiary,
            fontSize: 13,
          ),
          hintText: 'Descreva brevemente a situação...',
          hintStyle: GoogleFonts.inter(
            color: AppColors.textDisabled,
            fontSize: 13,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 14, right: 10),
            child: Icon(
              Icons.edit_note_rounded,
              color: AppColors.textTertiary,
              size: 20,
            ),
          ),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 0, minHeight: 0),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide:
                const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
        onChanged: (val) => provider.setDescricao(val),
      ),
    );
  }

  Widget _buildEstimateCard(ChamadosProvider provider) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.account_balance_wallet_rounded,
                color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Estimativa de custo',
                    style: AppTextStyles.labelS.copyWith(
                      color: AppColors.textSecondary,
                    )),
                const SizedBox(height: 3),
                provider.calculandoEstimativa
                    ? Row(
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color:
                                  AppColors.primary.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('A calcular...',
                              style: AppTextStyles.labelM.copyWith(
                                color: AppColors.textSecondary,
                              )),
                        ],
                      )
                    : Text(
                        provider.estimativaMin != null
                            ? 'R\$ ${provider.estimativaMin} – R\$ ${provider.estimativaMax}'
                            : 'Não disponível',
                        style: AppTextStyles.h4.copyWith(
                          color: provider.estimativaMin != null
                              ? AppColors.textPrimary
                              : AppColors.textTertiary,
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCtaButton(ChamadosProvider provider) {
    final isEnabled = provider.categoriaSelecionada != null;

    return GestureDetector(
      onTapDown: isEnabled ? (_) => _btnController.forward() : null,
      onTapUp: isEnabled
          ? (_) async {
              await _btnController.reverse();
              HapticFeedback.mediumImpact();
              provider.solicitarProfissional();
            }
          : null,
      onTapCancel: isEnabled ? () => _btnController.reverse() : null,
      child: AnimatedBuilder(
        animation: _btnScaleAnim,
        builder: (context, child) {
          return Transform.scale(
            scale: _btnScaleAnim.value,
            child: child,
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 58,
          decoration: BoxDecoration(
            gradient: isEnabled
                ? AppColors.primaryGradient
                : LinearGradient(colors: [
                    AppColors.bg4,
                    AppColors.bg4,
                  ]),
            borderRadius: BorderRadius.circular(18),
            boxShadow: isEnabled ? AppColors.primaryGlowShadow : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isEnabled ? Icons.search_rounded : Icons.search_rounded,
                color: isEnabled
                    ? Colors.white
                    : AppColors.textDisabled,
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                'ENCONTRAR PROFISSIONAL',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: isEnabled
                      ? Colors.white
                      : AppColors.textDisabled,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── BUSCANDO PANEL ────────────────────────────────────────────────────────
  Widget _buildBuscandoPanel(ChamadosProvider provider) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: AppColors.floatingShadow,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Lottie animation + timer
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    height: 130,
                    width: 130,
                    child: Lottie.network(
                      'https://lottie.host/6d1cbf49-f53f-4e0a-9d62-67852c50587d/91oD2k9Vb4.json',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          SizedBox(
                        width: 120,
                        height: 120,
                        child: CircularProgressIndicator(
                          value: provider.segundosRestantes / 90,
                          color: AppColors.primary,
                          backgroundColor: AppColors.bg4,
                          strokeWidth: 6,
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                    ),
                  ),
                  // Timer overlay
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.bg3.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _formatarTempo(provider.segundosRestantes),
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Text(
                'Procurando especialista...',
                style: AppTextStyles.h2,
              ),
              const SizedBox(height: 6),
              Text(
                provider.categoriaSelecionada != null
                    ? 'A pesquisar profissionais de ${provider.categoriaSelecionada} na sua área'
                    : 'A pesquisar profissionais na sua área',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyM,
              ),
              const SizedBox(height: 6),

              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: 1 - (provider.segundosRestantes / 90),
                  backgroundColor: AppColors.bg4,
                  color: AppColors.primary,
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 28),

              // Cancel button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('CANCELAR PEDIDO'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(
                        color: AppColors.error, width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    textStyle: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    provider.cancelarBuscaManualmente();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── TRACKING PANEL ────────────────────────────────────────────────────────
  Widget _buildTrackingPanel(ChamadosProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: AppColors.floatingShadow,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Status badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'PROFISSIONAL A CAMINHO',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Professional card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.bg3,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    // Avatar
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: AppColors.primaryGlowShadow,
                      ),
                      child: const Icon(Icons.person_rounded,
                          color: Colors.white, size: 30),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            provider.nomeProfissional,
                            style: AppTextStyles.h4,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.navigation_rounded,
                                  color: AppColors.primary, size: 14),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  provider.distanciaProfissional,
                                  style: AppTextStyles.labelM.copyWith(
                                    color: AppColors.primary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Botão de Chat
                    GestureDetector(
                      onTap: () async {
                        final auth = context.read<AuthProvider>();
                        final token = await const FlutterSecureStorage().read(key: 'access_token');
                        if (token == null || provider.idChamadoAtual == null) return;
                        if (!mounted) return;
                        
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              chamadoId: provider.idChamadoAtual!,
                              meuId: auth.userId ?? '',
                              meuTipo: 'cliente',
                              token: token,
                              apiUrl: Env.baseUrl,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.chat_rounded,
                            color: AppColors.primary, size: 20),
                      ),
                    ),
                    // Contact button
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.phone_rounded,
                          color: AppColors.primary, size: 20),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Info row
              Row(
                children: [
                  _buildInfoChip(
                    icon: Icons.access_time_rounded,
                    label: 'ETA',
                    value: 'A calcular',
                    color: AppColors.info,
                  ),
                  const SizedBox(width: 12),
                  _buildInfoChip(
                    icon: Icons.shield_rounded,
                    label: 'Status',
                    value: 'Em rota',
                    color: AppColors.success,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: AppTextStyles.labelXS.copyWith(color: color)),
                  Text(value,
                      style: AppTextStyles.labelM.copyWith(
                          color: AppColors.textPrimary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── MODAL SHEETS ──────────────────────────────────────────────────────────
  Widget _buildNaoEncontradoSheet(ChamadosProvider provider) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 28),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.person_search_rounded,
                  color: AppColors.error, size: 40),
            ),
            const SizedBox(height: 20),
            Text('Nenhum especialista disponível',
                style: AppTextStyles.h2, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(
              'Todos os profissionais da sua área estão ocupados. Tente novamente em alguns minutos.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyM,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  provider.resetarEstado();
                },
                child: Text('ENTENDIDO, TENTAR DE NOVO',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: Colors.white,
                    )),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSucessoSheet(
    ChamadosProvider provider, {
    required String nome,
    required String distancia,
  }) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 28),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 44),
            ),
            const SizedBox(height: 20),
            Text('$nome está a caminho!',
                style: AppTextStyles.h2, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(
              'Ótimas notícias! O profissional aceitou o seu pedido e encontra-se a $distancia. Aguarde no local indicado.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyM,
            ),
            const SizedBox(height: 28),
            // Distance badge
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.navigation_rounded,
                      color: AppColors.success, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    distancia,
                    style: AppTextStyles.h4.copyWith(color: AppColors.success),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _ajustarCameraParaAmbos(provider);
                },
                child: Text('OK, ESTOU A AGUARDAR',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: Colors.white,
                    )),
              ),
            ),
          ],
        ),
      ),
    );
  }
}