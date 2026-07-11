// =============================================================
// HELPI - Testes de Pagamentos (Unitários com Mocks)
// Testa o fluxo de processamento de pagamentos e webhook.
// =============================================================

const request = require('supertest');
const app = require('../../src/app');
const jwt = require('jsonwebtoken');

// Mock do banco de dados
jest.mock('../../src/config/database', () => ({
    query: jest.fn(),
    connect: jest.fn(),
    on: jest.fn(),
}));

// Mock do Mercado Pago
jest.mock('../../src/config/mercadopago', () => ({
    client: {},
    payment: {
        get: jest.fn(),
    },
    order: {
        create: jest.fn()
    }
}));

const pool = require('../../src/config/database');
const { order } = require('../../src/config/mercadopago');

const gerarTokenCliente = (id = 'cliente-001') =>
    jwt.sign({ id, tipo: 'cliente', tokenType: 'access' }, process.env.JWT_SECRET, { expiresIn: '15m' });

// ═══════════════════════════════════════════════════════════════
// PROCESSAR PAGAMENTO
// ═══════════════════════════════════════════════════════════════
describe('POST /api/v1/pagamentos/processar', () => {
    const token = gerarTokenCliente('cliente-001');

    beforeEach(() => jest.clearAllMocks());

    test('Deve processar pagamento PIX com sucesso', async () => {
        // 1. Buscar chamado
        pool.query
            .mockResolvedValueOnce({
                rows: [{ id: 'chamado-001', valor_cobrado: '150.00', profissional_id: 'prof-001', status: 'finalizado' }]
            })
            // 2. Buscar cliente (email + CPF)
            .mockResolvedValueOnce({
                rows: [{ email: 'joao@email.com', cpf: '52998224725' }]
            })
            // 3. INSERT pagamento
            .mockResolvedValueOnce({ rows: [] })
            // 4. UPDATE chamado (pago)
            .mockResolvedValueOnce({ rows: [] });

        order.create.mockResolvedValueOnce({
            id: 'mp-order-999',
            status: 'approved',
            transactions: {
                payments: [{
                    id: 'mp-payment-12345',
                    status: 'approved',
                    qr_code: 'pix-code-123',
                    qr_code_base64: 'base64data',
                }]
            }
        });

        // Mock do io e profissionaisConectados via app.set
        app.set('io', { to: jest.fn().mockReturnThis(), emit: jest.fn() });
        app.set('profissionaisConectados', new Map([['prof-001', 'socket-abc']]));

        const res = await request(app)
            .post('/api/v1/pagamentos/processar')
            .set('Authorization', `Bearer ${token}`)
            .send({
                chamado_id: 'chamado-001',
                payment_method_id: 'pix',
            });

        expect(res.statusCode).toBe(200);
        expect(res.body.status).toBe('approved');
        expect(res.body.id).toBe('mp-payment-12345');
        expect(res.body.qr_code).toBe('pix-code-123');
    });

    test('Deve retornar 404 se o chamado não existir', async () => {
        pool.query.mockResolvedValueOnce({ rows: [] });

        const res = await request(app)
            .post('/api/v1/pagamentos/processar')
            .set('Authorization', `Bearer ${token}`)
            .send({ chamado_id: 'chamado-inexistente' });

        expect(res.statusCode).toBe(404);
        expect(res.body.erro).toContain('não encontrado');
    });

    test('Deve retornar 400 se o chamado não estiver finalizado', async () => {
        pool.query.mockResolvedValueOnce({
            rows: [{ id: 'chamado-001', valor_cobrado: '150.00', profissional_id: 'prof-001', status: 'em_servico' }]
        });

        const res = await request(app)
            .post('/api/v1/pagamentos/processar')
            .set('Authorization', `Bearer ${token}`)
            .send({ chamado_id: 'chamado-001' });

        expect(res.statusCode).toBe(400);
        expect(res.body.erro).toContain('finalizados');
    });

    test('Deve retornar 400 se o cliente não tiver CPF cadastrado (V7)', async () => {
        pool.query
            .mockResolvedValueOnce({
                rows: [{ id: 'chamado-001', valor_cobrado: '100.00', profissional_id: 'prof-001', status: 'finalizado' }]
            })
            .mockResolvedValueOnce({
                rows: [{ email: 'joao@email.com', cpf: null }] // Sem CPF
            });

        const res = await request(app)
            .post('/api/v1/pagamentos/processar')
            .set('Authorization', `Bearer ${token}`)
            .send({ chamado_id: 'chamado-001' });

        expect(res.statusCode).toBe(400);
        expect(res.body.erro).toContain('CPF');
    });

    test('Deve retornar 400 se o CPF tiver tamanho errado (V7)', async () => {
        pool.query
            .mockResolvedValueOnce({
                rows: [{ id: 'chamado-001', valor_cobrado: '100.00', profissional_id: 'prof-001', status: 'finalizado' }]
            })
            .mockResolvedValueOnce({
                rows: [{ email: 'joao@email.com', cpf: '1234' }] // CPF curto
            });

        const res = await request(app)
            .post('/api/v1/pagamentos/processar')
            .set('Authorization', `Bearer ${token}`)
            .send({ chamado_id: 'chamado-001' });

        expect(res.statusCode).toBe(400);
        expect(res.body.erro).toContain('CPF');
    });

    test('Deve calcular split 90/10 corretamente', async () => {
        pool.query
            .mockResolvedValueOnce({
                rows: [{ id: 'chamado-001', valor_cobrado: '200.00', profissional_id: 'prof-001', status: 'finalizado' }]
            })
            .mockResolvedValueOnce({
                rows: [{ email: 'joao@email.com', cpf: '52998224725' }]
            })
            .mockResolvedValueOnce({ rows: [] }); // INSERT pagamento

        order.create.mockResolvedValueOnce({
            id: 'mp-order-888',
            status: 'in_process',
            transactions: {
                payments: [{
                    id: 'mp-pay-999',
                    status: 'in_process'
                }]
            }
        });

        app.set('io', null);
        app.set('profissionaisConectados', null);

        const res = await request(app)
            .post('/api/v1/pagamentos/processar')
            .set('Authorization', `Bearer ${token}`)
            .send({ chamado_id: 'chamado-001' });

        expect(res.statusCode).toBe(200);

        // Verifica que o INSERT usou os valores de split corretos
        const insertCall = pool.query.mock.calls[2]; // 3ª chamada = INSERT pagamentos
        const valores = insertCall[1];
        expect(valores[2]).toBe(200); // valor_total
        expect(valores[3]).toBe(180); // valor_profissional (90%)
        expect(valores[4]).toBe(20);  // valor_plataforma (10%)
    });

    test('Deve rejeitar sem token de autenticação', async () => {
        const res = await request(app)
            .post('/api/v1/pagamentos/processar')
            .send({ chamado_id: 'chamado-001' });

        expect(res.statusCode).toBe(401);
    });
});

