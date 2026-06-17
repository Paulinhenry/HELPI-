import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

// Importação do AuthProvider para gerir o estado de login
import '../../../core/providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final senhaController = TextEditingController();
  bool _carregando = false;

  Future<void> fazerLogin() async {
    setState(() => _carregando = true);

    try {
      final response = await http.post(
        Uri.parse('http://localhost:3000/api/login/clientes'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': emailController.text,
          'senha': senhaController.text,
        }),
      );

      debugPrint('Status: ${response.statusCode}');
      debugPrint('Body: ${response.body}');

      if (response.statusCode == 200) {
        final dados = jsonDecode(response.body);
        final token = dados['token'];

        // Usa o AuthProvider para guardar o token e trocar de ecrã automaticamente
        // O Consumer no main.dart vai detetar a mudança e mostrar o MapaScreen
        if (mounted) {
          await context.read<AuthProvider>().login(token);
        }

        debugPrint('LOGIN EFETUADO COM SUCESSO');
      } else {
        // Mostra mensagem de erro se o login falhar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('E-mail ou senha incorretos.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // Erro de rede (servidor desligado, sem internet, etc.)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro de ligação: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HELPI'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 40),

            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: senhaController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Senha',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _carregando ? null : () async {
                  await fazerLogin();
                },
                child: _carregando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Entrar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}