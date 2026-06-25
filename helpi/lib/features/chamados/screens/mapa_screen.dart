import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../../core/services/socket_service.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/chamados_provider.dart';

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
    });
  }

  @override
  void dispose() {
    mapController?.dispose();
    _descricaoController.dispose();
    // Arch Fix: Desconectar socket
    SocketService().desconectar();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  // Transforma segundos brutos no formato MM:SS
  String _formatarTempo(int segundos) {
    final minutos = segundos ~/ 60;
    final restante = segundos % 60;
    return '${minutos.toString().padLeft(2, '0')}:${restante.toString().padLeft(2, '0')}';
  }

  // Helper para obter IconData pelo nome da string da DB
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

  // Helper para obter a Cor pela string da DB
  Color _getColor(String colorName) {
    switch(colorName) {
      case 'orange': return Colors.orange;
      case 'blue': return Colors.blue;
      case 'amber': return Colors.amber;
      case 'teal': return Colors.teal;
      case 'blueGrey': return Colors.blueGrey;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChamadosProvider>();

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
              // UX Fix: Ícone de logout
              icon: const Icon(Icons.logout, color: AppColors.primaryColor),
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
                      initialCameraPosition: CameraPosition(
                        target: LatLng(provider.posicaoAtual!.latitude, provider.posicaoAtual!.longitude),
                        zoom: 16.5,
                      ),
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      mapToolbarEnabled: false,
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: provider.isProcurando 
                        ? _construirPainelBuscando(provider) 
                        : _construirPainelSolicitacao(provider),
                    ),
                  ],
                ),
    );
  }

  Widget _construirPainelSolicitacao(ChamadosProvider provider) {
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
                            provider.enderecoAtual,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // UX Fix: Campo para descrição personalizada
                TextField(
                  controller: _descricaoController,
                  decoration: InputDecoration(
                    labelText: 'Qual o problema?',
                    hintText: 'Descreva a emergência brevemente',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (val) => provider.setDescricao(val),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Escolha a categoria',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 100,
                  child: provider.categorias.isEmpty 
                    ? const Center(child: Text("Nenhuma categoria disponível"))
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: provider.categorias.length,
                        itemBuilder: (context, index) {
                          final cat = provider.categorias[index];
                          final isSelected = provider.categoriaSelecionada == cat['nome'];
                          final catColor = _getColor(cat['cor']);

                          return GestureDetector(
                            onTap: () => provider.setCategoria(cat['nome']),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(right: 16),
                              width: 85,
                              decoration: BoxDecoration(
                                color: isSelected ? catColor.withValues(alpha: 0.15) : AppColors.background,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: isSelected ? catColor : Colors.transparent, width: 2),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(_getIconData(cat['icone']), color: isSelected ? catColor : Colors.grey[600], size: 32),
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
                      elevation: provider.categoriaSelecionada == null ? 0 : 5,
                    ),
                    onPressed: provider.categoriaSelecionada == null 
                        ? null 
                        : () => provider.solicitarProfissional(),
                    child: Text(
                      provider.categoriaSelecionada == null ? 'Escolha um serviço' : 'ENCONTRAR PROFISSIONAL',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: provider.categoriaSelecionada == null ? Colors.grey[600] : Colors.white,
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

  Widget _construirPainelBuscando(ChamadosProvider provider) {
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
                      value: provider.segundosRestantes / 90,
                      color: AppColors.primaryColor,
                      backgroundColor: Colors.grey[200],
                      strokeWidth: 6,
                    ),
                  ),
                  Text(
                    _formatarTempo(provider.segundosRestantes),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryColor),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Procurando especialista em\n${provider.categoriaSelecionada}...',
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
                Navigator.pop(context);
                provider.resetarEstado();
              },
              child: const Text('OK, ESTOU À ESPERA', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}