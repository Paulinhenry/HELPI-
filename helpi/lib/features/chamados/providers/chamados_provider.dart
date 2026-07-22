import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import '../../../core/services/location_service.dart';
import '../../../core/services/socket_service.dart';
import '../services/chamados_service.dart';
import '../services/categorias_service.dart';
import '../../pagamentos/services/pagamento_service.dart';
import '../../../core/services/foreground_notification_service.dart';

class ChamadosProvider with ChangeNotifier {
  final ChamadosService _chamadosService = ChamadosService();
  final CategoriasService _categoriasService = CategoriasService();
  final PagamentoService _pagamentoService = PagamentoService();

  Timer? _debounceEstimativa;

  Position? _posicaoAtual;
  bool _carregando = true;
  String _enderecoAtual = "A procurar morada...";
  
  List<Map<String, dynamic>> _categorias = [];
  String? _categoriaSelecionada;
  bool _isProcurando = false;
  String? _idChamadoAtual;
  String _descricaoProblema = "Emergência urgente solicitada via Helpi App";
  
  // Estimativas
  int? _estimativaMin;
  int? _estimativaMax;
  int? _estimativaSugerida;
  bool _calculandoEstimativa = false;

  // Tracking do Profissional
  bool _isProfissionalACaminho = false;
  Position? _posicaoProfissional;
  String _nomeProfissional = "";
  String _distanciaProfissional = "";

  Timer? _cooldownTimer;
  int _segundosRestantes = 90;

  // Callbacks for UI
  Function()? onTimeout;
  Function(Map<String, dynamic>)? onSuccess;
  Function(String)? onError;
  Function(Map<String, dynamic>)? onServicoFinalizado;

  Position? get posicaoAtual => _posicaoAtual;
  bool get carregando => _carregando;
  String get enderecoAtual => _enderecoAtual;
  List<Map<String, dynamic>> get categorias => _categorias;
  String? get categoriaSelecionada => _categoriaSelecionada;
  bool get isProcurando => _isProcurando;
  String? get idChamadoAtual => _idChamadoAtual;
  int get segundosRestantes => _segundosRestantes;
  String get descricaoProblema => _descricaoProblema;
  
  int? get estimativaMin => _estimativaMin;
  int? get estimativaMax => _estimativaMax;
  int? get estimativaSugerida => _estimativaSugerida;
  bool get calculandoEstimativa => _calculandoEstimativa;
  
  bool get isProfissionalACaminho => _isProfissionalACaminho;
  Position? get posicaoProfissional => _posicaoProfissional;
  String get nomeProfissional => _nomeProfissional;
  String get distanciaProfissional => _distanciaProfissional;

  void setCategoria(String? categoria) {
    _categoriaSelecionada = categoria;
    notifyListeners();
    _atualizarEstimativa();
  }

  void setDescricao(String descricao) {
    if (descricao.trim().isNotEmpty) {
      _descricaoProblema = descricao;
      notifyListeners();
      _atualizarEstimativa();
    }
  }

  void _atualizarEstimativa() {
    if (_categoriaSelecionada == null || _descricaoProblema.isEmpty) return;

    if (_debounceEstimativa?.isActive ?? false) _debounceEstimativa!.cancel();

    _calculandoEstimativa = true;
    notifyListeners();

    _debounceEstimativa = Timer(const Duration(milliseconds: 800), () async {
      try {
        final estimativa = await _pagamentoService.estimarPreco(_categoriaSelecionada!, _descricaoProblema);
        _estimativaMin = estimativa['preco_minimo'];
        _estimativaMax = estimativa['preco_maximo'];
        _estimativaSugerida = estimativa['preco_sugerido'];
      } catch (e) {
        debugPrint('Erro ao estimar preço: $e');
        _estimativaMin = null;
        _estimativaMax = null;
        _estimativaSugerida = null;
      } finally {
        _calculandoEstimativa = false;
        notifyListeners();
      }
    });
  }

  Future<void> inicializar() async {
    await Future.wait([
      _buscarLocalizacao(),
      _carregarCategorias(),
      _verificarChamadoAtivo(), // Crash Recovery
    ]);
  }

  Future<void> sincronizarEstadoServidor() async {
    await _verificarChamadoAtivo();
  }

