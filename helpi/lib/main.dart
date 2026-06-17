import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Importações Core (A tua infraestrutura)
import 'core/providers/auth_provider.dart';
import 'core/theme/app_colors.dart';

// Importações Features (As telas da aplicação)
import 'features/chamados/screens/mapa_screen.dart';

void main() {
  runApp(
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
        // Agora usamos as tuas cores centrais!
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primaryColor),
        scaffoldBackgroundColor: AppColors.background,
        useMaterial3: true,
      ),
      // O Roteador Automático
      home: Consumer<AuthProvider>(
        builder: (context, auth, child) {
          if (auth.isLoading) {
            return const TelaSplash();
          }
          if (auth.isLoggedIn) {
            return const MapaScreen();
          }
          // Quando o Victor terminar o LoginScreen, importa e substitui esta linha:
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        },
      ),
    );
  }
}

// O Ecrã de Carregamento mantemos aqui pois é global e super leve
class TelaSplash extends StatelessWidget {
  const TelaSplash({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.primaryColor,
      body: Center(
        child: Text(
          'HELPI',
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            color: AppColors.white,
            letterSpacing: 2.0,
          ),
        ),
      ),
    );
  }
}
