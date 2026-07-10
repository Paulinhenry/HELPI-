// =============================================================
// HELPI - Testes de Cancelamento de Chamados (Unitários com Mocks)
// Testa o endpoint PATCH /chamados/:id/cancelar
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

const pool = require('../../src/config/database');

const gerarTokenCliente = (id = 'cliente-001') =>
    jwt.sign({ id, tipo: 'cliente', tokenType: 'access' }, process.env.JWT_SECRET, { expiresIn: '15m' });

const CHAMADO_UUID = 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d';

describe('PATCH /api/v1/chamados/:id/cancelar', () => {
    const token = gerarTokenCliente('cliente-001');

    beforeEach(() => jest.clearAllMocks());

    // ═══ SUCESSO ════════════════════════════════════════════
    test('Deve cancelar chamado próprio em status procurando_profissional', async () => {
        pool.query.mockResolvedValueOnce({
            rows: [{ id: CHAMADO_UUID, status: 'cancelado_pelo_cliente' }],
        });

        const res = await request(app)
            .patch(`/api/v1/chamados/${CHAMADO_UUID}/cancelar`)
            .set('Authorization', `Bearer ${token}`);

        expect(res.statusCode).toBe(200);
        expect(res.body.mensagem).toContain('cancelado');
        expect(res.body.chamado.status).toBe('cancelado_pelo_cliente');

        // Verifica que a query usou o cliente_id do JWT
        const queryArgs = pool.query.mock.calls[0][1];
        expect(queryArgs).toContain('cliente-001');
        expect(queryArgs).toContain(CHAMADO_UUID);
    });

    // ═══ ERROS ══════════════════════════════════════════════
    test('Deve retornar 400 se o chamado já foi aceite por profissional', async () => {
        pool.query.mockResolvedValueOnce({
            rows: [], // UPDATE não encontrou — já foi aceite ou não pertence ao cliente
        });

        const res = await request(app)
            .patch(`/api/v1/chamados/${CHAMADO_UUID}/cancelar`)
            .set('Authorization', `Bearer ${token}`);

        expect(res.statusCode).toBe(400);
        expect(res.body.erro).toContain('não encontrado ou já foi aceite');
    });

    test('Deve retornar 400 se o chamado não pertencer ao cliente', async () => {
        // Token é de 'cliente-001', mas o chamado é de 'outro-cliente'
        pool.query.mockResolvedValueOnce({
            rows: [], // A cláusula AND cliente_id = $2 não bate
        });

        const res = await request(app)
            .patch(`/api/v1/chamados/${CHAMADO_UUID}/cancelar`)
            .set('Authorization', `Bearer ${token}`);

        expect(res.statusCode).toBe(400);
    });

    test('Deve retornar 401 sem token de autenticação', async () => {
        const res = await request(app)
            .patch(`/api/v1/chamados/${CHAMADO_UUID}/cancelar`);

        expect(res.statusCode).toBe(401);
    });

    test('Deve retornar 400 com UUID inválido (V12)', async () => {
        const res = await request(app)
            .patch('/api/v1/chamados/nao-eh-uuid/cancelar')
            .set('Authorization', `Bearer ${token}`);

        expect(res.statusCode).toBe(400);
        expect(res.body.erro).toContain('UUID');
    });

    test('Deve retornar 403 se token for de profissional (apenas clientes cancelam)', async () => {
        const tokenProf = jwt.sign(
            { id: 'prof-001', tipo: 'profissional', tokenType: 'access' },
            process.env.JWT_SECRET,
            { expiresIn: '15m' }
        );

        const res = await request(app)
            .patch(`/api/v1/chamados/${CHAMADO_UUID}/cancelar`)
            .set('Authorization', `Bearer ${tokenProf}`);

        expect(res.statusCode).toBe(403);
    });

    test('Deve retornar 500 se houver erro interno no banco', async () => {
        pool.query.mockRejectedValueOnce(new Error('Connection refused'));

        const res = await request(app)
            .patch(`/api/v1/chamados/${CHAMADO_UUID}/cancelar`)
            .set('Authorization', `Bearer ${token}`);

        expect(res.statusCode).toBe(500);
    });
});
