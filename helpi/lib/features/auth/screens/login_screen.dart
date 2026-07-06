import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../services/auth_service.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _carregando = false;
  bool _senhaVisivel = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.1, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> _fazerLogin() async {
    if (_emailController.text.isEmpty || _senhaController.text.isEmpty) {
      _mostrarErro('Preencha todos os campos');
      return;
    }
    if (!_emailController.text.contains('@') ||
        !_emailController.text.contains('.')) {
      _mostrarErro('E-mail inválido');
      return;
    }

    HapticFeedback.mediumImpact();
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
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(mensagem)),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg0,
      body: Stack(
        children: [
          // ── Background gradient ──────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF060C15),
                  Color(0xFF0B1120),
                  Color(0xFF0F1A2C),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // ── Glow orbs ─────────────────────────────────────────────────
          Positioned(
            top: -120,
            right: -80,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -100,
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.accent.withValues(alpha: 0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── Main content ──────────────────────────────────────────────
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: AnimatedBuilder(
                  animation: _animController,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _fadeAnim,
                      child: SlideTransition(
                        position: _slideAnim,
                        child: child,
                      ),
                    );
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 32),

                      // ── LOGO ────────────────────────────────────────
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: AppColors.primaryGlowShadow,
                        ),
                        child: const Icon(
                          Icons.bolt_rounded,
                          color: Colors.white,
                          size: 44,
                        ),
                      ),
                      const SizedBox(height: 20),

                      Text(
                        'HELPI',
                        style: GoogleFonts.inter(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 5.0,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'A ajuda que precisava, agora.',
                        style: AppTextStyles.bodyM,
                      ),
                      const SizedBox(height: 40),

                      // ── GLASSMORPHISM CARD ───────────────────────────
                      ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: BackdropFilter(
                          filter:
                              ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Container(
                            decoration: BoxDecoration(
                              color:
                                  Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color:
                                    Colors.white.withValues(alpha: 0.09),
                              ),
                            ),
                            padding: const EdgeInsets.all(28),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment:
                                  CrossAxisAlignment.stretch,
                              children: [
                                Text('Bem-vindo(a)', style: AppTextStyles.h1),
                                const SizedBox(height: 4),
                                Text('Entre na sua conta',
                                    style: AppTextStyles.bodyM),
                                const SizedBox(height: 28),

                                // Email field
                                _buildInputField(
                                  controller: _emailController,
                                  label: 'E-mail',
                                  hint: 'seu@email.com',
                                  icon: Icons.email_outlined,
                                  keyboardType: TextInputType.emailAddress,
                                ),
                                const SizedBox(height: 14),

                                // Password field
                                _buildInputField(
                                  controller: _senhaController,
                                  label: 'Senha',
                                  hint: '••••••••',
                                  icon: Icons.lock_outline_rounded,
                                  obscureText: !_senhaVisivel,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _senhaVisivel
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: AppColors.textTertiary,
                                      size: 20,
                                    ),
                                    onPressed: () => setState(
                                        () => _senhaVisivel = !_senhaVisivel),
                                  ),
                                ),

                                const SizedBox(height: 10),

                                // Forgot password
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () {},
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Text(
                                      'Esqueceu a senha?',
                                      style: GoogleFonts.inter(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // Login button
                                _buildLoginButton(),
                                const SizedBox(height: 22),

                                // Divider
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                          height: 1,
                                          color: AppColors.border),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12),
                                      child: Text('ou',
                                          style: AppTextStyles.labelM),
                                    ),
                                    Expanded(
                                      child: Container(
                                          height: 1,
                                          color: AppColors.border),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),

                                // Register link
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Não tem conta? ',
                                      style: AppTextStyles.bodyM,
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const RegisterScreen(),
                                          ),
                                        );
                                      },
                                      child: Text(
                                        'Criar agora',
                                        style: GoogleFonts.inter(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
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
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg3,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Icon(icon, color: AppColors.textTertiary, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscureText,
              keyboardType: keyboardType,
              style: GoogleFonts.inter(
                  color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                labelText: label,
                labelStyle: GoogleFonts.inter(
                    color: AppColors.textTertiary, fontSize: 13),
                hintText: hint,
                hintStyle: GoogleFonts.inter(
                    color: AppColors.textDisabled, fontSize: 13),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 14),
                suffixIcon: suffixIcon,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginButton() {
    return GestureDetector(
      onTap: _carregando ? null : _fazerLogin,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 56,
        decoration: BoxDecoration(
          gradient: _carregando
              ? LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.6),
                    AppColors.accent.withValues(alpha: 0.6),
                  ],
                )
              : AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _carregando ? [] : AppColors.primaryGlowShadow,
        ),
        child: Center(
          child: _carregando
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Text(
                  'ENTRAR',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}