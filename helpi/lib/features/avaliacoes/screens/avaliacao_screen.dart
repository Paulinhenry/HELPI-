import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../services/avaliacao_service.dart';

class AvaliacaoScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  final AvaliacaoService? avaliacaoService;

  const AvaliacaoScreen({
    super.key, 
    required this.data,
    this.avaliacaoService,
  });

  @override
  State<AvaliacaoScreen> createState() => _AvaliacaoScreenState();
}

class _AvaliacaoScreenState extends State<AvaliacaoScreen> {
  late final AvaliacaoService _avaliacaoService;
  final TextEditingController _comentarioController = TextEditingController();
  
  int _notaSelecionada = 0;
  final List<String> _tagsSelecionadas = [];
  bool _enviando = false;
  double _gorjetaSelecionada = 0.0;

  final List<String> _tagsExcelentes = ['Excelente', 'Muito Limpo', 'Rápido', 'Educado', 'Cuidadoso'];
  final List<String> _tagsNeutras = ['Bom', 'Aceitável', 'Demorado', 'Comum'];
  final List<String> _tagsRuins = ['Atrasado', 'Trabalho Mal Feito', 'Grosseiro', 'Sujo', 'Inseguro'];

  @override
  void initState() {
    super.initState();
    _avaliacaoService = widget.avaliacaoService ?? AvaliacaoService();
  }

  List<String> get _tagsAtuais {
    if (_notaSelecionada == 5) return _tagsExcelentes;
    if (_notaSelecionada >= 3) return _tagsNeutras;
    if (_notaSelecionada > 0) return _tagsRuins;
    return [];
  }

  Color get _corDestaque {
    if (_notaSelecionada == 5) return Colors.green;
    if (_notaSelecionada >= 3) return Colors.orange;
    if (_notaSelecionada > 0) return Colors.red;
    return Colors.grey;
  }

  void _alternarTag(String tag) {
    setState(() {
      if (_tagsSelecionadas.contains(tag)) {
        _tagsSelecionadas.remove(tag);
      } else {
        _tagsSelecionadas.add(tag);
      }
    });
  }

  Future<void> _enviarAvaliacao() async {
    if (_notaSelecionada == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, dê uma nota de 1 a 5 estrelas.')),
      );
      return;
    }

    setState(() => _enviando = true);

    try {
      await _avaliacaoService.enviarAvaliacaoCliente(
        chamadoId: widget.data['chamado_id'],
        nota: _notaSelecionada,
        tags: _tagsSelecionadas,
        comentario: _comentarioController.text.trim(),
      );

      // Processamento Simulado da Gorjeta (se selecionada)
      if (_gorjetaSelecionada > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gorjeta de R\$ ${_gorjetaSelecionada.toInt()} enviada! Muito obrigado.'),
            backgroundColor: Colors.green,
          ),
        );
      }

      if (mounted) {
        // Redireciona para a raiz após avaliação bem sucedida
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      setState(() => _enviando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _comentarioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nomeProfissional = widget.data['profissional_nome'] ?? 'o profissional';

    return PopScope(
      canPop: false, // Bloqueia a volta pelo sistema (Android back button, etc)
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Por favor, avalie o serviço antes de sair.')),
          );
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          automaticallyImplyLeading: false, // Remove a seta de voltar
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text('Avaliação do Serviço', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                Text(
                  'Como foi o serviço de $nomeProfissional?',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),
                
                // --- MÁQUINA DE ESTRELAS ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final nota = index + 1;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _notaSelecionada = nota;
                          _tagsSelecionadas.clear(); // Limpa as tags ao mudar a nota
                          _gorjetaSelecionada = 0; // Limpa a gorjeta ao mudar a nota
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: AnimatedScale(
                          scale: _notaSelecionada >= nota ? 1.2 : 1.0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            _notaSelecionada >= nota ? Icons.star_rounded : Icons.star_outline_rounded,
                            size: 48,
                            color: _notaSelecionada >= nota ? Colors.amber : Colors.grey.shade300,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                
                const SizedBox(height: 40),

                // --- TAGS INTELIGENTES ---
                if (_notaSelecionada > 0) ...[
                  Text(
                    'O que destacaria?',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _tagsAtuais.map((tag) {
                      final isSelected = _tagsSelecionadas.contains(tag);
                      return ChoiceChip(
                        label: Text(tag),
                        selected: isSelected,
                        onSelected: (_) => _alternarTag(tag),
                        selectedColor: _corDestaque.withValues(alpha: 0.2),
                        backgroundColor: Colors.grey.shade100,
                        labelStyle: TextStyle(
                          color: isSelected ? _corDestaque : Colors.grey.shade700,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        side: BorderSide(
                          color: isSelected ? _corDestaque : Colors.transparent,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 32),
                ],

                // --- MÁQUINA DE GORJETA (UPSELL) ---
                if (_notaSelecionada == 5) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.monetization_on, color: Colors.green, size: 28),
                            SizedBox(width: 8),
                            Text(
                              'Enviar Gorjeta?',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$nomeProfissional foi incrível? Recompense-o!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.green.shade700),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [5.0, 10.0, 20.0].map((valor) {
                            final isSelected = _gorjetaSelecionada == valor;
                            return InkWell(
                              onTap: () => setState(() => _gorjetaSelecionada = isSelected ? 0 : valor),
                              borderRadius: BorderRadius.circular(12),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.green : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected ? Colors.green : Colors.grey.shade300,
                                  ),
                                ),
                                child: Text(
                                  'R\$ ${valor.toInt()}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.white : Colors.grey.shade800,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],

                // --- COMENTÁRIO OPCIONAL ---
                if (_notaSelecionada > 0) ...[
                  TextField(
                    controller: _comentarioController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Deixe um comentário (opcional)',
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],

                // --- BOTÃO DE ENVIO ---
                if (_notaSelecionada > 0)
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      onPressed: _enviando ? null : _enviarAvaliacao,
                      child: _enviando
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'ENVIAR AVALIAÇÃO',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
