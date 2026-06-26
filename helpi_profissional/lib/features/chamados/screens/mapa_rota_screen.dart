import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../../../core/services/location_service.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../services/chamado_service.dart';
import '../../../services/socket_service.dart';

/// Tela de Mapa que mostra a rota do profissional até a casa do cliente.
/// Exibe:
/// - Marker na posição atual do profissional (GPS em tempo real)
/// - Marker na casa do cliente
/// - Polyline com a rota real (via OSRM)
/// - ETA estimado (tempo e distância)
/// - Botão "Abrir no Google Maps" para navegação real
/// - Botão "Cheguei!" para avançar o status
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

  // Posição atual do profissional
  LatLng? _posicaoAtual;

  // Pontos da rota (Polyline)
  List<LatLng> _pontosRota = [];

  // Info da rota
  String _distanciaTexto = '...';
  String _tempoTexto = '...';

  // Estado da UI
  bool _carregandoRota = true;
  bool _registrandoChegada = false;
  bool _chegou = false;
  bool _finalizandoServico = false;

  // Timer para atualizar GPS
  Timer? _gpsTimer;

  // Animação do marker do profissional
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Animação de pulso no marker do profissional
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _inicializar();
  }

  Future<void> _inicializar() async {
    await _obterLocalizacao();
    await _buscarRota();

    // Atualiza GPS a cada 5 segundos
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

        // CORE LOOP: Emite a localização em tempo real para o cliente via WebSocket
        // O backend retransmite apenas para a sala do cliente específico
        if (widget.clienteId != null) {
          final profissionalId = context.read<AuthProvider>().profissionalId;
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
      // Fallback para São Paulo em ambiente de testes
      if (mounted && _posicaoAtual == null) {
        setState(() {
          _posicaoAtual = const LatLng(-23.550520, -46.633308);
        });
      }
    }
  }

  /// Busca a rota real via OSRM (OpenStreetMap Routing Machine) — 100% gratuito
  Future<void> _buscarRota() async {
    if (_posicaoAtual == null) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (_posicaoAtual == null) return;
    }

    try {
      final origem = _posicaoAtual!;
      final destino = LatLng(widget.latitudeDestino, widget.longitudeDestino);

      // OSRM API pública (lon,lat order!)
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
          final geometry = route['geometry'];
          final coordinates = geometry['coordinates'] as List;

          // OSRM retorna [longitude, latitude] — precisamos inverter
          final pontos =
              coordinates
                  .map<LatLng>(
                    (coord) => LatLng(
                      (coord[1] as num).toDouble(),
                      (coord[0] as num).toDouble(),
                    ),
                  )
                  .toList();

          // Distância em metros e duração em segundos
          final distancia = (route['distance'] as num).toDouble();
          final duracao = (route['duration'] as num).toDouble();

          if (mounted) {
            setState(() {
              _pontosRota = pontos;
              _distanciaTexto = _formatarDistancia(distancia);
              _tempoTexto = _formatarTempo(duracao);
              _carregandoRota = false;
            });

            // Ajusta o zoom para mostrar toda a rota
            _ajustarZoom(origem, destino);
          }
        }
      }
    } catch (e) {
      debugPrint('Erro ao buscar rota OSRM: $e');
      if (mounted) {
        setState(() => _carregandoRota = false);
        // Mesmo sem rota, mostra os markers
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
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(80)),
      );
    } catch (e) {
      // MapController pode não estar pronto ainda
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

  /// Abre o Google Maps ou Waze com navegação até o destino
  Future<void> _abrirNavegacaoExterna() async {
    final lat = widget.latitudeDestino;
    final lng = widget.longitudeDestino;

    // Tenta Google Maps primeiro
    final googleMapsUrl = Uri.parse(
      'google.navigation:q=$lat,$lng&mode=d',
    );
    final googleMapsWeb = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
    );

    try {
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl);
      } else {
        await launchUrl(googleMapsWeb, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível abrir o app de navegação'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Regista a chegada ao local via API
  Future<void> _registrarChegada() async {
    setState(() => _registrandoChegada = true);

    try {
      await _chamadoService.registrarChegada(widget.chamadoId);

      if (mounted) {
        setState(() {
          _chegou = true;
          _registrandoChegada = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Chegada registrada! O cliente foi notificado.'),
            backgroundColor: Color(0xFF00C853),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _registrandoChegada = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Abre o diálogo para inserir o preço
  void _abrirDialogoPreco() {
    final TextEditingController precoController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('💸 Definir Preço Final', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'O serviço foi concluído. Insira o valor a ser cobrado do cliente.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 12),
            if (widget.valorEstimadoMin != null)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
                ),
                child: Text(
                  'Estimativa Original: R\$ ${widget.valorEstimadoMin} - R\$ ${widget.valorEstimadoMax}',
                  style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: precoController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                prefixText: 'R\$ ',
                prefixStyle: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                filled: true,
                fillColor: Colors.black45,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              final valorStr = precoController.text.replaceAll(',', '.');
              final valor = double.tryParse(valorStr);
              if (valor == null || valor <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Insira um valor válido.'), backgroundColor: Colors.red),
                );
                return;
              }
              Navigator.pop(context);
              _finalizarServico(valor);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF448AFF)),
            child: const Text('COBRAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// Finaliza o serviço e retorna ao radar
  Future<void> _finalizarServico(double valorCobrado) async {
    setState(() => _finalizandoServico = true);

    try {
      await _chamadoService.finalizarChamado(widget.chamadoId, valorCobrado: valorCobrado);

      if (mounted) {
        setState(() => _finalizandoServico = false);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Serviço finalizado! Excelente trabalho!'),
            backgroundColor: Color(0xFF448AFF),
            duration: Duration(seconds: 3),
          ),
        );

        // Limpar chamado ativo e voltar
        context.read<AuthProvider>().limparChamadoAtivo();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _finalizandoServico = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao finalizar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _gpsTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final destinoLatLng = LatLng(
      widget.latitudeDestino,
      widget.longitudeDestino,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        children: [
          // ═══════════════════════════════════════════════
          // MAPA (OpenStreetMap via flutter_map)
          // ═══════════════════════════════════════════════
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter:
                  _posicaoAtual ?? const LatLng(-23.550520, -46.633308),
              initialZoom: 14.0,
            ),
            children: [
              // Tile layer — Estilo escuro do CartoDB (combina com o tema dark)
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.helpi.profissional',
              ),

              // Polyline da rota
              if (_pontosRota.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _pontosRota,
                      strokeWidth: 5.0,
                      color: const Color(0xFF448AFF),
                    ),
                  ],
                ),

              // Markers
              MarkerLayer(
                markers: [
                  // Marker do CLIENTE (destino) — 🏠
                  Marker(
                    point: destinoLatLng,
                    width: 50,
                    height: 50,
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.home_rounded,
                          color: Color(0xFFFF5252),
                          size: 36,
                          shadows: [
                            Shadow(
                              blurRadius: 12,
                              color: Colors.black54,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Marker do PROFISSIONAL (posição atual) — 📍
                  if (_posicaoAtual != null)
                    Marker(
                      point: _posicaoAtual!,
                      width: 50,
                      height: 50,
                      child: AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF448AFF,
                                  ).withValues(alpha: _pulseAnimation.value * 0.5),
                                  blurRadius: 20 * _pulseAnimation.value,
                                  spreadRadius: 5 * _pulseAnimation.value,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.navigation_rounded,
                              color: Color(0xFF448AFF),
                              size: 36,
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ],
          ),

          // ═══════════════════════════════════════════════
          // HEADER com info do chamado
          // ═══════════════════════════════════════════════
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF0A0A0A),
                    const Color(0xFF0A0A0A).withValues(alpha: 0.8),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      // Botão voltar
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Info do chamado
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.categoria,
                              style: const TextStyle(
                                color: Color(0xFF448AFF),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.descricao,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
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
            ),
          ),

          // ═══════════════════════════════════════════════
          // PAINEL INFERIOR (ETA + Botões)
          // ═══════════════════════════════════════════════
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    const Color(0xFF0A0A0A),
                    const Color(0xFF0A0A0A).withValues(alpha: 0.95),
                    const Color(0xFF0A0A0A).withValues(alpha: 0.7),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.4, 0.7, 1.0],
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 40, 20, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Card de ETA
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            // Distância
                            _buildEtaItem(
                              icon: Icons.straighten_rounded,
                              label: 'DISTÂNCIA',
                              value: _carregandoRota ? '...' : _distanciaTexto,
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                            // Tempo
                            _buildEtaItem(
                              icon: Icons.access_time_rounded,
                              label: 'TEMPO EST.',
                              value: _carregandoRota ? '...' : _tempoTexto,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Botões de ação
                      Row(
                        children: [
                          // Botão "Abrir GPS"
                          Expanded(
                            child: SizedBox(
                              height: 56,
                              child: OutlinedButton.icon(
                                onPressed: _abrirNavegacaoExterna,
                                icon: const Icon(
                                  Icons.navigation_rounded,
                                  size: 22,
                                ),
                                label: const Text(
                                  'ABRIR GPS',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.0,
                                    fontSize: 14,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF448AFF),
                                  side: const BorderSide(
                                    color: Color(0xFF448AFF),
                                    width: 1.5,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 12),

                          // Botão "CHEGUEI!" ou "FINALIZAR SERVIÇO"
                          Expanded(
                            flex: 2,
                            child: SizedBox(
                              height: 56,
                              child: ElevatedButton.icon(
                                onPressed:
                                    (_registrandoChegada || _finalizandoServico)
                                        ? null
                                        : (_chegou ? _abrirDialogoPreco : _registrarChegada),
                                icon:
                                    (_registrandoChegada || _finalizandoServico)
                                        ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.white,
                                          ),
                                        )
                                        : Icon(
                                          _chegou
                                              ? Icons.check_circle_rounded
                                              : Icons.location_on_rounded,
                                          size: 22,
                                        ),
                                label: Text(
                                  _chegou ? 'FINALIZAR SERVIÇO' : 'CHEGUEI!',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.0,
                                    fontSize: 15,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      _chegou
                                          ? const Color(0xFF448AFF)
                                          : const Color(0xFF00C853),
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: const Color(
                                    0xFF2E7D32,
                                  ),
                                  disabledForegroundColor: Colors.white70,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Loading overlay enquanto busca a rota
          if (_carregandoRota)
            Positioned(
              top: MediaQuery.of(context).size.height * 0.45,
              left: 0,
              right: 0,
              child: const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(color: Color(0xFF448AFF)),
                    SizedBox(height: 12),
                    Text(
                      'A calcular rota...',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEtaItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF448AFF), size: 22),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
