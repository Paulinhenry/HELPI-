import 'package:geolocator/geolocator.dart';

class LocationService {
  // Uma função estática para podermos chamá-la de qualquer lugar sem ter de a instanciar
  static Future<Position> obterLocalizacaoAtual() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 1. Verifica se o GPS do telemóvel está fisicamente ligado
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Se estiver desligado, lança um erro que podemos mostrar na interface mais tarde
      return Future.error('Por favor, ative o GPS do seu dispositivo.');
    }

    // 2. Verifica as permissões da aplicação
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // Se não tem permissão, faz aparecer o Pop-Up nativo (aquele que configuraste no iOS/Android)
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Permissões de localização negadas pelo utilizador.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'As permissões de localização estão negadas permanentemente. Vá às definições do telemóvel.');
    }

    // 3. Se passou por todas as barreiras de segurança, obtém as coordenadas exatas!
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high, // Exige precisão alta (crucial para o Helpi)
    );
  }
}
