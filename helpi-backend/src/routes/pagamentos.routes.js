const express = require('express');
const router = express.Router();
const { estimarPreco, processarPagamento, webhookMercadoPago } = require('../controllers/pagamentos.controller');
const { requireAuth } = require('../middlewares/auth');

// Rota de estimativa de preço
router.post('/estimar', requireAuth, estimarPreco);

// Rota para processar pagamento nativo
router.post('/processar', requireAuth, processarPagamento);

// Webhook do Mercado Pago (público)
router.post('/webhook', webhookMercadoPago);

module.exports = router;
