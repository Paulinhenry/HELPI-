import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/providers/auth_provider.dart';

void main() {
  runApp(
    // O MultiProvider envolve a app toda e injeta os "Cérebros"
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider()..checkLoginStatus(),
        ),
      ],
      child: const HelpiApp(),
    ),
  );
}

class HelpiApp extends StatelessWidget {
  const HelpiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Helpi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      // A MÁGICA DO ROTEAMENTO INTELIGENTE:
      // A app "escuta" o AuthProvider e decide que ecrã mostrar.
      home: Consumer<AuthProvider>(
        builder: (context, auth, child) {
          if (auth.isLoading) {
            return const TelaSplash(); // Mostra o logo enquanto procura o token
          }
          if (auth.isLoggedIn) {
            return const TelaMapaProvisoria(); // Vai direto para dentro da app!
          }
          return const TelaLoginProvisoria(); // Vai pedir E-mail e Senha
        },
      ),
    );
  }
}

// Uma tela provisória em branco só para arrancar o motor
class TelaSplash extends StatelessWidget {
  const TelaSplash({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueAccent,
      body: Center(
        child: Text(
          'HELPI',
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 2.0,
          ),
        ),
      ),
    );
  }
}

// Ecrã Provisório 1 (Para testar)
class TelaLoginProvisoria extends StatelessWidget {
  const TelaLoginProvisoria({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Login")),
      body: Center(child: const Text("O Victor está a construir esta página...")),
    );
  }
}

// Ecrã Provisório 2 (Para testar)
class TelaMapaProvisoria extends StatelessWidget {
  const TelaMapaProvisoria({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mapa Helpi"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              // Testa o botão de Sair!
              context.read<AuthProvider>().logout();
            },
          )
        ],
      ),
      body: Center(child: const Text("Aqui vai ficar o Google Maps!")),
    );
  }
}
