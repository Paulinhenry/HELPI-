import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/network/app_client.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nomeController = TextEditingController();
  final _cpfCnpjController = TextEditingController();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _telefoneController = TextEditingController();
  String? _categoriaSelecionada;
  bool _isLoading = false;

  final List<String> _categorias = [
    'Eletricista',
    'Encanador',
    'Chaveiro',
    'Diarista',
    'Montador',
    'Outros'
  ];

  Future<void> _fazerCadastro() async {
    if (_nomeController.text.trim().isEmpty ||
        _cpfCnpjController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _senhaController.text.trim().isEmpty ||
        _telefoneController.text.trim().isEmpty ||
        _categoriaSelecionada == null) {
      _mostrarErro('Preencha todos os campos obrigatórios.');
      return;
    }

    if (!_emailController.text.contains('@')) {
      _mostrarErro('E-mail inválido.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final apiClient = ApiClient();
      await apiClient.dio.post(
        '/profissionais', // Corresponde ao backend: POST /api/profissionais
        data: {
          'nome': _nomeController.text.trim(),
          'cpf_cnpj': _cpfCnpjController.text.trim(),
          'email': _emailController.text.trim(),
          'senha': _senhaController.text.trim(),
          'telefone': _telefoneController.text.trim(),
          'categoria': _categoriaSelecionada,
        },
      );

      if (mounted) {
        // Sucesso: Profissional registrado aguardando aprovação
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: const Color(0xFF161A22),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('🎉 Sucesso!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            content: const Text(
              'A sua conta foi criada com sucesso.\n\nFicará a aguardar aprovação pela nossa equipa para garantir a segurança da plataforma. \n\nEntraremos em contacto em breve.',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B55D6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(dialogContext); // Fecha dialog
                  Navigator.pop(context); // Volta ao login
                },
                child: const Text('VOLTAR AO LOGIN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        _mostrarErro(e.response?.data['erro'] ?? 'Erro de ligação ao servidor');
      }
    } catch (e) {
      if (mounted) {
        _mostrarErro('Ocorreu um erro inesperado.');
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Junte-se a nós',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Crie a sua conta de profissional e comece a receber chamados na sua área.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white54,
                ),
              ),
              const SizedBox(height: 32),

              _buildTextField(
                controller: _nomeController,
                label: 'Nome Completo',
                iconData: Icons.person_rounded,
                darkCard: darkCard,
                mockupBlue: mockupBlue,
              ),
              const SizedBox(height: 16),

              _buildTextField(
                controller: _cpfCnpjController,
                label: 'CPF / CNPJ',
                iconData: Icons.badge_rounded,
                darkCard: darkCard,
                mockupBlue: mockupBlue,
              ),
              const SizedBox(height: 16),

              _buildTextField(
                controller: _emailController,
                label: 'E-mail profissional',
                iconData: Icons.email_rounded,
                keyboardType: TextInputType.emailAddress,
                darkCard: darkCard,
                mockupBlue: mockupBlue,
              ),
              const SizedBox(height: 16),

              _buildTextField(
                controller: _telefoneController,
                label: 'Telemóvel',
                iconData: Icons.phone_rounded,
                keyboardType: TextInputType.phone,
                darkCard: darkCard,
                mockupBlue: mockupBlue,
              ),
              const SizedBox(height: 16),

              // Dropdown de Categoria
              Container(
                decoration: BoxDecoration(
                  color: darkCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.category_rounded, size: 14, color: Colors.white54),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _categoriaSelecionada,
                          hint: const Text('Especialidade principal', style: TextStyle(color: Colors.white38, fontSize: 14)),
                          dropdownColor: darkCard,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white54),
                          isExpanded: true,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          items: _categorias.map((cat) {
                            return DropdownMenuItem(
                              value: cat,
                              child: Text(cat),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _categoriaSelecionada = val;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              _buildTextField(
                controller: _senhaController,
                label: 'Palavra-passe',
                iconData: Icons.lock_rounded,
                obscureText: true,
                darkCard: darkCard,
                mockupBlue: mockupBlue,
              ),
              const SizedBox(height: 32),

              SizedBox(
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mockupBlue,
                    foregroundColor: Colors.white,
                    elevation: 10,
                    shadowColor: mockupBlue.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _isLoading ? null : _fazerCadastro,
                  child: _isLoading
                      ? const SizedBox(
                          width: 24, height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'CRIAR CONTA',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
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
              child: Icon(iconData, size: 14, color: Colors.white54),
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
}
