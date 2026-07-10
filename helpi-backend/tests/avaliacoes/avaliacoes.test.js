// =============================================================
// HELPI - Testes de Avaliações (Unitários com Mocks)
// Testa o motor de confiança e a máquina de punição.
// =============================================================

const request = require('supertest');
const app = require('../../src/app');
const jwt = require('jsonwebtoken');

// Mock do banco de dados
jest.mock('../../src/config/database', () => {
    const mockClient = {
        query: jest.fn(),
        release: jest.fn(),
    };
    return {
        query: jest.fn(),
        connect: jest.fn().mockResolvedValue(mockClient),
        on: jest.fn(),
        _mockClient: mockClient,
    };
});

const pool = require('../../src/config/database');

// Helpers para gerar tokens
const gerarTokenCliente = (id = 'cliente-uuid-001') =>
    jwt.sign({ id, tipo: 'cliente', tokenType: 'access' }, process.env.JWT_SECRET, { expiresIn: '15m' });

const gerarTokenProfissional = (id = 'prof-uuid-001') =>
    jwt.sign({ id, tipo: 'profissional', tokenType: 'access' }, process.env.JWT_SECRET, { expiresIn: '15m' });

// ═══════════════════════════════════════════════════════════════
// CLIENTE AVALIA PROFISSIONAL
// ═══════════════════════════════════════════════════════════════
describe('POST /api/v1/avaliacoes/cliente', () => {
    const token = gerarTokenCliente('cliente-001');
    const mockClient = pool._mockClient;

    beforeEach(() => {
        jest.clearAllMocks();
        pool.connect.mockResolvedValue(mockClient);
    });

    test('Deve criar avaliação com sucesso e atualizar nota média', async () => {
        // 1. Validar chamado
        mockClient.query
            .mockResolvedValueOnce({ rows: [] }) // BEGIN
            .mockResolvedValueOnce({
                rows: [{ cliente_id: 'cliente-001', profissional_id: 'prof-001', status: 'finalizado' }]
            })
            // 2. INSERT avaliação
            .mockResolvedValueOnce({
                rows: [{ id: 'aval-001', nota: 5, tags: '[]', comentario: 'Ótimo!', criado_em: new Date() }]
            })
            // 3. UPDATE profissional (nota_media)
            .mockResolvedValueOnce({
                rows: [{ nota_media: 4.8, total_avaliacoes: 5, status: 'aprovado' }]
            })
            // 4. COMMIT
            .mockResolvedValueOnce({ rows: [] });

        const res = await request(app)
            .post('/api/v1/avaliacoes/cliente')
            .set('Authorization', `Bearer ${token}`)
            .send({ chamado_id: 'chamado-001', nota: 5, comentario: 'Ótimo!' });

        expect(res.statusCode).toBe(201);
        expect(res.body.avaliacao.nota).toBe(5);
        expect(res.body).toHaveProperty('nova_media_profissional');
        expect(res.body.profissional_suspenso).toBe(false);
    });

    test('Deve retornar 400 se a nota estiver fora do range (0)', async () => {
        const res = await request(app)
            .post('/api/v1/avaliacoes/cliente')
            .set('Authorization', `Bearer ${token}`)
            .send({ chamado_id: 'chamado-001', nota: 0 });

        expect(res.statusCode).toBe(400);
        expect(res.body.erro).toContain('nota');
    });

    test('Deve retornar 400 se a nota estiver fora do range (6)', async () => {
        const res = await request(app)
            .post('/api/v1/avaliacoes/cliente')
            .set('Authorization', `Bearer ${token}`)
            .send({ chamado_id: 'chamado-001', nota: 6 });

        expect(res.statusCode).toBe(400);
    });

    test('Deve retornar 400 sem chamado_id', async () => {
        const res = await request(app)
            .post('/api/v1/avaliacoes/cliente')
            .set('Authorization', `Bearer ${token}`)
            .send({ nota: 5 });

        expect(res.statusCode).toBe(400);
        expect(res.body.erro).toContain('chamado');
    });

    test('Deve retornar 404 se o chamado não existir', async () => {
        mockClient.query
            .mockResolvedValueOnce({ rows: [] }) // BEGIN
            .mockResolvedValueOnce({ rows: [] }); // SELECT chamado — vazio

        const res = await request(app)
            .post('/api/v1/avaliacoes/cliente')
            .set('Authorization', `Bearer ${token}`)
            .send({ chamado_id: 'chamado-inexistente', nota: 5 });

        expect(res.statusCode).toBe(404);
    });

    test('Deve retornar 400 se o chamado não estiver finalizado', async () => {
        mockClient.query
            .mockResolvedValueOnce({ rows: [] }) // BEGIN
            .mockResolvedValueOnce({
                rows: [{ cliente_id: 'cliente-001', profissional_id: 'prof-001', status: 'em_servico' }]
            });

        const res = await request(app)
            .post('/api/v1/avaliacoes/cliente')
            .set('Authorization', `Bearer ${token}`)
            .send({ chamado_id: 'chamado-001', nota: 5 });

        expect(res.statusCode).toBe(400);
        expect(res.body.erro).toContain('finalizados');
    });

    test('Deve retornar 403 se o chamado não pertencer ao cliente', async () => {
        mockClient.query
            .mockResolvedValueOnce({ rows: [] }) // BEGIN
            .mockResolvedValueOnce({
                rows: [{ cliente_id: 'outro-cliente', profissional_id: 'prof-001', status: 'finalizado' }]
            });

        const res = await request(app)
            .post('/api/v1/avaliacoes/cliente')
            .set('Authorization', `Bearer ${token}`)
            .send({ chamado_id: 'chamado-001', nota: 5 });

        expect(res.statusCode).toBe(403);
    });

    test('Deve retornar 409 em tentativa de avaliação duplicada', async () => {
        mockClient.query
            .mockResolvedValueOnce({ rows: [] }) // BEGIN
            .mockResolvedValueOnce({
                rows: [{ cliente_id: 'cliente-001', profissional_id: 'prof-001', status: 'finalizado' }]
            })
            // INSERT falha com unique_violation
            .mockRejectedValueOnce({ code: '23505', message: 'unique_violation' });

        const res = await request(app)
            .post('/api/v1/avaliacoes/cliente')
            .set('Authorization', `Bearer ${token}`)
            .send({ chamado_id: 'chamado-001', nota: 4 });

        expect(res.statusCode).toBe(409);
        expect(res.body.erro).toContain('já avaliou');
    });

    test('Deve suspender profissional com nota < 4.0 após 10 avaliações (Máquina de Punição)', async () => {
        mockClient.query
            .mockResolvedValueOnce({ rows: [] }) // BEGIN
            .mockResolvedValueOnce({
                rows: [{ cliente_id: 'cliente-001', profissional_id: 'prof-001', status: 'finalizado' }]
            })
            .mockResolvedValueOnce({
                rows: [{ id: 'aval-002', nota: 1, tags: '[]', comentario: 'Péssimo', criado_em: new Date() }]
            })
            // UPDATE retorna status 'suspenso'
            .mockResolvedValueOnce({
                rows: [{ nota_media: 3.5, total_avaliacoes: 11, status: 'suspenso' }]
            })
            .mockResolvedValueOnce({ rows: [] }); // COMMIT

        const res = await request(app)
            .post('/api/v1/avaliacoes/cliente')
            .set('Authorization', `Bearer ${token}`)
            .send({ chamado_id: 'chamado-001', nota: 1, comentario: 'Péssimo' });

        expect(res.statusCode).toBe(201);
        expect(res.body.profissional_suspenso).toBe(true);
    });

    test('Deve rejeitar sem token de autenticação', async () => {
        const res = await request(app)
            .post('/api/v1/avaliacoes/cliente')
            .send({ chamado_id: 'chamado-001', nota: 5 });

        expect(res.statusCode).toBe(401);
    });
});

