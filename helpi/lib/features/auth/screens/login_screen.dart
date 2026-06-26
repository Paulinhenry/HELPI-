import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../services/auth_service.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _carregando = false;
  bool _senhaVisivel = false;

  Future<void> _fazerLogin() async {
    if (_emailController.text.isEmpty || _senhaController.text.isEmpty) {
      _mostrarErro('Preencha todos os campos');
      return;
    }

    if (!_emailController.text.contains('@') || !_emailController.text.contains('.')) {
      _mostrarErro('E-mail inválido');
      return;
    }

    setState(() => _carregando = true);

    try {
      final tokens = await _authService.loginCliente(
        _emailController.text.trim(),
        _senhaController.text.trim(),
      );

      if (tokens != null && mounted) {
        final accessToken = tokens['access_token']?.toString() ?? '';
        final refreshToken = tokens['refresh_token']?.toString() ?? '';
        await context.read<AuthProvider>().login(accessToken, refreshToken);
      }
    } catch (e) {
      if (mounted) {
        _mostrarErro(e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _mostrarErro(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // Cor azul premium do mockup
    const Color mockupBlue = Color(0xFF1B55D6); 

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Fundo Azul Metade Superior
          Container(
            height: size.height * 0.55,
            width: double.infinity,
            decoration: const BoxDecoration(
              color: mockupBlue,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            child: const SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.favorite_border_rounded,
                    size: 64,
                    color: Colors.white,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'HELPI',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 4.0,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Profissionais ao seu serviço',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 80), // Espaço para o card sobreposto
                ],
              ),
            ),
          ),
          
          // Card de Login Sobreposto
          Align(
            alignment: Alignment.bottomCenter,
            child: SingleChildScrollView(
              child: Container(
                margin: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Bem-vindo de volta',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Entre na sua conta para continuar',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Campo de E-mail
                    _buildTextField(
                      controller: _emailController,
                      hintText: 'seu@email.com',
                      label: 'E-mail',
                      iconData: Icons.email, // Ícone simulado com container quadrado
                      keyboardType: TextInputType.emailAddress,
                      iconColor: mockupBlue,
                    ),
                    const SizedBox(height: 16),

                    // Campo de Senha
                    _buildTextField(
                      controller: _senhaController,
                      hintText: '••••••••',
                      label: 'Senha',
                      iconData: Icons.lock,
                      obscureText: !_senhaVisivel,
                      iconColor: Colors.blueGrey,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _senhaVisivel ? Icons.visibility : Icons.visibility_off,
                          color: Colors.black38,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _senhaVisivel = !_senhaVisivel;
                          });
                        },
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Esqueceu a senha
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {},
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Esqueceu a senha?',
                          style: TextStyle(
                            color: mockupBlue,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Botão Entrar
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: mockupBlue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _carregando ? null : _fazerLogin,
                        child: _carregando
                            ? const SizedBox(
                                width: 24, height: 24,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                'ENTRAR',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Criar conta
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Não tem uma conta? ',
                          style: TextStyle(color: Colors.black54, fontSize: 13),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const RegisterScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            'Criar agora',
                            style: TextStyle(
                              color: mockupBlue,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
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
    required String hintText,
    required IconData iconData,
    required Color iconColor,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Ícone Quadrado Colorido
          Padding(
            padding: const EdgeInsets.only(left: 12.0, top: 12, bottom: 12),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconColor,
                borderRadius: BorderRadius.circular(8),
              ),
              // Como os ícones no mockup são apenas quadrados coloridos (azul e cinzento escuro)
              // com o texto ao lado. O mockup não parece ter um ícone dentro do quadrado, apenas a cor.
              // Mas se precisar, o ícone pode ficar aqui. No mockup é só um quadrado arredondado!
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscureText,
              keyboardType: keyboardType,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: const TextStyle(
                  color: Colors.black38,
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                suffixIcon: suffixIcon,
              ),
            ),
          ),
        ],
      ),
    );
  }
}