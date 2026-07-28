import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';

import 'app_colors.dart';

class DarkMapTileLayer extends StatelessWidget {
  const DarkMapTileLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return TileLayer(
      urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
      subdomains: const ['a', 'b', 'c', 'd'],
      userAgentPackageName: 'com.helpi.profissional',
      // retinaMode is deprecated in flutter_map v6/v7, handled by default or tile provider
      tileProvider: CancellableNetworkTileProvider(),
      // Opcional: subtil toque azulado da identidade visual
      tileBuilder: (context, tileWidget, tile) {
        return ColorFiltered(
          colorFilter: ColorFilter.mode(
            AppColors.primary.withValues(alpha: 0.08), 
            BlendMode.srcATop,
          ),
          child: tileWidget,
        );
      },
    );
  }
}
