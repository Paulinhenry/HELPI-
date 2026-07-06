// =============================================================
// HELPI - Rotas de Pagamentos
// POST /pagamentos/estimar   → Estimar preço (requer cliente autenticado)
// POST /pagamentos/processar → Processar pagamento (requer cliente autenticado)
// POST /pagamentos/webhook   → Webhook do Mercado Pago (público, mas validado por HMAC)
// =============================================================

const express = require('express');
const router = express.Router();
const { estimarPreco, processarPagamento, webhookMercadoPago } = require('../controllers/pagamentos.controller');
const authCliente = require('../middlewares/authCliente');
const { verificarAssinaturaMP } = require('../middlewares/webhookValidator');

// Rota de estimativa de preço
router.post('/estimar', authCliente, estimarPreco);

// Rota para processar pagamento nativo
router.post('/processar', authCliente, processarPagamento);

// Webhook do Mercado Pago
// SEGURANÇA: express.raw() preserva o rawBody para validação de assinatura HMAC.
// O middleware verificarAssinaturaMP valida o header x-signature antes de processar.
router.post(
    '/webhook',
    express.raw({ type: 'application/json', limit: '50kb' }),
    (req, res, next) => {
        // Converte rawBody de volta a objeto JSON para o controller usar normalmente
        if (Buffer.isBuffer(req.body)) {
            try {
                req.body = JSON.parse(req.body.toString('utf8'));
            } catch {
                req.body = {};
            }
        }
        next();
    },
    verificarAssinaturaMP,
    webhookMercadoPago
);

module.exports = router;