// ═══════════════════════════════════════════════════════════════
// ESTIMAR PREÇO
// ═══════════════════════════════════════════════════════════════
describe('POST /api/v1/pagamentos/estimar', () => {
    const token = gerarTokenCliente('cliente-001');

    test('Deve retornar estimativa com categoria válida', async () => {
        const res = await request(app)
            .post('/api/v1/pagamentos/estimar')
            .set('Authorization', `Bearer ${token}`)
            .send({ categoria: 'Elétrica', descricao: 'Tomada queimada' });

        expect(res.statusCode).toBe(200);
        expect(res.body.estimativa).toHaveProperty('preco_minimo');
        expect(res.body.estimativa).toHaveProperty('preco_maximo');
        expect(res.body.estimativa).toHaveProperty('preco_sugerido');
        expect(res.body.estimativa.preco_minimo).toBeGreaterThan(0);
        expect(res.body.estimativa.preco_maximo).toBeGreaterThanOrEqual(res.body.estimativa.preco_minimo);
    });

    test('Deve retornar 400 sem categoria', async () => {
        const res = await request(app)
            .post('/api/v1/pagamentos/estimar')
            .set('Authorization', `Bearer ${token}`)
            .send({ descricao: 'Tomada queimada' });

        expect(res.statusCode).toBe(400);
        expect(res.body.erro).toContain('Categoria');
    });

    test('Deve detectar urgência e aplicar multiplicador', async () => {
        const resNormal = await request(app)
            .post('/api/v1/pagamentos/estimar')
            .set('Authorization', `Bearer ${token}`)
            .send({ categoria: 'Elétrica', descricao: 'Tomada com problema' });

        const resUrgente = await request(app)
            .post('/api/v1/pagamentos/estimar')
            .set('Authorization', `Bearer ${token}`)
            .send({ categoria: 'Elétrica', descricao: 'Tomada com problema urgente socorro' });

        expect(resUrgente.body.estimativa.preco_sugerido)
            .toBeGreaterThan(resNormal.body.estimativa.preco_sugerido);
    });
});
