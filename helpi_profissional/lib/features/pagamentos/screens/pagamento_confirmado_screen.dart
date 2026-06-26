import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';

class PagamentoConfirmadoScreen extends StatelessWidget {
  final double valor;

  const PagamentoConfirmadoScreen({super.key, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              
              // Ícone animado (fallback para ícone normal se não tivermos Lottie)
              const Center(
                child: Icon(
                  Icons.check_circle_outline,
                  color: Colors.greenAccent,
                  size: 120,
                ),
              ),
              
              const SizedBox(height: 32),
              
              const Text(
                'Pagamento Recebido!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 16),
              
              Text(
                'O valor de R\$ ${valor.toStringAsFixed(2)} foi creditado na sua conta Mercado Pago.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              
              const Spacer(),
              
              ElevatedButton(
                onPressed: () {
                  context.read<AuthProvider>().limparChamadoAtivo();
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF448AFF),
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'VOLTAR AO RADAR',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
