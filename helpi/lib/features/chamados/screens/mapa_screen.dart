import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../../core/services/socket_service.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/map_style.dart';
import '../providers/chamados_provider.dart';
import '../../pagamentos/screens/checkout_screen.dart';

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

class _MapaScreenViewState extends State<MapaScreenView> {
  GoogleMapController? mapController;
  final TextEditingController _descricaoController = TextEditingController(text: "Emergência urgente solicitada via Helpi App");

  @override
  void initState() {
    super.initState();
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
          backgroundColor: const Color(0xFF161A22),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
          ),
          builder: (context) => _construirPainelNaoEncontrado(chamadosProvider),
        );
      };

      chamadosProvider.onSuccess = (data) {
        if (!mounted) return;
        showModalBottomSheet(
          context: context,
          isDismissible: false,
          enableDrag: false,
          backgroundColor: const Color(0xFF161A22),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
          ),
          builder: (context) => _construirPainelSucesso(
            chamadosProvider,
            nome: data['profissional_nome'] ?? 'O Profissional',
            distancia: data['distancia_texto'] ?? 'caminho',
          ),
        );
      };

      chamadosProvider.onError = (erro) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(erro), backgroundColor: AppColors.error),
        );
      };

      chamadosProvider.onServicoFinalizado = (data) {
        if (!mounted) return;
        
        // Esconder a modal de tracking (se estiver aberta)
        Navigator.popUntil(context, (route) => route.isFirst);

        // Abrir a nova tela de checkout em ecrã inteiro
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CheckoutScreen(data: data),
          ),
        );
      };

      // Listen to provider changes to adjust camera dynamically when tracking
      chamadosProvider.addListener(_onProviderUpdate);
    });
  }

  void _onProviderUpdate() {
    if (!mounted) return;
    final chamadosProvider = context.read<ChamadosProvider>();
    if (chamadosProvider.isProfissionalACaminho && chamadosProvider.posicaoProfissional != null) {
      _ajustarCameraParaAmbos(chamadosProvider);
    }
  }

  @override
  void dispose() {
    mapController?.dispose();
    _descricaoController.dispose();
    SocketService().desconectar();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  void _ajustarCameraParaAmbos(ChamadosProvider provider) {
    if (mapController == null || provider.posicaoAtual == null || provider.posicaoProfissional == null) return;
    
    LatLngBounds bounds;
    final p1 = LatLng(provider.posicaoAtual!.latitude, provider.posicaoAtual!.longitude);
    final p2 = LatLng(provider.posicaoProfissional!.latitude, provider.posicaoProfissional!.longitude);
    
    if (p1.latitude > p2.latitude && p1.longitude > p2.longitude) {
      bounds = LatLngBounds(southwest: p2, northeast: p1);
    } else if (p1.longitude > p2.longitude) {
      bounds = LatLngBounds(southwest: LatLng(p1.latitude, p2.longitude), northeast: LatLng(p2.latitude, p1.longitude));
    } else if (p1.latitude > p2.latitude) {
      bounds = LatLngBounds(southwest: LatLng(p2.latitude, p1.longitude), northeast: LatLng(p1.latitude, p2.longitude));
    } else {
      bounds = LatLngBounds(southwest: p1, northeast: p2);
    }
    
    mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80.0)); // 80.0 de padding
  }

  Set<Marker> _getMarkers(ChamadosProvider provider) {
    Set<Marker> markers = {};
    if (provider.posicaoAtual != null) {
      markers.add(Marker(
        markerId: const MarkerId('cliente'),
        position: LatLng(provider.posicaoAtual!.latitude, provider.posicaoAtual!.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ));
    }
    if (provider.isProfissionalACaminho && provider.posicaoProfissional != null) {
      markers.add(Marker(
        markerId: const MarkerId('profissional'),
        position: LatLng(provider.posicaoProfissional!.latitude, provider.posicaoProfissional!.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
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
    switch(iconName) {
      case 'electrical_services': return Icons.electrical_services;
      case 'plumbing': return Icons.plumbing;
      case 'key': return Icons.key;
      case 'cleaning_services': return Icons.cleaning_services;
      case 'handyman': return Icons.handyman;
      default: return Icons.build;
    }
  }


  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChamadosProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: const Text(
            'Helpi',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: () => context.read<AuthProvider>().logout(),
            ),
          )
        ],
      ),
      body: provider.carregando
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryColor))
          : provider.posicaoAtual == null
              ? const Center(child: Text("Localização não encontrada."))
              : Stack(
                  children: [
                    GoogleMap(
                      onMapCreated: _onMapCreated,
                      style: MapStyle.darkStyle,
                      initialCameraPosition: CameraPosition(
                        target: LatLng(provider.posicaoAtual!.latitude, provider.posicaoAtual!.longitude),
                        zoom: 16.5,
                      ),
                      markers: _getMarkers(provider),
                      myLocationEnabled: !provider.isProfissionalACaminho, // Esconde o ponto azul do Google se estiver em tracking
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      mapToolbarEnabled: false,
                    ),
                    provider.isProfissionalACaminho
                        ? Align(
                            alignment: Alignment.bottomCenter,
                            child: _construirPainelRastreamento(provider),
                          )
                        : provider.isProcurando
                            ? Align(
                                alignment: Alignment.bottomCenter,
                                child: _construirPainelBuscando(provider),
                              )
                            : DraggableScrollableSheet(
                                initialChildSize: 0.45,
                                minChildSize: 0.15,
                                maxChildSize: 0.75,
                                builder: (context, scrollController) {
                                  return _construirPainelSolicitacao(provider, scrollController);
                                },
                              ),
                  ],
                ),
    );
  }

  Widget _construirPainelRastreamento(ChamadosProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161A22),
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20, offset: const Offset(0, -5))],
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B55D6).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF1B55D6), width: 2),
                    ),
                    child: const Icon(Icons.person, color: Color(0xFF1B55D6), size: 35),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          provider.nomeProfissional,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: Color(0xFF1B55D6), size: 16),
                            const SizedBox(width: 4),
                            Text(
                              provider.distanciaProfissional,
                              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.phone, color: Color(0xFF1B55D6)),
                  label: const Text('Contactar Profissional', style: TextStyle(color: Color(0xFF1B55D6), fontSize: 16, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF1B55D6), width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    // Simular chamada telefónica
                  },
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _construirPainelSolicitacao(ChamadosProvider provider, ScrollController scrollController) {
    const Color mockupBlue = Color(0xFF1B55D6);
    
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161A22),
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, -5),
          )
        ],
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: mockupBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.keyboard_arrow_up_rounded, color: mockupBlue, size: 16),
                      const SizedBox(width: 4),
                      const Text(
                        'Arraste para expandir',
                        style: TextStyle(color: mockupBlue, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Location Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_outlined, color: mockupBlue, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Sua localização", style: TextStyle(fontSize: 12, color: Colors.white54)),
                          Text(
                            provider.enderecoAtual,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Categories Title
              const Text(
                'Serviços disponíveis',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 16),

              // Categories Horizontal List
              SizedBox(
                height: 90,
                child: provider.categorias.isEmpty
                    ? const Center(child: Text("Nenhuma categoria disponível", style: TextStyle(color: Colors.white54)))
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: provider.categorias.length,
                        itemBuilder: (context, index) {
                          final cat = provider.categorias[index];
                          final isSelected = provider.categoriaSelecionada == cat['nome'];

                          return GestureDetector(
                            onTap: () => provider.setCategoria(cat['nome']),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(right: 12),
                              width: 80,
                              decoration: BoxDecoration(
                                color: isSelected ? mockupBlue.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected ? mockupBlue : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _getIconData(cat['icone']),
                                    color: isSelected ? Colors.white : Colors.white54,
                                    size: 28,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    cat['nome'],
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: isSelected ? Colors.white : Colors.white54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 24),

              // Description Field
              TextField(
                controller: _descricaoController,
                style: const TextStyle(fontSize: 14, color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Qual o problema?',
                  labelStyle: const TextStyle(color: Colors.white54),
                  hintText: 'Descreva a emergência brevemente',
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: mockupBlue, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: (val) => provider.setDescricao(val),
              ),
              const SizedBox(height: 24),

              // Find Professional Button
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mockupBlue,
                    disabledBackgroundColor: Colors.white.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  icon: Icon(
                    Icons.search,
                    color: provider.categoriaSelecionada == null ? Colors.white30 : Colors.white,
                  ),
                  label: Text(
                    'ENCONTRAR PROFISSIONAL',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: provider.categoriaSelecionada == null ? Colors.white30 : Colors.white,
                    ),
                  ),
                  onPressed: provider.categoriaSelecionada == null
                      ? null
                      : () => provider.solicitarProfissional(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _construirPainelBuscando(ChamadosProvider provider) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF161A22),
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20, offset: const Offset(0, -5))],
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    height: 90,
                    width: 90,
                    child: CircularProgressIndicator(
                      value: provider.segundosRestantes / 90,
                      color: const Color(0xFF1B55D6),
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      strokeWidth: 6,
                    ),
                  ),
                  Text(
                    _formatarTempo(provider.segundosRestantes),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Procurando especialista em\n${provider.categoriaSelecionada}...',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => provider.cancelarBuscaManualmente(),
                  child: const Text('CANCELAR PEDIDO', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.error)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _construirPainelNaoEncontrado(ChamadosProvider provider) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF161A22),
      ),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.person_search_rounded, color: Colors.redAccent, size: 40),
          ),
          const SizedBox(height: 24),
          const Text(
            'Nenhum profissional disponível',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          const Text(
            'Analisamos o raio de cobertura, mas todos os nossos especialistas estão ocupados ou fora da área no momento.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.white70),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B55D6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                Navigator.pop(context);
                provider.resetarEstado();
              },
              child: const Text('ENTENDIDO / TENTAR DE NOVO', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirPainelSucesso(ChamadosProvider provider, {required String nome, required String distancia}) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF161A22),
      ),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.greenAccent.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 40),
          ),
          const SizedBox(height: 24),
          Text(
            '$nome está a caminho!',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Suspiro de alívio! O profissional aceitou o pedido e encontra-se a $distancia de distância. Por favor, aguarde no local.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Colors.white70),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent[700],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                Navigator.pop(context); // Remove a modal
                _ajustarCameraParaAmbos(provider); // Ajusta a câmera para o rastreamento
              },
              child: const Text('OK, ESTOU À ESPERA', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}