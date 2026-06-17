import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/providers/auth_provider.dart';
import 'features/chamados/screens/mapa_screen.dart';

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
            return const MapaScreen(); // AGORA ESTÁ A CHAMAR O MAPA REAL!
          }
          return const TelaLoginProvisoria(); // Vai pedir E-mail e Senha
        },
      ),
    );
  }
}

// ============================================================
// TELA SPLASH — Ecrã de carregamento inicial com animação
// ============================================================
class TelaSplash extends StatelessWidget {
  const TelaSplash({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1565C0), // Azul escuro
              Color(0xFF448AFF), // Azul vibrante
              Color(0xFF42A5F5), // Azul claro
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ícone principal com sombra
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.health_and_safety_rounded,
                size: 60,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'HELPI',
              style: TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 6.0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Socorro na palma da mão',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.7),
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// TELA LOGIN PROVISÓRIA — Design premium enquanto o Victor
// constrói a versão final com autenticação real
// ============================================================
class TelaLoginProvisoria extends StatelessWidget {
  const TelaLoginProvisoria({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1565C0),
              Color(0xFF0D47A1),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const SizedBox(height: 60),

                // ===== LOGO E MARCA =====
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.health_and_safety_rounded,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'HELPI',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 5.0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Bem-vindo de volta',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 48),

                // ===== CARTÃO DE LOGIN =====
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Iniciar Sessão',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3436),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Insira as suas credenciais para continuar',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Campo E-mail
                      TextField(
                        enabled: false, // Desativado — o Victor vai ativar
                        decoration: InputDecoration(
                          labelText: 'E-mail',
                          hintText: 'seunome@email.com',
                          prefixIcon: Icon(
                            Icons.email_outlined,
                            color: Colors.blueAccent.shade200,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF5F6FA),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Colors.blueAccent,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Campo Senha
                      TextField(
                        enabled: false, // Desativado — o Victor vai ativar
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Senha',
                          hintText: '••••••••',
                          prefixIcon: Icon(
                            Icons.lock_outline_rounded,
                            color: Colors.blueAccent.shade200,
                          ),
                          suffixIcon: Icon(
                            Icons.visibility_off_outlined,
                            color: Colors.grey.shade400,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF5F6FA),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Colors.blueAccent,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Link "Esqueceu a senha?"
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: null,
                          child: Text(
                            'Esqueceu a senha?',
                            style: TextStyle(
                              color: Colors.blueAccent.shade200,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Botão ENTRAR
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: () {
                            // Login de teste — simula um token para entrar no mapa
                            // O Victor vai substituir isto pela chamada real à API
                            context.read<AuthProvider>().login('token_teste_temporario');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            disabledBackgroundColor: Colors.blueAccent.withValues(alpha: 0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'ENTRAR',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // ===== DIVISOR "OU" =====
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'OU',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // ===== BOTÃO CRIAR CONTA =====
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: OutlinedButton(
                    onPressed: null,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'CRIAR NOVA CONTA',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.9),
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // ===== RODAPÉ =====
                Text(
                  'v1.0.0 • Em construção pelo Victor 🛠️',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
