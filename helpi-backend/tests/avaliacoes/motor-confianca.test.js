// =============================================================
// HELPI - Testes do Motor de Confiança (Avaliações Bi-Direcionais)
// Pilar 2 > Máquina de Punição e Regras de Avaliação
// =============================================================

const request = require('supertest');
const app = require('../../src/app');
const pool = require('../../src/config/database');
const { gerarTokenExpirado } = require('../setup');
const jwt = require('jsonwebtoken');

// Mock completo do Pool do PostgreSQL para evitar mutação na DB real
jest.mock('../../src/config/database', () => {
    const mPool = {
        connect: jest.fn(),
        query: jest.fn()
    };
    return mPool;
});

describe('🛡️ Motor de Confiança (Avaliações)', () => {
    
    let tokenCliente;
    let tokenProfissional;
    let mockClient;

    beforeEach(() => {
        // Gerar tokens válidos para testes
        tokenCliente = jwt.sign({ id: 'cliente-123', tipo: 'cliente' }, process.env.JWT_SECRET || 'secret-test', { expiresIn: '1h' });
        tokenProfissional = jwt.sign({ id: 'prof-456', tipo: 'profissional' }, process.env.JWT_SECRET || 'secret-test', { expiresIn: '1h' });

        // Setup do mock do client DB
        mockClient = {
            query: jest.fn(),
            release: jest.fn()
        };
        pool.connect.mockResolvedValue(mockClient);
        
        jest.clearAllMocks();
    });

    // ─── TESTES: CLIENTE AVALIA PROFISSIONAL ────────────────────
    describe('Cliente avaliando Profissional', () => {
        
        it('deve registrar avaliação com sucesso e atualizar média', async () => {
            // Configurar mocks do DB
            // 1. BEGIN
            mockClient.query.mockResolvedValueOnce({});
            // 2. Validar chamado
            mockClient.query.mockResolvedValueOnce({ 
                rows: [{ cliente_id: 'cliente-123', profissional_id: 'prof-456', status: 'finalizado' }] 
            });
            // 3. Inserir avaliação
            mockClient.query.mockResolvedValueOnce({
                rows: [{ id: 'aval-789', nota: 5, tags: ["pontual"], comentario: "Excelente!" }]
            });
            // 4. Update profissional e máquina de punição
            mockClient.query.mockResolvedValueOnce({
                rows: [{ nota_media: "4.90", total_avaliacoes: 5, status: 'ativo' }]
            });
            // 5. COMMIT
            mockClient.query.mockResolvedValueOnce({});

            const res = await request(app)
                .post('/api/avaliacoes/cliente')
                .set('Authorization', `Bearer ${tokenCliente}`)
                .send({
                    chamado_id: 'chamado-000',
                    nota: 5,
                    tags: ["pontual"],
                    comentario: "Excelente!"
                });

            expect(res.statusCode).toBe(201);
            expect(res.body.nova_media_profissional).toBe("4.90");
            expect(res.body.profissional_suspenso).toBe(false);
            
            // Verifica se a query de update da máquina de punição foi chamada
            expect(mockClient.query).toHaveBeenCalledWith(
                expect.stringContaining('UPDATE profissionais'),
                [5, 'prof-456']
            );
        });

        it('deve suspender o profissional automaticamente (Máquina de Punição)', async () => {
            // 1. BEGIN
            mockClient.query.mockResolvedValueOnce({});
            // 2. Validar chamado
            mockClient.query.mockResolvedValueOnce({ 
                rows: [{ cliente_id: 'cliente-123', profissional_id: 'prof-bad', status: 'finalizado' }] 
            });
            // 3. Inserir avaliação
            mockClient.query.mockResolvedValueOnce({
                rows: [{ id: 'aval-101', nota: 1 }]
            });
            // 4. Update profissional simulando média < 4.0 após 10 avaliações
            mockClient.query.mockResolvedValueOnce({
                rows: [{ nota_media: "3.80", total_avaliacoes: 10, status: 'suspenso' }]
            });

            const res = await request(app)
                .post('/api/avaliacoes/cliente')
                .set('Authorization', `Bearer ${tokenCliente}`)
                .send({
                    chamado_id: 'chamado-bad',
                    nota: 1
                });

            expect(res.statusCode).toBe(201);
            expect(res.body.profissional_suspenso).toBe(true);
        });

        it('deve rejeitar se o chamado não estiver finalizado', async () => {
            mockClient.query.mockResolvedValueOnce({});
            mockClient.query.mockResolvedValueOnce({ 
                rows: [{ cliente_id: 'cliente-123', profissional_id: 'prof-456', status: 'em_andamento' }] 
            });

            const res = await request(app)
                .post('/api/avaliacoes/cliente')
                .set('Authorization', `Bearer ${tokenCliente}`)
                .send({ chamado_id: 'chamado-1', nota: 5 });

            expect(res.statusCode).toBe(400);
            expect(res.body.erro).toContain('finalizados');
        });

        it('deve rejeitar avaliação duplicada (Bloqueio Único)', async () => {
            mockClient.query.mockResolvedValueOnce({});
            mockClient.query.mockResolvedValueOnce({ 
                rows: [{ cliente_id: 'cliente-123', profissional_id: 'prof-456', status: 'finalizado' }] 
            });
            
            // Simular erro de UNIQUE violation do PostgreSQL
            const dbError = new Error('Unique violation');
            dbError.code = '23505';
            mockClient.query.mockRejectedValueOnce(dbError);

            const res = await request(app)
                .post('/api/avaliacoes/cliente')
                .set('Authorization', `Bearer ${tokenCliente}`)
                .send({ chamado_id: 'chamado-2', nota: 4 });

            expect(res.statusCode).toBe(409);
            expect(res.body.erro).toContain('já avaliou');
        });
    });

    // ─── TESTES: PROFISSIONAL AVALIA CLIENTE ──────────────────────
    describe('Profissional avaliando Cliente', () => {
        
        it('deve registrar avaliação do cliente com sucesso', async () => {
            mockClient.query.mockResolvedValueOnce({});
            mockClient.query.mockResolvedValueOnce({ 
                rows: [{ cliente_id: 'cliente-999', profissional_id: 'prof-456', status: 'finalizado' }] 
            });
            mockClient.query.mockResolvedValueOnce({
                rows: [{ id: 'aval-999', nota: 5 }]
            });
            mockClient.query.mockResolvedValueOnce({
                rows: [{ nota_media: "5.00", total_avaliacoes: 2 }]
            });
            mockClient.query.mockResolvedValueOnce({});

            const res = await request(app)
                .post('/api/avaliacoes/profissional')
                .set('Authorization', `Bearer ${tokenProfissional}`)
                .send({ chamado_id: 'chamado-3', nota: 5 });

            expect(res.statusCode).toBe(201);
            expect(res.body.nova_media_cliente).toBe("5.00");
        });
        
        it('deve rejeitar se o profissional não realizou o chamado', async () => {
            mockClient.query.mockResolvedValueOnce({});
            mockClient.query.mockResolvedValueOnce({ 
                // Chamado foi realizado por OUTRO profissional
                rows: [{ cliente_id: 'cliente-123', profissional_id: 'outro-prof', status: 'finalizado' }] 
            });

            const res = await request(app)
                .post('/api/avaliacoes/profissional')
                .set('Authorization', `Bearer ${tokenProfissional}`)
                .send({ chamado_id: 'chamado-4', nota: 4 });

            expect(res.statusCode).toBe(403);
            expect(res.body.erro).toContain('Você só pode avaliar serviços que você realizou');
        });
    });

});
