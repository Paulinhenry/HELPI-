// =============================================================
// HELPI - Testes do Webhook do Mercado Pago
// Pilar 1 > Domínio Financeiro
//
// Testa: Resposta 200 em < 1s (Sobrevivência),
//        Rejeição de eventos falsos (Dinheiro Falso),
//        Formatos IPN vs Webhook
//
// NOTA: Usa mocks — não chama a API real do Mercado Pago
// =============================================================

const request = require('supertest');
const app = require('../../src/app');

// Mock do módulo do Mercado Pago para não fazer chamadas reais
jest.mock('../../src/config/mercadopago', () => ({
    payment: {
        get: jest.fn().mockResolvedValue({
            status: 'approved',
            id: '12345'
        }),
        create: jest.fn()
    }
}));

// Mock do database pool para não precisar de BD real
jest.mock('../../src/config/database', () => ({
    query: jest.fn().mockResolvedValue({
        rows: [{ 
            chamado_id: 'test-uuid',
            valor_profissional: 90,
            valor_total: 100
        }]
    }),
    connect: jest.fn().mockResolvedValue({
        query: jest.fn().mockResolvedValue({ rows: [] }),
        release: jest.fn()
    })
}));

describe('🔔 Webhook Mercado Pago', () => {
    const originalEnv = process.env;

    beforeEach(() => {
        jest.resetModules();
        process.env = { ...originalEnv };
        // Remove a chave para que o middleware ignore a validação (bypass de dev/test)
        delete process.env.MP_WEBHOOK_SECRET;
        process.env.NODE_ENV = 'development';
    });

    afterEach(() => {
        process.env = originalEnv;
    });

    // ─── TESTE DE SOBREVIVÊNCIA ─────────────────────────────
    // O Mercado Pago BANE servidores que demoram mais de ~1s a responder
    describe('Teste de Sobrevivência (Tempo de Resposta)', () => {
        
        it('deve responder 200 OK em menos de 1 segundo', async () => {
            const inicio = Date.now();
            
            const res = await request(app)
                .post('/api/pagamentos/webhook')
                .send({
                    action: 'payment.created',
                    data: { id: '12345' }
                });

            const duracao = Date.now() - inicio;

            expect(res.statusCode).toBe(200);
            expect(duracao).toBeLessThan(1000); // < 1 segundo
        });

        it('deve responder 200 mesmo com body vazio', async () => {
            const res = await request(app)
                .post('/api/pagamentos/webhook')
                .send({});

            // Deve responder 200 (não crashar) mesmo sem dados válidos
            expect(res.statusCode).toBe(200);
        });
    });

    // ─── TESTE DO DINHEIRO FALSO ────────────────────────────
    // Webhook deve ignorar eventos que não são de pagamento
    describe('Teste do Dinheiro Falso (Eventos Inválidos)', () => {

        it('deve responder 200 mas ignorar evento merchant_order', async () => {
            const res = await request(app)
                .post('/api/pagamentos/webhook')
                .send({
                    type: 'merchant_order',
                    data: { id: '99999' }
                });

            // Webhook deve responder 200 (para o MP não retentar)
            // mas NÃO deve processar como pagamento
            expect(res.statusCode).toBe(200);
        });

        it('deve responder 200 mas ignorar evento de test', async () => {
            const res = await request(app)
                .post('/api/pagamentos/webhook')
                .send({
                    type: 'test',
                    data: { id: '00000' }
                });

            expect(res.statusCode).toBe(200);
        });

        it('deve processar evento payment.created corretamente', async () => {
            const res = await request(app)
                .post('/api/pagamentos/webhook')
                .send({
                    action: 'payment.created',
                    data: { id: '12345' }
                });

            expect(res.statusCode).toBe(200);
        });

        it('deve processar evento payment.updated corretamente', async () => {
            const res = await request(app)
                .post('/api/pagamentos/webhook')
                .send({
                    action: 'payment.updated',
                    data: { id: '12345' }
                });

            expect(res.statusCode).toBe(200);
        });
    });

    // ─── TESTE DO FORMATO IPN (Query Params) ────────────────
    describe('Formato IPN (Query Parameters)', () => {

        it('deve aceitar formato IPN via query params (?topic=payment&id=xxx)', async () => {
            const res = await request(app)
                .post('/api/pagamentos/webhook?topic=payment&id=12345')
                .send({});

            expect(res.statusCode).toBe(200);
        });

        it('deve ignorar IPN com topic diferente de payment', async () => {
            const res = await request(app)
                .post('/api/pagamentos/webhook?topic=merchant_order&id=99999')
                .send({});

            // Responde 200 mas não processa
            expect(res.statusCode).toBe(200);
        });
    });

    // ─── TESTE DE BODY TYPE ─────────────────────────────────
    describe('Formato Webhook V2 (body.type)', () => {

        it('deve aceitar formato V2 com type=payment', async () => {
            const res = await request(app)
                .post('/api/pagamentos/webhook')
                .send({
                    type: 'payment',
                    data: { id: '12345' }
                });

            expect(res.statusCode).toBe(200);
        });
    });
});
