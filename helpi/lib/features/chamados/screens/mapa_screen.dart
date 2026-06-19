import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

// Importações do teu Core
import '../../../core/services/location_service.dart';
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
  bool _solicitando = false;
  bool _isProcurando = false; // Controla se estamos no modo "Radar"
  String? _idChamadoAtual; // Guardará o ID do chamado devolvido pelo Node.js
  final ChamadosService _chamadosService = ChamadosService();

  // --- DADOS DA INTERFACE DO HELPI ---
  String? _categoriaSelecionada; // Guarda o que o cliente escolheu

  // Catálogo rápido de emergências (Mentalidade Uber)
  final List<Map<String, dynamic>> _categorias = [
    {'nome': 'Eletricista', 'icone': Icons.electrical_services, 'cor': Colors.orange},
    {'nome': 'Encanador', 'icone': Icons.plumbing, 'cor': Colors.blue},
    {'nome': 'Chaveiro', 'icone': Icons.key, 'cor': Colors.amber},
    {'nome': 'Faxina', 'icone': Icons.cleaning_services, 'cor': Colors.teal},
    {'nome': 'Montador', 'icone': Icons.handyman, 'cor': Colors.blueGrey},
  ];

  @override
  void initState() {
    super.initState();
    _buscarLocalizacao();
  }

  Future<void> _buscarLocalizacao() async {
    try {
      Position posicao = await LocationService.obterLocalizacaoAtual();
      setState(() {
        _posicaoAtual = posicao;
        _carregando = false;
      });
    } catch (e) {
      setState(() => _carregando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  // Função que será chamada quando o cliente clicar em "Solicitar"
  Future<void> _solicitarProfissional() async {
    if (_posicaoAtual == null || _categoriaSelecionada == null) return;

    // 1. Muda a interface para o modo "Radar" instantaneamente
    setState(() {
      _isProcurando = true;
      _solicitando = true;
    });

    try {
      // 2. O MOMENTO MILIONÁRIO: Escreve no teu Banco de Dados PostGIS!
      final chamadoId = await _chamadosService.criarChamado(
        categoria: _categoriaSelecionada!,
        descricao: 'Preciso de um $_categoriaSelecionada urgente!', 
        latitude: _posicaoAtual!.latitude,
        longitude: _posicaoAtual!.longitude,
      );

      if (mounted) {
        setState(() {
          _idChamadoAtual = chamadoId;
        });
        
        // Sucesso visual
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pedido registado! A procurar profissionais...'), backgroundColor: AppColors.success),
        );
      }
      
      // NOTA: O ecrã vai continuar no modo "Radar" a girar infinitamente agora. 
      // Numa app On-Demand real, é exatamente isto que acontece até que um 
      // profissional do outro lado aceite o pedido (via WebSockets no futuro).

    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcurando = false;
          _solicitando = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // A AppBar agora é flutuante e transparente (estilo Uber) para maximizar o mapa
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10),
                ],
              ),
              child: const Text(
                'Helpi',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryColor),
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: IconButton(
              icon: const Icon(Icons.person, color: AppColors.primaryColor),
              onPressed: () {
                // Futuramente abrir o menu de Perfil/Sair
                context.read<AuthProvider>().logout();
              },
            ),
          )
        ],
      ),
      
      // O STACK: A mágica de colocar painéis por cima do mapa
      body: _carregando
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryColor))
          : _posicaoAtual == null
              ? const Center(child: Text("Localização não encontrada."))
              : Stack(
                  children: [
                    // CAMADA 1: O MAPA NO FUNDO
                    GoogleMap(
                      onMapCreated: _onMapCreated,
                      initialCameraPosition: CameraPosition(
                        target: LatLng(_posicaoAtual!.latitude, _posicaoAtual!.longitude),
                        zoom: 16.5, // Zoom bem focado nas ruas
                      ),
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false, // Desativado o padrão para criarmos um customizado depois
                      zoomControlsEnabled: false,
                      mapToolbarEnabled: false,
                    ),

                    // CAMADA 2: O PAINEL DE SOLICITAÇÃO (BOTTOM SHEET)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: _isProcurando ? _construirPainelBuscando() : _construirPainelSolicitacao(),
                    ),
                  ],
                ),
    );
  }

  // --- O COMPONENTE PREMIUM DE DESIGN ---
  Widget _construirPainelSolicitacao() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32), // Padding generoso
      child: Column(
        mainAxisSize: MainAxisSize.min, // Só ocupa o espaço necessário
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. A barrinha cinza (Drag Handle visual)
          Center(
            child: Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 2. Indicador de Localização (Futuro Geocoding)
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.background, shape: BoxShape.circle),
                child: const Icon(Icons.my_location, color: AppColors.primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Local Atual", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(
                      "Usando GPS do dispositivo", // No futuro: "Rua Augusta, 123"
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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

          // 3. Título da Ação
          const Text(
            'Qual é a sua emergência?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),

          // 4. Lista Horizontal de Categorias (Design Premium)
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _categorias.length,
              itemBuilder: (context, index) {
                final cat = _categorias[index];
                final isSelected = _categoriaSelecionada == cat['nome'];

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _categoriaSelecionada = cat['nome'];
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 16),
                    width: 85,
                    decoration: BoxDecoration(
                      color: isSelected ? cat['cor'].withOpacity(0.15) : AppColors.background,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? cat['cor'] : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          cat['icone'],
                          color: isSelected ? cat['cor'] : Colors.grey[600],
                          size: 32,
                        ),
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
          const SizedBox(height: 32),

          // 5. Botão Gigante de Solicitação (CTA)
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
              // Se nenhuma categoria estiver selecionada, o botão fica inativo (null)
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
    );
  }
  // --- O PAINEL DE "RADAR" (ESTADO DE BUSCA) ---
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
              // Animação de Procura
              const SizedBox(
                height: 80,
                width: 80,
                child: CircularProgressIndicator(
                  color: AppColors.primaryColor,
                  strokeWidth: 4,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'A procurar especialista em\n$_categoriaSelecionada...',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              const Text(
                'Isto costuma demorar menos de 1 minuto.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              
              // Botão de Cancelar
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    // Aqui futuramente vais bater na API para cancelar o chamado
                    setState(() {
                      _isProcurando = false;
                      _categoriaSelecionada = null; // Reseta a escolha
                    });
                  },
                  child: const Text('CANCELAR PEDIDO', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.error)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}