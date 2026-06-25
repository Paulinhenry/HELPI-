import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:geocoding/geocoding.dart'; // <--- Nova importação para ler moradas

// Importações do Core
import '../../../core/services/location_service.dart';
import '../../../core/services/socket_service.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../services/chamados_service.dart';

class MapaScreen extends StatefulWidget {
  const MapaScreen({super.key});

  @override
  State<MapaScreen> createState() => _MapaScreenState();
}

class _MapaScreenState extends State<MapaScreen> {
  GoogleMapController? mapController;
  Position? _posicaoAtual;
  bool _carregando = true;

  // Nova variável de estado
  String _enderecoAtual = "A procurar morada...";

  // --- CONTROLE DE ESTADOS DO CHAMADO ---
  String? _categoriaSelecionada;
  bool _isProcurando = false;
  String? _idChamadoAtual;

  // --- MECANISMO DE COOLDOWN / TIMEOUT (1:30) ---
  Timer? _cooldownTimer;
  int _segundosRestantes = 90; // 90 segundos = 1 minuto e meio

  final ChamadosService _chamadosService = ChamadosService();

  final List<Map<String, dynamic>> _categorias = [
    {'nome': 'Elétrica', 'icone': Icons.electrical_services, 'cor': Colors.orange},
    {'nome': 'Hidráulica', 'icone': Icons.plumbing, 'cor': Colors.blue},
    {'nome': 'Chaveiro', 'icone': Icons.key, 'cor': Colors.amber},
    {'nome': 'Limpeza', 'icone': Icons.cleaning_services, 'cor': Colors.teal},
    {'nome': 'Montador', 'icone': Icons.handyman, 'cor': Colors.blueGrey},
  ];

  @override
  void initState() {
    super.initState();
    _buscarLocalizacao();
    Future.microtask(() {
      if (!mounted) return;
      final authProvider = context.read<AuthProvider>();
      if (authProvider.userId != null) {
        SocketService().conectar(authProvider.userId!);
      }
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel(); // Limpa o timer da memória para evitar vazamento de dados
    mapController?.dispose(); // Libera o controlador do Google Maps
    super.dispose();
  }

  Future<void> _buscarLocalizacao() async {
    try {
      // 1. Vai buscar a Latitude/Longitude crua
      Position posicao = await LocationService.obterLocalizacaoAtual();
      
      String enderecoFormatado = "Morada desconhecida";

      // 2. O Mágico Geocoding: Pergunta à Google qual é a rua destas coordenadas
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          posicao.latitude, 
          posicao.longitude
        );

        if (placemarks.isNotEmpty) {
          Placemark lugar = placemarks[0];
          // Constrói a morada (Ex: "Rua Augusta, 123 - Lisboa")
          // thoroughfare = Nome da Rua | subThoroughfare = Número da porta
          final rua = lugar.thoroughfare ?? '';
          final numero = lugar.subThoroughfare ?? '';
          final cidade = lugar.subAdministrativeArea ?? lugar.locality ?? '';
          
          enderecoFormatado = '$rua, $numero - $cidade'.trim();
          
          // Limpeza caso a rua venha vazia
          if (enderecoFormatado == ', -') enderecoFormatado = "GPS Ativo (Rua não identificada)";
        }
      } catch (geoErro) {
        // Se o serviço de tradução falhar, não quebramos a app
        enderecoFormatado = "Coordenadas: ${posicao.latitude.toStringAsFixed(4)}, ${posicao.longitude.toStringAsFixed(4)}";
      }

      // 3. Atualiza o ecrã com a morada real
      if (mounted) {
        setState(() {
          _posicaoAtual = posicao;
          _enderecoAtual = enderecoFormatado;
          _carregando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _carregando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  // Inicia o contador regressivo de 90 segundos
  void _iniciarContador() {
    setState(() {
      _segundosRestantes = 90;
    });

    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_segundosRestantes > 0) {
        setState(() {
          _segundosRestantes--;
        });
      } else {
        // O tempo esgotou! Cancela o timer ANTES de processar
        timer.cancel();
        _finalizarBuscaPorTimeout();
      }
    });
  }

  // Executado automaticamente quando os 1:30 minutos acabam
  void _finalizarBuscaPorTimeout() {
    _cooldownTimer?.cancel();
    SocketService().pararDeOuvir();

    // CORREÇÃO: Cancela o chamado no servidor para não ficar pendente eternamente
    if (_idChamadoAtual != null) {
      _chamadosService.cancelarChamado(_idChamadoAtual!).catchError((e) {
        debugPrint('Aviso: falha ao cancelar chamado no timeout: $e');
      });
    }

    if (!mounted) return;

    setState(() {
      _isProcurando = false;
      _idChamadoAtual = null;
    });

    // Abre um feedback visual premium informando que ninguém foi encontrado
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
      ),
      builder: (context) => _construirPainelNaoEncontrado(),
    );
  }

