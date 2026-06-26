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
import 'services/socket_service.dart'; // O ficheiro que te dei na resposta anterior

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
                latitudeDestino: (c['latitude_destino'] as num).toDouble(),
                longitudeDestino: (c['longitude_destino'] as num).toDouble(),
                categoria: c['categoria_solicitada'] ?? '',
                descricao: c['problema_descricao'] ?? '',
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

class _RadarScreenState extends State<RadarScreen> {
  final SocketService _socketService = SocketService();
  bool _isOnline = false;

  void _toggleModoTrabalho() {
    setState(() => _isOnline = !_isOnline);

    if (_isOnline) {
      // Impede o ecrã de desligar enquanto estiver à espera de pedidos
      WakelockPlus.enable();

      // LIGA O RADAR COM O ID REAL DA TUA BASE DE DADOS POSTGRESQL!
      _socketService.ligarRadar(
        widget.profissionalId,
        _mostrarAlertaDeTrabalho,
      );
    } else {
      // Permite que o ecrã volte a desligar normalmente
      WakelockPlus.disable();

      _socketService.desligarRadar();
    }
  }

  void _mostrarAlertaDeTrabalho(Map<String, dynamic> dados) async {
    // 🔊 Toca o alarme do telemóvel (ignora o modo silencioso e toca alto)
    FlutterRingtonePlayer().playAlarm();

    // 📳 Faz o telemóvel vibrar
    bool? hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      Vibration.vibrate(
        pattern: [500, 1000, 500, 1000],
      ); // Vibra, Pausa, Vibra, Pausa
    }

    if (!mounted) return;

    final chamadoId = dados['chamado_id']?.toString() ?? '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          '🚨 NOVO SERVIÇO!',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Categoria: ${dados['categoria']}\nProblema: ${dados['descricao']}\nDistância: ${dados['distancia_metros']}m',
        ),
        actions: [
          TextButton(
            onPressed: () {
              FlutterRingtonePlayer()
                  .stop(); // Para o som se ainda estiver a tocar
              Navigator.pop(dialogContext);
            },
            child: const Text('RECUSAR', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () async {
              FlutterRingtonePlayer().stop();

              // Fecha o popup imediatamente (UX rápida)
              Navigator.pop(dialogContext);

              // Mostra feedback visual enquanto chama a API
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
                  backgroundColor: Color(0xFF1565C0),
                  duration: Duration(seconds: 10),
                ),
              );

              try {
                // Chama o backend: PUT /chamados/:id/aceitar
                final chamadoService = ChamadoService();
                final chamado = await chamadoService.aceitarChamado(chamadoId);

                if (!mounted) return;
                ScaffoldMessenger.of(context).hideCurrentSnackBar();

                // Navega para a tela de mapa com as coordenadas do cliente
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MapaRotaScreen(
                      chamadoId: chamado['id'].toString(),
                      latitudeDestino: (chamado['latitude_destino'] as num).toDouble(),
                      longitudeDestino: (chamado['longitude_destino'] as num).toDouble(),
                      categoria: chamado['categoria_solicitada'] ?? dados['categoria'] ?? '',
                      descricao: chamado['problema_descricao'] ?? dados['descricao'] ?? '',
                    ),
                  ),
                );
              } on ChamadoJaAceitoException catch (e) {
                // Outro profissional foi mais rápido (race condition)
                if (!mounted) return;
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('😞 $e'),
                    backgroundColor: Colors.orange[800],
                    duration: const Duration(seconds: 4),
                  ),
                );
              } catch (e) {
                // Erro genérico
                if (!mounted) return;
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Erro: $e'),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 4),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text(
              'ACEITAR',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nome = context.read<AuthProvider>().nome ?? 'Profissional';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Olá, $nome', style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.blue),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              _socketService.desligarRadar();
              context.read<AuthProvider>().logout();
            },
          ),
        ],
      ),
      body: Center(
        child: GestureDetector(
          onTap: _toggleModoTrabalho,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isOnline ? Colors.blue : Colors.grey[800],
              boxShadow: [
                BoxShadow(
                  color: (_isOnline ? Colors.blue : Colors.grey[800]!)
                      .withValues(alpha: 0.5),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Center(
              child: Text(
                _isOnline ? 'FICAR\nOFFLINE' : 'FICAR\nONLINE',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
