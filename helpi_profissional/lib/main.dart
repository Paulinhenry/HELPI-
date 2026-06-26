import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

// Importa os teus ficheiros
import 'core/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/chamados/screens/mapa_rota_screen.dart';
import 'services/chamado_service.dart';
import 'services/socket_service.dart'; 
import 'features/pagamentos/screens/pagamento_confirmado_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final authProvider = AuthProvider();
  await authProvider
      .checkLoginStatus(); // Vai ver se a sessão já existe na memória

  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider.value(value: authProvider)],
      child: const HelpiProfissionalApp(),
    ),
  );
}

class HelpiProfissionalApp extends StatelessWidget {
  const HelpiProfissionalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Helpi Profissional',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.black,
      ),
      // O Roteador Dinâmico (com Crash Recovery):
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          if (auth.isAuthenticated) {
            // CRASH RECOVERY: Se o servidor disse que há corrida ativa,
            // atira direto para o mapa (ex: bateria morreu no meio do chamado)
            if (auth.chamadoAtivo != null) {
              final c = auth.chamadoAtivo!;
              // Limpa o estado para não criar loop se o profissional
              // voltar atrás do mapa e o widget rebuildar
              WidgetsBinding.instance.addPostFrameCallback((_) {
                auth.limparChamadoAtivo();
              });
              return MapaRotaScreen(
                chamadoId: c['id'].toString(),
                latitudeDestino: double.parse(c['latitude_destino'].toString()),
                longitudeDestino: double.parse(c['longitude_destino'].toString()),
                categoria: c['categoria_solicitada'] ?? '',
                descricao: c['problema_descricao'] ?? '',
                clienteId: c['cliente_id']?.toString(),
              );
            }
            return RadarScreen(profissionalId: auth.profissionalId!);
          }
          return const LoginScreen();
        },
      ),
    );
  }
}

// --- O TEU ECRÃ DE RADAR AGORA USA O ID REAL ---
class RadarScreen extends StatefulWidget {
  final String profissionalId; // Exigimos o ID real agora!

  const RadarScreen({super.key, required this.profissionalId});

  @override
  State<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends State<RadarScreen> with SingleTickerProviderStateMixin {
  final SocketService _socketService = SocketService();
  bool _isOnline = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _toggleModoTrabalho() {
    setState(() {
      _isOnline = !_isOnline;
      if (_isOnline) {
        _pulseController.repeat();
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    });

    if (_isOnline) {
      WakelockPlus.enable();
      _socketService.ligarRadar(
        widget.profissionalId,
        _mostrarAlertaDeTrabalho,
        onPagamentoConfirmado: (dados) {
          if (!mounted) return;
          final valor = double.tryParse(dados['valor']?.toString() ?? '0') ?? 0.0;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PagamentoConfirmadoScreen(valor: valor),
            ),
          );
        },
      );
    } else {
      WakelockPlus.disable();
      _socketService.desligarRadar();
    }
  }

  void _mostrarAlertaDeTrabalho(Map<String, dynamic> dados) async {
    FlutterRingtonePlayer().playAlarm();

    bool? hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      Vibration.vibrate(
        pattern: [500, 1000, 500, 1000],
      );
    }

    if (!mounted) return;