  // Cancelamento manual feito pelo cliente clicando no botão
  Future<void> _cancelarBuscaManualmente() async {
    // 1. Pára o cronómetro imediatamente
    _cooldownTimer?.cancel();
    SocketService().pararDeOuvir();

    // 2. Se temos um ID de chamado registado, avisamos o Node.js para o cancelar!
    if (_idChamadoAtual != null) {
      try {
        await _chamadosService.cancelarChamado(_idChamadoAtual!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pedido cancelado com sucesso.'), backgroundColor: Colors.orange),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Aviso: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }

    // 3. Independentemente do servidor, fechamos a interface para o utilizador
    setState(() {
      _isProcurando = false;
      _categoriaSelecionada = null;
      _idChamadoAtual = null; // Limpamos a memória
    });
  }

  Future<void> _solicitarProfissional() async {
    if (_categoriaSelecionada == null || _posicaoAtual == null) return;

    setState(() {
      _isProcurando = true;
    });

    // Arranca o cronômetro visual imediatamente
    _iniciarContador();
    SocketService().ouvirAtualizacoesChamado(_onAtualizacaoChamado);

    try {
      final chamadoId = await _chamadosService.criarChamado(
        categoria: _categoriaSelecionada!,
        descricao: 'Emergência urgente solicitada via Helpi App', // Mantém acima de 10 caracteres
        latitude: _posicaoAtual!.latitude,
        longitude: _posicaoAtual!.longitude,
      );

      if (mounted) {
        setState(() {
          _idChamadoAtual = chamadoId;
        });
      }
    } catch (e) {
      _cooldownTimer?.cancel();
      setState(() => _isProcurando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.error),
        );
      }
    }
  }

  // Transforma segundos brutos no formato MM:SS (ex: 90 -> 01:30)
  String _formatarTempo(int segundos) {
    final minutos = segundos ~/ 60;
    final restante = segundos % 60;
    return '${minutos.toString().padLeft(2, '0')}:${restante.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
          ),
          child: const Text(
            'Helpi',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryColor),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: IconButton(
              icon: const Icon(Icons.person, color: AppColors.primaryColor),
              onPressed: () => context.read<AuthProvider>().logout(),
            ),
          )
        ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryColor))
          : _posicaoAtual == null
              ? const Center(child: Text("Localização não encontrada."))
              : Stack(
                  children: [
                    GoogleMap(
                      onMapCreated: _onMapCreated,
                      initialCameraPosition: CameraPosition(
                        target: LatLng(_posicaoAtual!.latitude, _posicaoAtual!.longitude),
                        zoom: 16.5,
                      ),
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      mapToolbarEnabled: false,
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: _isProcurando ? _construirPainelBuscando() : _construirPainelSolicitacao(),
                    ),
                  ],
                ),
    );
  }

  // --- PAINEL PADRÃO DE SELEÇÃO DE CATEGORIAS ---
  Widget _construirPainelSolicitacao() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(color: AppColors.background, shape: BoxShape.circle),
                      child: const Icon(Icons.my_location, color: AppColors.primaryColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Local Atual", style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Text(
                            _enderecoAtual, // <--- A nossa nova variável inteligente
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(height: 1),
                const SizedBox(height: 24),
                const Text(
                  'Qual é a sua emergência?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categorias.length,
                    itemBuilder: (context, index) {
                      final cat = _categorias[index];
                      final isSelected = _categoriaSelecionada == cat['nome'];

                      return GestureDetector(
                        onTap: () => setState(() => _categoriaSelecionada = cat['nome']),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 16),
                          width: 85,
                          decoration: BoxDecoration(
                            color: isSelected ? cat['cor'].withValues(alpha: 0.15) : AppColors.background,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: isSelected ? cat['cor'] : Colors.transparent, width: 2),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(cat['icone'], color: isSelected ? cat['cor'] : Colors.grey[600], size: 32),
                              const SizedBox(height: 8),
                              Text(
                                cat['nome'],
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? AppColors.textPrimary : Colors.grey[600],
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
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      disabledBackgroundColor: Colors.grey[300],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: _categoriaSelecionada == null ? 0 : 5,
                    ),
                    onPressed: _categoriaSelecionada == null ? null : _solicitarProfissional,
                    child: Text(
                      _categoriaSelecionada == null ? 'Escolha um serviço' : 'ENCONTRAR PROFISSIONAL',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _categoriaSelecionada == null ? Colors.grey[600] : Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- PAINEL DE RADAR COM CRONÔMETRO ATIVO ---
  Widget _construirPainelBuscando() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, -5))],
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
                      value: _segundosRestantes / 90, // Barra reduz conforme o tempo passa
                      color: AppColors.primaryColor,
                      backgroundColor: Colors.grey[200],
                      strokeWidth: 6,
                    ),
                  ),
                  // Mostrador digital do tempo (Estilo Uber)
                  Text(
                    _formatarTempo(_segundosRestantes),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryColor),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Procurando especialista em\n$_categoriaSelecionada...',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
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
                  onPressed: _cancelarBuscaManualmente,
                  child: const Text('CANCELAR PEDIDO', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.error)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- PAINEL INFERIOR QUANDO O TEMPO ESGOTA ---
  Widget _construirPainelNaoEncontrado() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.red[50], shape: BoxShape.circle),
            child: const Icon(Icons.person_search_rounded, color: AppColors.error, size: 40),
          ),
          const SizedBox(height: 24),
          const Text(
            'Nenhum profissional disponível',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          const Text(
            'Analisamos o raio de cobertura, mas todos os nossos especialistas estão ocupados ou fora da área no momento.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                Navigator.pop(context); // Fecha o painel de erro
                setState(() {
                  _categoriaSelecionada = null; // Permite escolher de novo
                });
              },
              child: const Text('ENTENDIDO / TENTAR DE NOVO', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  // --- PAINEL DE SUCESSO (SUSPIRO DE ALÍVIO) ---
  Widget _construirPainelSucesso({required String nome, required String distancia}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.green[50], shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 40),
          ),
          const SizedBox(height: 24),
          Text(
            '$nome está a caminho!',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Suspiro de alívio! O profissional aceitou o pedido e encontra-se a $distancia de distância. Por favor, aguarde no local.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                Navigator.pop(context); // Fecha o painel de sucesso
                setState(() {
                  _categoriaSelecionada = null; // Permite um novo pedido depois
                  _idChamadoAtual = null;
                });
              },
              child: const Text('OK, ESTOU À ESPERA', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  void _onAtualizacaoChamado(Map<String, dynamic> data) {
    if (data['status_novo'] == 'a_caminho' && data['chamado_id'] == _idChamadoAtual) {
      _cooldownTimer?.cancel();
      SocketService().pararDeOuvir();
      
      if (!mounted) return;
      
      setState(() {
        _isProcurando = false;
      });

      // Abre o feedback de sucesso!
      showModalBottomSheet(
        context: context,
        isDismissible: false,
        enableDrag: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
        ),
        builder: (context) => _construirPainelSucesso(
          nome: data['profissional_nome'] ?? 'O Profissional',
          distancia: data['distancia_texto'] ?? 'caminho',
        ),
      );
    }
  }
}