// =============================================================
// HELPI - Middleware de Verificação de Assinatura do Mercado Pago
//
// SEGURANÇA: O endpoint /webhook é público. Sem esta verificação,
// qualquer pessoa pode forjar uma requisição HTTP e marcar
// pagamentos como aprovados na nossa base de dados.
//
// Como funciona:
// 1. O Mercado Pago envia um header x-signature com HMAC-SHA256
// 2. Nós recalculamos o HMAC com o rawBody e o MP_WEBHOOK_SECRET
// 3. Se os HMACs baterem, a requisição é legítima
// =============================================================

const crypto = require('crypto');
const logger = require('../utils/logger');

/**
 * Verifica a assinatura HMAC-SHA256 enviada pelo Mercado Pago.
 * Docs: https://www.mercadopago.com.br/developers/pt/docs/your-integrations/notifications/webhooks
 *
 * Requer que a rota use express.raw() para preservar o rawBody.
 */
const verificarAssinaturaMP = (req, res, next) => {
    const secret = process.env.MP_WEBHOOK_SECRET;

    // Se não há secret configurado, bloqueia em produção, avisa em dev
    if (!secret) {
        if (process.env.NODE_ENV === 'production') {
            logger.error('[WEBHOOK] MP_WEBHOOK_SECRET não configurado — requisição bloqueada em produção.');
            return res.status(500).json({ erro: 'Configuração de webhook ausente.' });
        }
        logger.warn('[WEBHOOK] MP_WEBHOOK_SECRET não configurado — pulando verificação em desenvolvimento.');
        return next();
    }

    const xSignature = req.headers['x-signature'];
    const xRequestId = req.headers['x-request-id'];

    if (!xSignature) {
        logger.warn(`[WEBHOOK] Requisição sem x-signature recebida (ip: ${req.ip})`);
        return res.status(401).json({ erro: 'Assinatura ausente.' });
    }

    // Extrai ts e v1 do header x-signature
    // Formato: "ts=1704067200,v1=abc123..."
    const parts = {};
    xSignature.split(',').forEach(part => {
        const [key, value] = part.split('=');
        if (key && value) parts[key.trim()] = value.trim();
    });

    if (!parts.ts || !parts.v1) {
        logger.warn('[WEBHOOK] Formato de x-signature inválido.');
        return res.status(401).json({ erro: 'Formato de assinatura inválido.' });
    }

    // Constrói a string de manifesto conforme documentação do MP
    const manifest = `id:${req.query?.['data.id'] || req.body?.data?.id || ''};request-id:${xRequestId || ''};ts:${parts.ts};`;

    // Recalcula o HMAC
    const expectedSignature = crypto
        .createHmac('sha256', secret)
        .update(manifest)
        .digest('hex');

    // Comparação segura (evita timing attacks)
    const isValid = crypto.timingSafeEqual(
        Buffer.from(parts.v1, 'hex'),
        Buffer.from(expectedSignature, 'hex')
    );

    if (!isValid) {
        logger.warn(`[WEBHOOK] Assinatura inválida! Possível tentativa de forjamento (ip: ${req.ip})`);
        return res.status(401).json({ erro: 'Assinatura inválida.' });
    }

    next();
};

module.exports = { verificarAssinaturaMP };