// ═══════════════════════════════════════════════════════════════
// PROFISSIONAL AVALIA CLIENTE
// ═══════════════════════════════════════════════════════════════
describe('POST /api/v1/avaliacoes/profissional', () => {
    const token = gerarTokenProfissional('prof-001');
    const mockClient = pool._mockClient;

    beforeEach(() => {
        jest.clearAllMocks();
        pool.connect.mockResolvedValue(mockClient);
    });

    test('Deve permitir profissional avaliar cliente com sucesso', async () => {
        mockClient.query
            .mockResolvedValueOnce({ rows: [] }) // BEGIN
            .mockResolvedValueOnce({
                rows: [{ cliente_id: 'cliente-001', profissional_id: 'prof-001', status: 'finalizado' }]
            })
            .mockResolvedValueOnce({
                rows: [{ id: 'aval-003', nota: 4, tags: '[]', comentario: 'Bom cliente', criado_em: new Date() }]
            })
            .mockResolvedValueOnce({
                rows: [{ nota_media: 4.5, total_avaliacoes: 3 }]
            })
            .mockResolvedValueOnce({ rows: [] }); // COMMIT

        const res = await request(app)
            .post('/api/v1/avaliacoes/profissional')
            .set('Authorization', `Bearer ${token}`)
            .send({ chamado_id: 'chamado-001', nota: 4, comentario: 'Bom cliente' });

        expect(res.statusCode).toBe(201);
        expect(res.body).toHaveProperty('nova_media_cliente');
    });

    test('Deve retornar 403 se o profissional não realizou o serviço', async () => {
        mockClient.query
            .mockResolvedValueOnce({ rows: [] }) // BEGIN
            .mockResolvedValueOnce({
                rows: [{ cliente_id: 'cliente-001', profissional_id: 'outro-prof', status: 'finalizado' }]
            });

        const res = await request(app)
            .post('/api/v1/avaliacoes/profissional')
            .set('Authorization', `Bearer ${token}`)
            .send({ chamado_id: 'chamado-001', nota: 4 });

        expect(res.statusCode).toBe(403);
    });
});
