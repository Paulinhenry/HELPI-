import 'package:flutter/material.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/home_screen.dart';

void main() {
  runApp(const HelpiApp());
}

class HelpiApp extends StatelessWidget {
  const HelpiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
  title: 'Helpi',
  debugShowCheckedModeBanner: false,
  theme: ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blueAccent,
    ),
    useMaterial3: true,
  ),

  routes: {
    '/home': (context) => const HomeScreen(),
  },

  home: const LoginScreen(),
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
