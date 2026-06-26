const express = require('express');
const router = express.Router();
const { estimarPreco, processarPagamento, webhookMercadoPago } = require('../controllers/pagamentos.controller');
const authCliente = require('../middlewares/authCliente');

// Rota de estimativa de preço
router.post('/estimar', authCliente, estimarPreco);

// Rota para processar pagamento nativo
router.post('/processar', authCliente, processarPagamento);

// Webhook do Mercado Pago (público)
router.post('/webhook', webhookMercadoPago);

module.exports = router;