    final chamadoId = dados['chamado_id']?.toString() ?? '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF161A22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '🚨 NOVO SERVIÇO!',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Categoria: ${dados['categoria']}\nProblema: ${dados['descricao']}\nDistância: ${dados['distancia_metros']}m',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.attach_money_rounded, color: Colors.greenAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Referência: R\$ ${dados['valor_estimado_min'] ?? '--'} - R\$ ${dados['valor_estimado_max'] ?? '--'}',
                      style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              FlutterRingtonePlayer().stop();
              Navigator.pop(dialogContext);
            },
            child: const Text('RECUSAR', style: TextStyle(color: Colors.redAccent)),
          ),
          ElevatedButton(
            onPressed: () async {
              FlutterRingtonePlayer().stop();
              Navigator.pop(dialogContext);

              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Row(
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text('A aceitar o chamado...'),
                    ],
                  ),
                  backgroundColor: Color(0xFF1B55D6),
                  duration: Duration(seconds: 10),
                ),
              );

              try {
                final chamadoService = ChamadoService();
                final chamado = await chamadoService.aceitarChamado(chamadoId);

                if (!mounted) return;
                ScaffoldMessenger.of(context).hideCurrentSnackBar();

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MapaRotaScreen(
                      chamadoId: chamado['id'].toString(),
                      latitudeDestino: double.parse(chamado['latitude_destino'].toString()),
                      longitudeDestino: double.parse(chamado['longitude_destino'].toString()),
                      categoria: chamado['categoria_solicitada'] ?? dados['categoria'] ?? '',
                      descricao: chamado['problema_descricao'] ?? dados['descricao'] ?? '',
                      clienteId: chamado['cliente_id']?.toString(),
                      valorEstimadoMin: dados['valor_estimado_min'] != null ? double.tryParse(dados['valor_estimado_min'].toString()) : null,
                      valorEstimadoMax: dados['valor_estimado_max'] != null ? double.tryParse(dados['valor_estimado_max'].toString()) : null,
                    ),
                  ),
                );
              } on ChamadoJaAceitoException catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('😞 $e'), backgroundColor: Colors.orange[800], duration: const Duration(seconds: 4)),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.redAccent, duration: const Duration(seconds: 4)),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.greenAccent[700],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('ACEITAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nome = context.read<AuthProvider>().nome ?? 'Profissional';
    const Color darkBg = Color(0xFF0B0E14);
    const Color darkCard = Color(0xFF161A22);
    const Color mockupBlue = Color(0xFF1B55D6);
    const Color activeGreen = Color(0xFF00E676);
    
    return Scaffold(
      backgroundColor: darkBg,
      body: SafeArea(
        child: Column(
          children: [
            // Custom AppBar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: mockupBlue,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.build_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Olá, $nome!',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _isOnline ? 'Disponível para chamados' : 'Atualmente offline',
                          style: TextStyle(
                            color: _isOnline ? activeGreen : Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.exit_to_app_rounded, color: Colors.white54),
                    onPressed: () {
                      _socketService.desligarRadar();
                      context.read<AuthProvider>().logout();
                    },
                  ),
                ],
              ),
            ),

            // Top Cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: darkCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.work_rounded, color: Colors.orange, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text('Chamados hoje', style: TextStyle(color: Colors.white54, fontSize: 10)),
                              Text('0', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: darkCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: (_isOnline ? activeGreen : Colors.redAccent).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.satellite_alt_rounded, color: _isOnline ? activeGreen : Colors.redAccent, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Status', style: TextStyle(color: Colors.white54, fontSize: 10)),
                              Text(
                                _isOnline ? 'Online' : 'Offline',
                                style: TextStyle(
                                  color: _isOnline ? activeGreen : Colors.redAccent,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Radar Button
            GestureDetector(
              onTap: _toggleModoTrabalho,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // Efeito Radar (Sonar Pulse) com 3 anéis
                      if (_isOnline)
                        ...List.generate(3, (index) {
                          // Atraso de tempo para cada anel criar o efeito de ondas
                          final delay = index * 0.33;
                          var progress = _pulseController.value - delay;
                          if (progress < 0) progress += 1.0;
                          
                          // Opacidade diminui à medida que o raio aumenta
                          final opacity = (1.0 - progress).clamp(0.0, 1.0);
                          
                          return Opacity(
                            opacity: opacity,
                            child: Container(
                              width: 200 + (progress * 180), // Expande de 200 até 380
                              height: 200 + (progress * 180),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: activeGreen.withValues(alpha: 0.15),
                                border: Border.all(
                                  color: activeGreen,
                                  width: 2,
                                ),
                              ),
                            ),
                          );
                        }),
                      // Core Button
                      Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isOnline ? activeGreen : darkCard,
                          boxShadow: _isOnline
                              ? [BoxShadow(color: activeGreen.withValues(alpha: 0.6), blurRadius: 40, spreadRadius: 10)]
                              : [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20)],
                          border: Border.all(
                            color: _isOnline ? Colors.white.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.satellite_alt_rounded,
                              size: 48,
                              color: _isOnline ? Colors.black87 : Colors.white54,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _isOnline ? 'ONLINE' : 'OFFLINE',
                              style: TextStyle(
                                color: _isOnline ? Colors.black87 : Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2.0,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _isOnline ? 'Toque para parar' : 'Toque para iniciar',
                              style: TextStyle(
                                color: _isOnline ? Colors.black54 : Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            const Spacer(),

            // Bottom Alert
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: darkCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isOnline ? activeGreen.withValues(alpha: 0.3) : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.notifications_active_rounded,
                      color: _isOnline ? Colors.amber : Colors.white38,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        _isOnline
                            ? 'Radar ativo! Você será notificado ao receber um chamado próximo.'
                            : 'Radar inativo. Fique online para receber novos chamados na sua região.',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
