import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/network/app_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../services/socket_service.dart';

class MapaScreen extends StatefulWidget {
  const MapaScreen({super.key});

  @override
  State<MapaScreen> createState() => _MapaScreenState();
}

class _MapaScreenState extends State<MapaScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  final Set<Circle> _circles = {};
  Timer? _heatmapTimer;
  final SocketService _socketService = SocketService();
  
  // Posição inicial (centro da cidade ou localização atual)
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(-23.550520, -46.633308), // SP Capital
    zoom: 12.0,
  );

  @override
  void initState() {
    super.initState();
    _fetchHeatmap();
    // Atualizar o heatmap a cada 30 segundos
    _heatmapTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _fetchHeatmap();
    });

    _setupSocket();
  }

  void _setupSocket() {
    // Escuta evento de mudança de multiplicador no socket, se implementado
    _socketService.socket?.on('surge_pricing_update', (data) {
      if (mounted) {
        final double multiplicador = double.tryParse(data['multiplicador'].toString()) ?? 1.0;
        if (multiplicador > 1.0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Alta procura na sua região! Ganhos multiplicados por ${multiplicador}x.'),
              backgroundColor: AppColors.warning,
              duration: const Duration(seconds: 5),
            )
          );
        }
        _fetchHeatmap(); // Recarrega o mapa
      }
    });
  }

  Future<void> _fetchHeatmap() async {
    try {
      final response = await ApiClient().dio.get('/radar/heatmap');
      if (response.statusCode == 200) {
        final List<dynamic> zonas = response.data['zonas'] ?? [];
        
        final Set<Circle> newCircles = {};
        for (var zona in zonas) {
          final lat = double.parse(zona['centro_lat'].toString());
          final lng = double.parse(zona['centro_lng'].toString());
          final raio = double.parse(zona['raio_metros'].toString());
          final mult = double.parse(zona['multiplicador'].toString());
          
          Color corCirculo;
          if (mult < 1.3) {
            corCirculo = Colors.orange.withValues(alpha: 0.3);
          } else {
            corCirculo = Colors.redAccent.withValues(alpha: 0.4);
          }

          newCircles.add(
            Circle(
              circleId: CircleId('zona_${lat}_$lng'),
              center: LatLng(lat, lng),
              radius: raio,
              fillColor: corCirculo,
              strokeColor: corCirculo.withValues(alpha: 0.8),
              strokeWidth: 2,
            )
          );
        }

        if (mounted) {
          setState(() {
            _circles.clear();
            _circles.addAll(newCircles);
          });
        }
      }
    } catch (e) {
      debugPrint('Erro ao buscar heatmap: $e');
    }
  }

  @override
  void dispose() {
    _heatmapTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mapa de Demanda', style: AppTextStyles.h3),
        backgroundColor: AppColors.bg1,
      ),
      body: GoogleMap(
        initialCameraPosition: _initialPosition,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        circles: _circles,
        onMapCreated: (GoogleMapController controller) {
          _controller.complete(controller);
        },
      ),
    );
  }
}
