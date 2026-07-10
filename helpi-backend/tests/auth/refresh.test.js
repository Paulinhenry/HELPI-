// =============================================================
// HELPI - Testes de Refresh Token (Unitários com Mocks)
// Testa o endpoint POST /auth/refresh isoladamente.
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

describe('POST /api/v1/auth/refresh — Renovação de Token', () => {
    afterEach(() => jest.clearAllMocks());

    // Gera um refresh token válido para testes
    const gerarRefreshToken = (id, tipo) => {
        const secret = process.env.JWT_REFRESH_SECRET || process.env.JWT_SECRET + '_refresh';
        return jwt.sign(
            { id, tipo, tokenType: 'refresh' },
            secret,
            { expiresIn: '30d' }
        );
    };

    // ═══ CENÁRIOS DE SUCESSO ════════════════════════════════
    test('Deve renovar access token com refresh token válido de cliente', async () => {
        const refreshToken = gerarRefreshToken('cliente-uuid-001', 'cliente');
        
        pool.query.mockResolvedValueOnce({
            rows: [{ id: 'cliente-uuid-001' }],
        });

        const res = await request(app)
            .post('/api/v1/auth/refresh')
            .send({ refresh_token: refreshToken });

        expect(res.statusCode).toBe(200);
        expect(res.body).toHaveProperty('access_token');
        expect(res.body).toHaveProperty('token'); // Retrocompatibilidade
        expect(res.body.mensagem).toContain('renovado');

        // Verifica que o novo access token é válido
        const decoded = jwt.verify(res.body.access_token, process.env.JWT_SECRET);
        expect(decoded.id).toBe('cliente-uuid-001');
        expect(decoded.tipo).toBe('cliente');
    });

    test('Deve renovar access token com refresh token válido de profissional', async () => {
        const refreshToken = gerarRefreshToken('prof-uuid-001', 'profissional');
        
        pool.query.mockResolvedValueOnce({
            rows: [{ id: 'prof-uuid-001' }],
        });

        const res = await request(app)
            .post('/api/v1/auth/refresh')
            .send({ refresh_token: refreshToken });

        expect(res.statusCode).toBe(200);
        expect(res.body).toHaveProperty('access_token');

        const decoded = jwt.verify(res.body.access_token, process.env.JWT_SECRET);
        expect(decoded.tipo).toBe('profissional');
    });

    // ═══ CENÁRIOS DE ERRO ═══════════════════════════════════
    test('Deve retornar 400 sem refresh_token no body', async () => {
        const res = await request(app)
            .post('/api/v1/auth/refresh')
            .send({});

        expect(res.statusCode).toBe(400);
        expect(res.body.erro).toContain('obrigatório');
    });

    test('Deve retornar 401 com refresh token expirado', async () => {
        const secret = process.env.JWT_REFRESH_SECRET || process.env.JWT_SECRET + '_refresh';
        const tokenExpirado = jwt.sign(
            { id: 'uuid', tipo: 'cliente', tokenType: 'refresh' },
            secret,
            { expiresIn: '0s' }
        );

        // Pequeno delay para garantir que o token expirou
        await new Promise(resolve => setTimeout(resolve, 50));

        const res = await request(app)
            .post('/api/v1/auth/refresh')
            .send({ refresh_token: tokenExpirado });

        expect(res.statusCode).toBe(401);
        expect(res.body.erro).toContain('expirado');
    });

    test('Deve retornar 401 com refresh token assinado com chave errada', async () => {
        const tokenFalso = jwt.sign(
            { id: 'uuid', tipo: 'cliente', tokenType: 'refresh' },
            'chave-secreta-errada-hacker',
            { expiresIn: '30d' }
        );

        const res = await request(app)
            .post('/api/v1/auth/refresh')
            .send({ refresh_token: tokenFalso });

        expect(res.statusCode).toBe(401);
        expect(res.body.erro).toContain('inválido');
    });

    test('Deve retornar 401 com tipo inválido no token', async () => {
        const secret = process.env.JWT_REFRESH_SECRET || process.env.JWT_SECRET + '_refresh';
        const tokenTipoErrado = jwt.sign(
            { id: 'uuid', tipo: 'admin', tokenType: 'refresh' }, // tipo 'admin' não existe
            secret,
            { expiresIn: '30d' }
        );

        const res = await request(app)
            .post('/api/v1/auth/refresh')
            .send({ refresh_token: tokenTipoErrado });

        expect(res.statusCode).toBe(401);
        expect(res.body.erro).toContain('Tipo');
    });

    test('Deve retornar 401 se o utilizador não existe mais no banco', async () => {
        const refreshToken = gerarRefreshToken('uuid-deletado', 'cliente');
        
        pool.query.mockResolvedValueOnce({
            rows: [], // Utilizador não encontrado
        });

        const res = await request(app)
            .post('/api/v1/auth/refresh')
            .send({ refresh_token: refreshToken });

        expect(res.statusCode).toBe(401);
        expect(res.body.erro).toContain('não encontrado');
    });

    test('Deve retornar 401 com string aleatória como refresh_token', async () => {
        const res = await request(app)
            .post('/api/v1/auth/refresh')
            .send({ refresh_token: 'isto-nao-eh-um-jwt-valido' });

        expect(res.statusCode).toBe(401);
    });
});
