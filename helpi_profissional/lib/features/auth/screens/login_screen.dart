import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _isLoading = false;

  Future<void> _fazerLogin() async {
    if (_emailController.text.trim().isEmpty || _senhaController.text.trim().isEmpty) {
      _mostrarErro('Preencha todos os campos');
      return;
    }

    if (!_emailController.text.contains('@') || !_emailController.text.contains('.')) {
      _mostrarErro('E-mail inválido');
      return;
    }

    if (_senhaController.text.length < 6) {
      _mostrarErro('Senha deve ter pelo menos 6 caracteres');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await context.read<AuthProvider>().login(
        _emailController.text.trim(),
        _senhaController.text.trim(),
      );
    } catch (e) {
      if (mounted) {
        _mostrarErro(e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _mostrarErro(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color darkBg = Color(0xFF0B0E14);
    const Color darkCard = Color(0xFF161A22);
    const Color mockupBlue = Color(0xFF1B55D6);

    return Scaffold(
      backgroundColor: darkBg,
      body: Stack(
        children: [
          // Efeito de luz sutil no canto superior esquerdo
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: mockupBlue.withValues(alpha: 0.1),
                boxShadow: [
                  BoxShadow(
                    color: mockupBlue.withValues(alpha: 0.1),
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),
          
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: mockupBlue,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: mockupBlue.withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.build_rounded,
                          size: 36,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'HELPI',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 4.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Área do Profissional',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white54,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Formulário Título
                    const Text(
                      'Entrar no Radar',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Acesse sua conta para receber chamados',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white54,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Email Field
                    _buildTextField(
                      controller: _emailController,
                      label: 'E-mail profissional',
                      iconData: Icons.email_rounded,
                      keyboardType: TextInputType.emailAddress,
                      darkCard: darkCard,
                      mockupBlue: mockupBlue,
                    ),
                    const SizedBox(height: 16),

                    // Senha Field
                    _buildTextField(
                      controller: _senhaController,
                      label: 'Senha',
                      iconData: Icons.lock_rounded,
                      obscureText: true,
                      darkCard: darkCard,
                      mockupBlue: mockupBlue,
                    ),
                    const SizedBox(height: 32),

                    // Botão Entrar
                    SizedBox(
                      height: 56,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: mockupBlue,
                          foregroundColor: Colors.white,
                          elevation: 10,
                          shadowColor: mockupBlue.withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _isLoading ? null : _fazerLogin,
                        icon: _isLoading 
                          ? const SizedBox.shrink() 
                          : const Icon(Icons.sensors, size: 20),
                        label: _isLoading
                            ? const SizedBox(
                                width: 24, height: 24,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                'ENTRAR NO RADAR',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Divisor
                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            'HELPI PRO',
                            style: TextStyle(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2.0),
                          ),
                        ),
                        Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Cards inferiores
                    Row(
                      children: [
                        Expanded(child: _buildFooterCard(Icons.security, 'Seguro', Colors.blue)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildFooterCard(Icons.bolt, 'Tempo real', Colors.amber)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildFooterCard(Icons.star, 'Avaliado', Colors.orange)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData iconData,
    required Color darkCard,
    required Color mockupBlue,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16.0, right: 12.0),
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscureText,
              keyboardType: keyboardType,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: label,
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterCard(IconData icon, String text, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF161A22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 8),
          Text(
            text,
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
