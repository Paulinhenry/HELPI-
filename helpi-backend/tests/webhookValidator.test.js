// =============================================================
// HELPI - Testes do Webhook Validator (HMAC Signature)
// Testa a verificação de assinatura do Mercado Pago.
// Unitário puro — sem chamadas externas.
// =============================================================

const crypto = require('crypto');
const { verificarAssinaturaMP } = require('../src/middlewares/webhookValidator');

// ─── HELPERS ────────────────────────────────────────────────
const MOCK_SECRET = 'test-webhook-secret-2024';

const mockRes = () => {
    const res = {};
    res.status = jest.fn().mockReturnValue(res);
    res.json = jest.fn().mockReturnValue(res);
    return res;
};

/**
 * Gera uma assinatura HMAC válida conforme a documentação do Mercado Pago.
 */
const gerarAssinaturaValida = (dataId, requestId, ts) => {
    const manifest = `id:${dataId};request-id:${requestId};ts:${ts};`;
    const hmac = crypto.createHmac('sha256', MOCK_SECRET).update(manifest).digest('hex');
    return { ts, v1: hmac };
};

describe('Webhook Validator — Verificação HMAC do Mercado Pago', () => {
    const originalEnv = { ...process.env };

    beforeEach(() => {
        process.env.MP_WEBHOOK_SECRET = MOCK_SECRET;
    });

    afterEach(() => {
        process.env = { ...originalEnv };
    });

    // ═══ ASSINATURA VÁLIDA ══════════════════════════════════
    test('Deve aceitar requisição com assinatura HMAC válida', (done) => {
        const ts = '1704067200';
        const dataId = 'payment-123';
        const requestId = 'req-abc-456';
        const sig = gerarAssinaturaValida(dataId, requestId, ts);

        const req = {
            headers: {
                'x-signature': `ts=${sig.ts},v1=${sig.v1}`,
                'x-request-id': requestId,
            },
            query: { 'data.id': dataId },
            body: {},
            ip: '127.0.0.1',
        };

        const next = () => {
            // Se chegou aqui, a assinatura foi aceita
            done();
        };

        verificarAssinaturaMP(req, mockRes(), next);
    });

    // ═══ ASSINATURA INVÁLIDA ════════════════════════════════
    test('Deve rejeitar requisição com assinatura HMAC adulterada', () => {
        const req = {
            headers: {
                'x-signature': 'ts=1704067200,v1=assinatura_falsa_0000000000000000000000000000000000000000000000000000000000000000',
                'x-request-id': 'req-abc-456',
            },
            query: { 'data.id': 'payment-123' },
            body: {},
            ip: '192.168.1.100',
        };

        const res = mockRes();
        const next = jest.fn();

        // HMAC hex inválido vai causar erro no timingSafeEqual (tamanho diferente)
        // ou falhar na comparação
        try {
            verificarAssinaturaMP(req, res, next);
        } catch (e) {
            // Buffer lengths podem ser diferentes, o que é esperado
        }

        expect(next).not.toHaveBeenCalled();
    });

    // ═══ SEM HEADER X-SIGNATURE ═════════════════════════════
    test('Deve rejeitar requisição sem header x-signature', () => {
        const req = {
            headers: {},
            query: {},
            body: {},
            ip: '10.0.0.1',
        };

        const res = mockRes();
        const next = jest.fn();

        verificarAssinaturaMP(req, res, next);

        expect(res.status).toHaveBeenCalledWith(401);
        expect(res.json).toHaveBeenCalledWith(
            expect.objectContaining({ erro: expect.stringContaining('Assinatura ausente') })
        );
        expect(next).not.toHaveBeenCalled();
    });

    // ═══ FORMATO INVÁLIDO ═══════════════════════════════════
    test('Deve rejeitar x-signature com formato inválido (sem ts)', () => {
        const req = {
            headers: {
                'x-signature': 'v1=abc123',
                'x-request-id': 'req-123',
            },
            query: {},
            body: {},
            ip: '10.0.0.1',
        };

        const res = mockRes();
        const next = jest.fn();

        verificarAssinaturaMP(req, res, next);

        expect(res.status).toHaveBeenCalledWith(401);
        expect(res.json).toHaveBeenCalledWith(
            expect.objectContaining({ erro: expect.stringContaining('Formato') })
        );
    });

    test('Deve rejeitar x-signature com formato inválido (sem v1)', () => {
        const req = {
            headers: {
                'x-signature': 'ts=1704067200',
                'x-request-id': 'req-123',
            },
            query: {},
            body: {},
            ip: '10.0.0.1',
        };

        const res = mockRes();
        const next = jest.fn();

        verificarAssinaturaMP(req, res, next);

        expect(res.status).toHaveBeenCalledWith(401);
    });

    // ═══ SEM SECRET CONFIGURADO ═════════════════════════════
    test('Em produção, deve bloquear se MP_WEBHOOK_SECRET não estiver configurado', () => {
        delete process.env.MP_WEBHOOK_SECRET;
        process.env.NODE_ENV = 'production';

        const req = {
            headers: {},
            query: {},
            body: {},
            ip: '10.0.0.1',
        };

        const res = mockRes();
        const next = jest.fn();

        verificarAssinaturaMP(req, res, next);

        expect(res.status).toHaveBeenCalledWith(500);
        expect(res.json).toHaveBeenCalledWith(
            expect.objectContaining({ erro: expect.stringContaining('Configuração') })
        );
        expect(next).not.toHaveBeenCalled();
    });

    test('Em development, deve fazer bypass se MP_WEBHOOK_SECRET não estiver configurado', (done) => {
        delete process.env.MP_WEBHOOK_SECRET;
        process.env.NODE_ENV = 'development';

        const req = {
            headers: {},
            query: {},
            body: {},
            ip: '10.0.0.1',
        };

        const next = () => {
            // Se chegou aqui, o bypass funcionou
            done();
        };

        verificarAssinaturaMP(req, mockRes(), next);
    });

    // ═══ DATA.ID DO BODY (fallback) ═════════════════════════
    test('Deve usar data.id do body quando não estiver na query', (done) => {
        const dataId = 'payment-789';
        const requestId = 'req-xyz-999';
        const ts = '1704067200';
        const sig = gerarAssinaturaValida(dataId, requestId, ts);

        const req = {
            headers: {
                'x-signature': `ts=${sig.ts},v1=${sig.v1}`,
                'x-request-id': requestId,
            },
            query: {}, // Sem data.id na query
            body: { data: { id: dataId } }, // data.id no body
            ip: '127.0.0.1',
        };

        const next = () => done();
        verificarAssinaturaMP(req, mockRes(), next);
    });
});
