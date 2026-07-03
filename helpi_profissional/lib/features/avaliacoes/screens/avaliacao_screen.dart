import 'package:flutter/material.dart';
import '../services/avaliacao_service.dart';

class AvaliacaoScreen extends StatefulWidget {
  final String chamadoId;
  final String nomeCliente;
  final AvaliacaoService? avaliacaoService;

  const AvaliacaoScreen({
    super.key, 
    required this.chamadoId, 
    required this.nomeCliente,
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

  final List<String> _tagsExcelentes = ['Ótimo Cliente', 'Boa Comunicação', 'Pagou Rápido', 'Educado', 'Acolhedor'];
  final List<String> _tagsNeutras = ['Bom', 'Razoável', 'Sem Problemas', 'Comum'];
  final List<String> _tagsRuins = ['Cliente Grosseiro', 'Atrasado', 'Cancelou no Local', 'Desrespeitoso'];

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
    if (_notaSelecionada == 5) return Colors.greenAccent;
    if (_notaSelecionada >= 3) return Colors.orangeAccent;
    if (_notaSelecionada > 0) return Colors.redAccent;
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
      await _avaliacaoService.enviarAvaliacaoProfissional(
        chamadoId: widget.chamadoId,
        nota: _notaSelecionada,
        tags: _tagsSelecionadas,
        comentario: _comentarioController.text.trim(),
      );

      if (mounted) {
        // Redireciona com true para o mapa
        Navigator.of(context).pop(true);
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
    return PopScope(
      canPop: false, // Bloqueia a volta pelo sistema
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Por favor, avalie o cliente antes de voltar ao mapa.')),
          );
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        appBar: AppBar(
          automaticallyImplyLeading: false, // Remove a seta de voltar
          backgroundColor: const Color(0xFF0A0A0A),
          elevation: 0,
          title: const Text('Avaliação do Cliente', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                  'Como foi o atendimento com o cliente ${widget.nomeCliente}?',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
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
                            color: _notaSelecionada >= nota ? Colors.amber : Colors.white38,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                
                const SizedBox(height: 40),

                // --- TAGS INTELIGENTES ---
                if (_notaSelecionada > 0) ...[
                  const Text(
                    'Como descreveria este cliente?',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70),
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
                        backgroundColor: Colors.white10,
                        labelStyle: TextStyle(
                          color: isSelected ? _corDestaque : Colors.white70,
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

                // --- COMENTÁRIO OPCIONAL ---
                if (_notaSelecionada > 0) ...[
                  TextField(
                    controller: _comentarioController,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Deixe um comentário (opcional)',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white10,
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
                        backgroundColor: const Color(0xFF448AFF),
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