  Future<void> _verificarChamadoAtivo() async {
    try {
      final ativo = await _chamadosService.verificarChamadoAtivo();
      if (ativo != null) {
        _idChamadoAtual = ativo['id'];
        _categoriaSelecionada = ativo['categoria_solicitada'];
        _descricaoProblema = ativo['problema_descricao'];

        final status = ativo['status'];
        if (status == 'procurando_profissional') {
          _isProcurando = true;
          // Iniciar timer visual (dummy) e conectar sockets se necessário
          SocketService().ouvirAtualizacoesChamado(_onAtualizacaoChamado);
          ForegroundNotificationService().iniciarProcurando();
        } else if (status == 'a_caminho' || status == 'em_servico') {
          _isProcurando = false;
          _isProfissionalACaminho = true;
          _nomeProfissional = ativo['profissional_nome'] ?? 'O Profissional';
          _distanciaProfissional = 'Em andamento';
          
          SocketService().ouvirAtualizacoesChamado(_onAtualizacaoChamado);
          SocketService().ouvirLocalizacaoProfissional(_onLocalizacaoProfissional);
          ForegroundNotificationService().atualizarParaACaminho(_nomeProfissional);
        } else if (status == 'finalizado') {
          ForegroundNotificationService().parar();
          final pgStatus = ativo['pagamento_status'];
          if (pgStatus == 'pendente' || pgStatus == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              onServicoFinalizado?.call(ativo);
            });
          }
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[CrashRecovery] Erro ao recuperar chamado: $e');
    }
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
      ForegroundNotificationService().iniciarProcurando();
      
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
    SocketService().pararDeOuvirLocalizacao();

    if (_idChamadoAtual != null) {
      _chamadosService.cancelarChamado(_idChamadoAtual!).catchError((e) {
        debugPrint('Aviso: falha ao cancelar chamado no timeout: $e');
      });
    }

    _isProcurando = false;
    _isProfissionalACaminho = false;
    _idChamadoAtual = null;
    ForegroundNotificationService().parar();
    notifyListeners();
    
    onTimeout?.call();
  }

  Future<void> cancelarBuscaManualmente() async {
    _cooldownTimer?.cancel();
    SocketService().pararDeOuvir();
    SocketService().pararDeOuvirLocalizacao();

    if (_idChamadoAtual != null) {
      try {
        await _chamadosService.cancelarChamado(_idChamadoAtual!);
      } catch (e) {
        onError?.call('Aviso: $e');
      }
    }

    _isProcurando = false;
    _isProfissionalACaminho = false;
    _categoriaSelecionada = null;
    _idChamadoAtual = null;
    ForegroundNotificationService().parar();
    notifyListeners();
  }

  void _onAtualizacaoChamado(Map<String, dynamic> data) {
    if (data['status_novo'] == 'a_caminho' && data['chamado_id'] == _idChamadoAtual) {
      _cooldownTimer?.cancel();
      // Mantemos o socket do chamado para ouvir quando for 'em_servico' ou 'finalizado'
      
      _isProcurando = false;
      _isProfissionalACaminho = true;
      _nomeProfissional = data['profissional_nome'] ?? 'O Profissional';
      _distanciaProfissional = data['distancia_texto'] ?? 'A caminho';
      
      // Inicia a escuta da localização em tempo real
      SocketService().ouvirLocalizacaoProfissional(_onLocalizacaoProfissional);
      ForegroundNotificationService().atualizarParaACaminho(_nomeProfissional);
      
      notifyListeners();
      
      onSuccess?.call(data);
    } else if (data['status_novo'] == 'cancelado' && data['chamado_id'] == _idChamadoAtual) {
      // Se for cancelado, resetamos tudo
      resetarEstado();
    } else if (data['status_novo'] == 'finalizado' && data['chamado_id'] == _idChamadoAtual) {
      ForegroundNotificationService().parar();
      // Quando finalizado, vamos transitar para a Caixa Registadora (Checkout)
      onServicoFinalizado?.call(data);
    }
  }

  void _onLocalizacaoProfissional(Map<String, dynamic> data) {
    if (data['latitude'] != null && data['longitude'] != null) {
      _posicaoProfissional = Position(
        latitude: data['latitude'],
        longitude: data['longitude'],
        timestamp: DateTime.now(),
        accuracy: 0.0, altitude: 0.0, altitudeAccuracy: 0.0, heading: 0.0, headingAccuracy: 0.0, speed: 0.0, speedAccuracy: 0.0,
      );
      notifyListeners();
    }
  }

  void resetarEstado() {
    _categoriaSelecionada = null;
    _idChamadoAtual = null;
    _isProcurando = false;
    _isProfissionalACaminho = false;
    _posicaoProfissional = null;
    _estimativaMin = null;
    _estimativaMax = null;
    _estimativaSugerida = null;
    SocketService().pararDeOuvirLocalizacao();
    ForegroundNotificationService().parar();
    notifyListeners();
  }

  @override
  void dispose() {
    _debounceEstimativa?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }
}
