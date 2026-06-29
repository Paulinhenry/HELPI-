import 'package:flutter/material.dart';
import 'package:flutter_credit_card/flutter_credit_card.dart';
import 'package:provider/provider.dart';
import '../services/pagamento_service.dart';
import '../../chamados/providers/chamados_provider.dart';

class PagamentoCartaoScreen extends StatefulWidget {
  final Map<String, dynamic> data;

  const PagamentoCartaoScreen({super.key, required this.data});

  @override
  State<PagamentoCartaoScreen> createState() => _PagamentoCartaoScreenState();
}

class _PagamentoCartaoScreenState extends State<PagamentoCartaoScreen> {
  String cardNumber = '';
  String expiryDate = '';
  String cardHolderName = '';
  String cvvCode = '';
  bool isCvvFocused = false;
  bool useGlassMorphism = true;
  bool useBackgroundImage = false;
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  bool _processando = false;
  final PagamentoService _pagamentoService = PagamentoService();

  void _processarCartao() async {
    if (formKey.currentState?.validate() ?? false) {
      setState(() => _processando = true);

      try {
        final partesExpiracao = expiryDate.split('/');
        if (partesExpiracao.length != 2) throw Exception('Data inválida');

        final reqData = {
          "card_number": cardNumber.replaceAll(' ', ''),
          "expiration_month": int.parse(partesExpiracao[0]),
          "expiration_year": int.parse("20${partesExpiracao[1]}"),
          "security_code": cvvCode,
          "cardholder": {
            "name": cardHolderName,
            "identification": {
              "type": "CPF",
              "number": "00000000000" // CPF default
            }
          }
        };

        // 1. Gerar Token no Mercado Pago
        final token = await _pagamentoService.gerarTokenCartao(reqData);

        // 2. Processar Pagamento no Backend
        final response = await _pagamentoService.processarPagamento(
          widget.data['chamado_id'],
          'master', // Exemplo fixo
          dadosCartao: {'token': token, 'installments': 1},
        );

        if (response['status'] == 'approved' || response['status'] == 'in_process') {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pagamento aprovado com sucesso!'), backgroundColor: Colors.green),
          );
          context.read<ChamadosProvider>().resetarEstado();
          Navigator.of(context).popUntil((route) => route.isFirst);
        } else {
          throw Exception('Pagamento recusado: ${response['status']}');
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      } finally {
        if (mounted) setState(() => _processando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color brandBlue = Color(0xFF1B55D6); 
    const Color darkBackground = Color(0xFF0F1A2C);

    return Scaffold(
      backgroundColor: darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Cartão de Crédito', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const SizedBox(height: 16),
            CreditCardWidget(
              glassmorphismConfig: useGlassMorphism ? Glassmorphism.defaultConfig() : null,
              cardNumber: cardNumber,
              expiryDate: expiryDate,
              cardHolderName: cardHolderName,
              cvvCode: cvvCode,
              bankName: 'Helpi Bank',
              frontCardBorder: !useGlassMorphism ? Border.all(color: Colors.grey) : null,
              backCardBorder: !useGlassMorphism ? Border.all(color: Colors.grey) : null,
              showBackView: isCvvFocused,
              obscureCardNumber: true,
              obscureCardCvv: true,
              isHolderNameVisible: true,
              cardBgColor: brandBlue,
              isSwipeGestureEnabled: true,
              onCreditCardWidgetChange: (CreditCardBrand creditCardBrand) {},
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: <Widget>[
                    CreditCardForm(
                      formKey: formKey,
                      obscureCvv: true,
                      obscureNumber: true,
                      cardNumber: cardNumber,
                      cvvCode: cvvCode,
                      isHolderNameVisible: true,
                      isCardNumberVisible: true,
                      isExpiryDateVisible: true,
                      cardHolderName: cardHolderName,
                      expiryDate: expiryDate,
                      inputConfiguration: InputConfiguration(
                        cardNumberDecoration: InputDecoration(
                          labelText: 'Número do Cartão',
                          hintText: 'XXXX XXXX XXXX XXXX',
                          hintStyle: const TextStyle(color: Colors.white54),
                          labelStyle: const TextStyle(color: Colors.white),
                          focusedBorder: border,
                          enabledBorder: border,
                        ),
                        expiryDateDecoration: InputDecoration(
                          hintStyle: const TextStyle(color: Colors.white54),
                          labelStyle: const TextStyle(color: Colors.white),
                          focusedBorder: border,
                          enabledBorder: border,
                          labelText: 'Data de Expiração',
                          hintText: 'XX/XX',
                        ),
                        cvvCodeDecoration: InputDecoration(
                          hintStyle: const TextStyle(color: Colors.white54),
                          labelStyle: const TextStyle(color: Colors.white),
                          focusedBorder: border,
                          enabledBorder: border,
                          labelText: 'CVV',
                          hintText: 'XXX',
                        ),
                        cardHolderDecoration: InputDecoration(
                          hintStyle: const TextStyle(color: Colors.white54),
                          labelStyle: const TextStyle(color: Colors.white),
                          focusedBorder: border,
                          enabledBorder: border,
                          labelText: 'Nome do Titular',
                        ),
                        cardNumberTextStyle: const TextStyle(color: Colors.white),
                        cardHolderTextStyle: const TextStyle(color: Colors.white),
                        expiryDateTextStyle: const TextStyle(color: Colors.white),
                        cvvCodeTextStyle: const TextStyle(color: Colors.white),
                      ),
                      onCreditCardModelChange: onCreditCardModelChange,
                    ),
                    const SizedBox(height: 32),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: brandBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: _processando ? null : _processarCartao,
                          child: _processando 
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text(
                                  'PAGAR R\$ ${widget.data['valor_cobrado'] ?? widget.data['valor'] ?? '0.00'}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void onCreditCardModelChange(CreditCardModel? creditCardModel) {
    setState(() {
      cardNumber = creditCardModel!.cardNumber;
      expiryDate = creditCardModel.expiryDate;
      cardHolderName = creditCardModel.cardHolderName;
      cvvCode = creditCardModel.cvvCode;
      isCvvFocused = creditCardModel.isCvvFocused;
    });
  }

  OutlineInputBorder get border => OutlineInputBorder(
        borderSide: BorderSide(
          color: Colors.grey.withValues(alpha: 0.5),
          width: 1.0,
        ),
        borderRadius: BorderRadius.circular(8.0),
      );
}
