import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import '../../../core/services/location_service.dart';
import '../../../core/services/socket_service.dart';
import '../services/chamados_service.dart';
import '../services/categorias_service.dart';

class ChamadosProvider with ChangeNotifier {
  final ChamadosService _chamadosService = ChamadosService();
  final CategoriasService _categoriasService = CategoriasService();

  Position? _posicaoAtual;
  bool _carregando = true;
  String _enderecoAtual = "A procurar morada...";
  
  List<Map<String, dynamic>> _categorias = [];
  String? _categoriaSelecionada;
  bool _isProcurando = false;
  String? _idChamadoAtual;
  String _descricaoProblema = "Emergência urgente solicitada via Helpi App";

  Timer? _cooldownTimer;
  int _segundosRestantes = 90;

  // Callbacks for UI
  Function()? onTimeout;
  Function(Map<String, dynamic>)? onSuccess;
  Function(String)? onError;

  Position? get posicaoAtual => _posicaoAtual;
  bool get carregando => _carregando;
  String get enderecoAtual => _enderecoAtual;
  List<Map<String, dynamic>> get categorias => _categorias;
  String? get categoriaSelecionada => _categoriaSelecionada;
  bool get isProcurando => _isProcurando;
  String? get idChamadoAtual => _idChamadoAtual;
  int get segundosRestantes => _segundosRestantes;
  String get descricaoProblema => _descricaoProblema;

  void setCategoria(String? categoria) {
    _categoriaSelecionada = categoria;
    notifyListeners();
  }

  void setDescricao(String descricao) {
    if (descricao.trim().isNotEmpty) {
      _descricaoProblema = descricao;
      notifyListeners();
    }
  }

  Future<void> inicializar() async {
    await Future.wait([
      _buscarLocalizacao(),
      _carregarCategorias(),
    ]);
  }

  Future<void> _carregarCategorias() async {
    try {
      _categorias = await _categoriasService.obterCategorias();
      notifyListeners();
    } catch (e) {
      onError?.call('Falha ao carregar categorias: $e');
    }
  }

  Future<void> _buscarLocalizacao() async {
    _carregando = true;
    notifyListeners();
    try {
      Position posicao = await LocationService.obterLocalizacaoAtual();
      String enderecoFormatado = "Morada desconhecida";

      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          posicao.latitude, 
          posicao.longitude
        );

        if (placemarks.isNotEmpty) {
          Placemark lugar = placemarks[0];
          final rua = lugar.thoroughfare ?? '';
          final numero = lugar.subThoroughfare ?? '';
          final cidade = lugar.subAdministrativeArea ?? lugar.locality ?? '';
          
          enderecoFormatado = '$rua, $numero - $cidade'.trim();
          
          if (enderecoFormatado == ',' || enderecoFormatado == ',-' || enderecoFormatado.startsWith(', -') || enderecoFormatado.trim() == '-') {
            enderecoFormatado = "GPS Ativo (Rua não identificada)";
          }
        }
      } catch (geoErro) {
        enderecoFormatado = "Coordenadas: ${posicao.latitude.toStringAsFixed(4)}, ${posicao.longitude.toStringAsFixed(4)}";
      }

      _posicaoAtual = posicao;
      _enderecoAtual = enderecoFormatado;
    } catch (e) {
      onError?.call(e.toString());
    } finally {
      _carregando = false;
      notifyListeners();
    }
  }

  Future<void> solicitarProfissional() async {
    if (_categoriaSelecionada == null || _posicaoAtual == null) return;

    _isProcurando = true;
    notifyListeners();

    try {
      // 1. Cria o chamado no servidor PRIMEIRO (Evita race condition)
      final chamadoId = await _chamadosService.criarChamado(
        categoria: _categoriaSelecionada!,
        descricao: _descricaoProblema,
        latitude: _posicaoAtual!.latitude,
        longitude: _posicaoAtual!.longitude,
      );

      _idChamadoAtual = chamadoId;

      // 2. SÓ DEPOIS do chamado ser criado é que o socket e o timer começam
      SocketService().ouvirAtualizacoesChamado(_onAtualizacaoChamado);
      _iniciarContador();
      
      notifyListeners();
    } catch (e) {
      _isProcurando = false;
      notifyListeners();
      onError?.call(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _iniciarContador() {
    _segundosRestantes = 90;
    _cooldownTimer?.cancel();
    
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_segundosRestantes > 0) {
        _segundosRestantes--;
        notifyListeners();
      } else {
        timer.cancel();
        _finalizarBuscaPorTimeout();
      }
    });
  }

  void _finalizarBuscaPorTimeout() {
    _cooldownTimer?.cancel();
    SocketService().pararDeOuvir();

    if (_idChamadoAtual != null) {
      _chamadosService.cancelarChamado(_idChamadoAtual!).catchError((e) {
        debugPrint('Aviso: falha ao cancelar chamado no timeout: $e');
      });
    }

    _isProcurando = false;
    _idChamadoAtual = null;
    notifyListeners();
    
    onTimeout?.call();
  }

  Future<void> cancelarBuscaManualmente() async {
    _cooldownTimer?.cancel();
    SocketService().pararDeOuvir();

    if (_idChamadoAtual != null) {
      try {
        await _chamadosService.cancelarChamado(_idChamadoAtual!);
      } catch (e) {
        onError?.call('Aviso: $e');
      }
    }

    _isProcurando = false;
    _categoriaSelecionada = null;
    _idChamadoAtual = null;
    notifyListeners();
  }

  void _onAtualizacaoChamado(Map<String, dynamic> data) {
    if (data['status_novo'] == 'a_caminho' && data['chamado_id'] == _idChamadoAtual) {
      _cooldownTimer?.cancel();
      SocketService().pararDeOuvir();
      
      _isProcurando = false;
      notifyListeners();
      
      onSuccess?.call(data);
    }
  }

  void resetarEstado() {
    _categoriaSelecionada = null;
    _idChamadoAtual = null;
    _isProcurando = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }
}
