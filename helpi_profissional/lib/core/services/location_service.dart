import 'package:geolocator/geolocator.dart';

class LocationService {
  static Future<Position> obterLocalizacaoAtual() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 1. Verifica se o GPS está ligado
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Por favor, ative o GPS do seu dispositivo.');
    }

    // 2. Verifica as permissões
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Permissões de localização negadas pelo utilizador.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('As permissões de localização estão negadas permanentemente.');
    }

    // 3. Obtém a posição com precisão alta
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }
}
