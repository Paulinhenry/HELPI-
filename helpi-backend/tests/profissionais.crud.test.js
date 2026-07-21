// =============================================================
// HELPI - Testes CRUD de Profissionais
// Pilar 1 > Domínio de Profissionais
//
// Testa: registar, listar, ver perfil, atualizar, FCM token
// =============================================================

const request = require('supertest');
const app = require('../src/app');
const pool = require('../src/config/database');
const { gerarTokenProfissional, gerarTokenCliente } = require('./setup');

describe('👷 Profissionais — CRUD Completo', () => {

    let profissionalTesteId;
    let tokenProfissional;

    const PROF_EMAIL = 'crud.prof.test@helpi.com';
    const PROF_CPF = '77700011122233';

    afterAll(async () => {
        // Limpa os dados de teste
        await pool.query(`DELETE FROM profissionais WHERE email = $1`, [PROF_EMAIL]);
    });

    // ─── REGISTAR ──────────────────────────────────────────────
    describe('POST /api/profissionais (Registar)', () => {

        it('deve registar profissional com dados válidos (201)', async () => {
            const res = await request(app)
                .post('/api/profissionais')
                .send({
                    nome: 'Prof CRUD Test',
                    cpf_cnpj: PROF_CPF,
                    email: PROF_EMAIL,
                    senha: 'SenhaSegura@123',
                    telefone: '(44) 99999-0099',
                    categoria: 'Eletricista',
                    biografia: 'Profissional de teste CRUD'
                });

            expect(res.statusCode).toBe(201);
            expect(res.body).toHaveProperty('profissional');
            expect(res.body.profissional).toHaveProperty('id');
            expect(res.body.profissional.status).toBe('pendente_aprovacao');
            expect(res.body.profissional.categoria).toBe('Eletricista');

            profissionalTesteId = res.body.profissional.id;
        });

        it('deve rejeitar email duplicado (erro de constraint)', async () => {
            const res = await request(app)
                .post('/api/profissionais')
                .send({
                    nome: 'Prof Duplicado',
                    cpf_cnpj: '88800011122299',
                    email: PROF_EMAIL, // mesmo email
                    senha: 'SenhaSegura@123',
                    telefone: '(44) 99999-0098',
                    categoria: 'Encanador'
                });

            // PostgreSQL unique constraint deve rejeitar (409 Conflict)
            expect(res.statusCode).toBe(409);
        });
    });

    // ─── LISTAR ────────────────────────────────────────────────
    describe('GET /api/profissionais (Listar)', () => {

        it('deve retornar lista de profissionais aprovados com paginação (200)', async () => {
            const res = await request(app)
                .get('/api/profissionais');

            expect(res.statusCode).toBe(200);
            expect(res.body).toHaveProperty('profissionais');
            expect(Array.isArray(res.body.profissionais)).toBe(true);
            expect(res.body).toHaveProperty('paginacao');
            expect(res.body.paginacao).toHaveProperty('tem_mais');
        });

        it('deve filtrar por categoria', async () => {
            const res = await request(app)
                .get('/api/profissionais?categoria=Eletricista');

            expect(res.statusCode).toBe(200);
            // Todos os retornados devem ser Eletricista
            res.body.profissionais.forEach(prof => {
                expect(prof.categoria).toBe('Eletricista');
            });
        });

        it('deve respeitar o limit de paginação', async () => {
            const res = await request(app)
                .get('/api/profissionais?limit=2');

            expect(res.statusCode).toBe(200);
            expect(res.body.profissionais.length).toBeLessThanOrEqual(2);
        });
    });

    // ─── VER PERFIL ────────────────────────────────────────────
    describe('GET /api/profissionais/:id (Ver Perfil)', () => {

        it('deve retornar perfil de profissional existente (200)', async () => {
            // Busca qualquer profissional aprovado no banco
            const qualquer = await pool.query(`SELECT id FROM profissionais WHERE status = 'aprovado' LIMIT 1`);
            if (qualquer.rows.length === 0) return; // Pula se não há profissionais

            const res = await request(app)
                .get(`/api/profissionais/${qualquer.rows[0].id}`);

            expect(res.statusCode).toBe(200);
            expect(res.body).toHaveProperty('id');
            expect(res.body).toHaveProperty('nome');
            expect(res.body).toHaveProperty('categoria');
            expect(res.body).toHaveProperty('ultimas_avaliacoes');
            expect(Array.isArray(res.body.ultimas_avaliacoes)).toBe(true);
        });

        it('deve retornar 404 para ID inexistente', async () => {
            const res = await request(app)
                .get('/api/profissionais/550e8400-e29b-41d4-a716-446655440000');

            expect(res.statusCode).toBe(404);
            expect(res.body.erro).toContain('não encontrado');
        });

        it('deve retornar 400 para UUID inválido', async () => {
            const res = await request(app)
                .get('/api/profissionais/nao-e-um-uuid');

            expect(res.statusCode).toBe(400);
        });
    });

    // ─── ATUALIZAR PERFIL ──────────────────────────────────────
    describe('PUT /api/profissionais/perfil (Atualizar)', () => {

        it('deve atualizar perfil com campos válidos (200)', async () => {
            // Usa o profissional de teste que foi criado acima e aprova-o
            await pool.query(`UPDATE profissionais SET status = 'aprovado' WHERE id = $1`, [profissionalTesteId]);
            tokenProfissional = gerarTokenProfissional(profissionalTesteId);

            const res = await request(app)
                .put('/api/profissionais/perfil')
                .set('Authorization', `Bearer ${tokenProfissional}`)
                .send({ nome: 'Nome Atualizado Test', biografia: 'Bio atualizada via teste' });

            expect(res.statusCode).toBe(200);
            expect(res.body.profissional.nome).toBe('Nome Atualizado Test');
        });

        it('deve rejeitar atualização sem campos (400)', async () => {
            tokenProfissional = gerarTokenProfissional(profissionalTesteId);

            const res = await request(app)
                .put('/api/profissionais/perfil')
                .set('Authorization', `Bearer ${tokenProfissional}`)
                .send({});

            expect(res.statusCode).toBe(400);
            expect(res.body.erro).toContain('Nenhum campo');
        });

        it('deve rejeitar sem token (401)', async () => {
            const res = await request(app)
                .put('/api/profissionais/perfil')
                .send({ nome: 'Sem Token' });

            expect(res.statusCode).toBe(401);
        });
    });

    // ─── FCM TOKEN ─────────────────────────────────────────────
    describe('PUT /api/profissionais/fcm-token (Token FCM)', () => {

        it('deve registar FCM token válido (200)', async () => {
            const aprovado = await pool.query(`SELECT id FROM profissionais WHERE status = 'aprovado' LIMIT 1`);
            if (aprovado.rows.length === 0) return;

            const token = gerarTokenProfissional(aprovado.rows[0].id);

            const res = await request(app)
                .put('/api/profissionais/fcm-token')
                .set('Authorization', `Bearer ${token}`)
                .send({ fcm_token: 'dummyFcmToken123456789_test' });

            expect(res.statusCode).toBe(200);
            expect(res.body.mensagem).toContain('FCM');
        });

        it('deve rejeitar FCM token vazio (400)', async () => {
            const aprovado = await pool.query(`SELECT id FROM profissionais WHERE status = 'aprovado' LIMIT 1`);
            if (aprovado.rows.length === 0) return;

            const token = gerarTokenProfissional(aprovado.rows[0].id);

            const res = await request(app)
                .put('/api/profissionais/fcm-token')
                .set('Authorization', `Bearer ${token}`)
                .send({ fcm_token: '' });

            expect(res.statusCode).toBe(400);
        });

        it('deve rejeitar sem token de autenticação (401)', async () => {
            const res = await request(app)
                .put('/api/profissionais/fcm-token')
                .send({ fcm_token: 'dummy123' });

            expect(res.statusCode).toBe(401);
        });

        it('deve funcionar para clientes também', async () => {
            const clienteResult = await pool.query(`SELECT id FROM clientes LIMIT 1`);
            if (clienteResult.rows.length === 0) return;

            const token = gerarTokenCliente(clienteResult.rows[0].id);

            const res = await request(app)
                .put('/api/profissionais/fcm-token')
                .set('Authorization', `Bearer ${token}`)
                .send({ fcm_token: 'dummyFcmTokenCliente_test' });

            expect(res.statusCode).toBe(200);
        });
    });
});
