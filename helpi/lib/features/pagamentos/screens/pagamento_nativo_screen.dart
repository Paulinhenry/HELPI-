import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../../core/theme/app_colors.dart';
import '../services/pagamento_service.dart';
import '../../chamados/providers/chamados_provider.dart';

class PagamentoNativoScreen extends StatefulWidget {
  final Map<String, dynamic> data;

  const PagamentoNativoScreen({super.key, required this.data});

  @override
  State<PagamentoNativoScreen> createState() => _PagamentoNativoScreenState();
}

class _PagamentoNativoScreenState extends State<PagamentoNativoScreen> {
  final PagamentoService _pagamentoService = PagamentoService();
  bool _processando = false;
  String? _qrCodeBase64;
  String? _qrCodeCopiaECola;

  Future<void> _gerarPix() async {
    setState(() {
      _processando = true;
      _qrCodeBase64 = null;
      _qrCodeCopiaECola = null;
    });

    try {
      final response = await _pagamentoService.processarPagamento(
        widget.data['chamado_id'],
        'pix',
      );

      if (response['status'] == 'pending' || response['status'] == 'approved' || response['status'] == 'in_process') {
        setState(() {
          _qrCodeBase64 = response['qr_code_base64'];
          _qrCodeCopiaECola = response['qr_code'];
          _processando = false;
        });
      } else {
        throw Exception('Status inesperado: ${response['status']}');
      }
    } catch (e) {
      setState(() => _processando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao gerar PIX: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _copiarPix() {
    if (_qrCodeCopiaECola != null) {
      Clipboard.setData(ClipboardData(text: _qrCodeCopiaECola!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Código PIX copiado!'), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final valorStr = widget.data['valor_cobrado'] != null ? 'R\$ ${widget.data['valor_cobrado']}' : '---';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Pagamento', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Total a pagar: $valorStr',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),
              
              if (_qrCodeBase64 == null && !_processando) ...[
                const Text('Escolha o método de pagamento:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                _MetodoCard(
                  icon: Icons.pix,
                  title: 'PIX',
                  subtitle: 'Aprovação imediata',
                  color: Colors.teal,
                  onTap: _gerarPix,
                ),
                const SizedBox(height: 12),
                _MetodoCard(
                  icon: Icons.credit_card,
                  title: 'Cartão de Crédito',
                  subtitle: 'Em breve',
                  color: Colors.grey,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Cartão de crédito estará disponível em breve.')),
                    );
                  },
                ),
              ],

              if (_processando)
                const Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('A gerar pagamento...', style: TextStyle(fontSize: 16, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),

              if (_qrCodeBase64 != null && !_processando) ...[
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const Text(
                          'Escaneie o QR Code abaixo com o app do seu banco:',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Image.memory(
                            base64Decode(_qrCodeBase64!),
                            width: 250,
                            height: 250,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 100),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text('Ou copie o código (Pix Copia e Cola):', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _qrCodeCopiaECola ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _copiarPix,
                          icon: const Icon(Icons.copy, color: Colors.white),
                          label: const Text('COPIAR CÓDIGO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () {
                            context.read<ChamadosProvider>().resetarEstado();
                            Navigator.of(context).popUntil((route) => route.isFirst);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryColor,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('JÁ PAGUEI / CONCLUIR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MetodoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _MetodoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
