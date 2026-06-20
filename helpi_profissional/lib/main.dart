import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

// Importa os teus ficheiros
import 'core/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'services/socket_service.dart'; // O ficheiro que te dei na resposta anterior

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final authProvider = AuthProvider();
  await authProvider.checkLoginStatus(); // Vai ver se a sessão já existe na memória

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
      // O Roteador Dinâmico:
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          if (auth.isAuthenticated) {
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
      _socketService.ligarRadar(widget.profissionalId, _mostrarAlertaDeTrabalho);
    } else {
      // Permite que o ecrã volte a desligar normalmente
      WakelockPlus.disable();
      
      _socketService.desligarRadar();
    }
  }

  void _mostrarAlertaDeTrabalho(Map<String, dynamic> dados) async {
    // 🔊 Toca o som padrão de notificação do telemóvel
    FlutterRingtonePlayer().playNotification();
    
    // 📳 Faz o telemóvel vibrar
    bool? hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      Vibration.vibrate(pattern: [500, 1000, 500, 1000]); // Vibra, Pausa, Vibra, Pausa
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🚨 NOVO SERVIÇO!', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Categoria: ${dados['categoria']}\nProblema: ${dados['descricao']}\nDistância: ${dados['distancia_metros']}m'),
        actions: [
          TextButton(
             onPressed: () {
               FlutterRingtonePlayer().stop(); // Para o som se ainda estiver a tocar
               Navigator.pop(context);
             },
             child: const Text('RECUSAR', style: TextStyle(color: Colors.red))
          ),
          ElevatedButton(
             onPressed: () {
               FlutterRingtonePlayer().stop();
               Navigator.pop(context);
               // TODO: Logica de aceitar o serviço (chamada API PUT /aceitar)
             },
             style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
             child: const Text('ACEITAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
          )
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
          )
        ],
      ),
      body: Center(
        child: GestureDetector(
          onTap: _toggleModoTrabalho,
          child: Container(
            width: 200, height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isOnline ? Colors.blue : Colors.grey[800],
              boxShadow: [
                BoxShadow(
                  color: (_isOnline ? Colors.blue : Colors.grey[800]!).withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: 5,
                )
              ]
            ),
            child: Center(
              child: Text(
                _isOnline ? 'FICAR\nOFFLINE' : 'FICAR\nONLINE',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
