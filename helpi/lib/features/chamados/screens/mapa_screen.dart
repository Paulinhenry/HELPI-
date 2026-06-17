import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

// Importações do teu núcleo (Core)
import '../../../core/services/location_service.dart';
import '../../../core/providers/auth_provider.dart';

class MapaScreen extends StatefulWidget {
  const MapaScreen({super.key});

  @override
  State<MapaScreen> createState() => _MapaScreenState();
}

class _MapaScreenState extends State<MapaScreen> {
  GoogleMapController? mapController;
  Position? _posicaoAtual;
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _buscarLocalizacao(); // Assim que a tela abre, pede o GPS
  }

  Future<void> _buscarLocalizacao() async {
    try {
      // Chama o teu serviço de infraestrutura que construíste antes!
      Position posicao = await LocationService.obterLocalizacaoAtual();
      setState(() {
        _posicaoAtual = posicao;
        _carregando = false;
      });
    } catch (e) {
      setState(() {
        _carregando = false;
      });
      // Se o utilizador negar o GPS, mostra um aviso na base do ecrã
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Helpi',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () {
              // Botão de Sair usa o teu Provider!
              context.read<AuthProvider>().logout();
            },
          )
        ],
      ),
      // Se estiver a calcular a posição, mostra o símbolo a rodar
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _posicaoAtual == null
              ? const Center(child: Text("Localização não encontrada."))
              // SE TUDO CORRER BEM, RENDERIZA O MAPA DA GOOGLE!
              : GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(
                    target: LatLng(_posicaoAtual!.latitude, _posicaoAtual!.longitude),
                    zoom: 16.0, // Zoom ideal para ver as ruas (nível Uber)
                  ),
                  myLocationEnabled: true, // Mostra aquela bolinha azul do utilizador
                  myLocationButtonEnabled: true, // Botão de centrar o mapa
                  zoomControlsEnabled: false, // Esconde os botões +/- para ficar mais limpo
                ),
    );
  }
}
