// =============================================================
// HELPI - Testes de Login Real (Cliente + Profissional)
// Pilar 1 > Domínio de Autenticação
//
// Testa: loginCliente, loginProfissional com DB real
// NOTA: Usa bcrypt para hash real — testa o fluxo completo
// =============================================================

const request = require('supertest');
const app = require('../../src/app');
const pool = require('../../src/config/database');
const bcrypt = require('bcrypt');

describe('🔑 Auth Login — Fluxo Real com Banco de Dados', () => {

    const EMAIL_CLIENTE = 'teste.login.cliente@helpi.com';
    const EMAIL_PROF = 'teste.login.prof@helpi.com';
    const EMAIL_PROF_PENDENTE = 'teste.login.pendente@helpi.com';
    const SENHA_RAW = 'SenhaForte@123';

    beforeAll(async () => {
        const senhaHash = await bcrypt.hash(SENHA_RAW, 10);

        // Limpa dados de testes anteriores
        await pool.query(`DELETE FROM clientes WHERE email IN ($1)`, [EMAIL_CLIENTE]);
        await pool.query(`DELETE FROM profissionais WHERE email IN ($1, $2)`, [EMAIL_PROF, EMAIL_PROF_PENDENTE]);

        // Cria cliente de teste
        await pool.query(`
            INSERT INTO clientes (nome, cpf, email, senha, telefone)
            VALUES ('Cliente Login Test', '00011122233', $1, $2, '11999990001')
        `, [EMAIL_CLIENTE, senhaHash]);

        // Cria profissional aprovado de teste
        await pool.query(`
            INSERT INTO profissionais (nome, cpf_cnpj, email, senha, telefone, categoria, status)
            VALUES ('Prof Login Test', '00011122233344', $1, $2, '11999990002', 'Eletricista', 'aprovado')
        `, [EMAIL_PROF, senhaHash]);

        // Cria profissional pendente de teste
        await pool.query(`
            INSERT INTO profissionais (nome, cpf_cnpj, email, senha, telefone, categoria, status)
            VALUES ('Prof Pendente Test', '00011122233355', $1, $2, '11999990003', 'Encanador', 'aguardando_aprovacao')
        `, [EMAIL_PROF_PENDENTE, senhaHash]);
    });

    afterAll(async () => {
        await pool.query(`DELETE FROM clientes WHERE email = $1`, [EMAIL_CLIENTE]);
        await pool.query(`DELETE FROM profissionais WHERE email IN ($1, $2)`, [EMAIL_PROF, EMAIL_PROF_PENDENTE]);
    });

    // ─── LOGIN CLIENTE ─────────────────────────────────────────
    describe('POST /api/login/clientes', () => {

        it('deve autenticar cliente com credenciais válidas (200)', async () => {
            const res = await request(app)
                .post('/api/login/clientes')
                .send({ email: EMAIL_CLIENTE, senha: SENHA_RAW });

            expect(res.statusCode).toBe(200);
            expect(res.body).toHaveProperty('access_token');
            expect(res.body).toHaveProperty('refresh_token');
            expect(res.body).toHaveProperty('token'); // retrocompat
            expect(res.body.usuario.tipo).toBe('cliente');
            expect(res.body.usuario.email).toBe(EMAIL_CLIENTE);
        });

        it('deve rejeitar email inexistente (401)', async () => {
            const res = await request(app)
                .post('/api/login/clientes')
                .send({ email: 'naoexiste@helpi.com', senha: SENHA_RAW });

            expect(res.statusCode).toBe(401);
            expect(res.body.erro).toContain('inválidos');
        });

        it('deve rejeitar senha incorreta (401)', async () => {
            const res = await request(app)
                .post('/api/login/clientes')
                .send({ email: EMAIL_CLIENTE, senha: 'SenhaErrada999' });

            expect(res.statusCode).toBe(401);
            expect(res.body.erro).toContain('inválidos');
        });

        it('deve retornar o objeto usuario com id, nome, email e tipo', async () => {
            const res = await request(app)
                .post('/api/login/clientes')
                .send({ email: EMAIL_CLIENTE, senha: SENHA_RAW });

            expect(res.body.usuario).toHaveProperty('id');
            expect(res.body.usuario).toHaveProperty('nome');
            expect(res.body.usuario).toHaveProperty('email');
            expect(res.body.usuario.tipo).toBe('cliente');
        });
    });

    // ─── LOGIN PROFISSIONAL ────────────────────────────────────
    describe('POST /api/login/profissionais', () => {

        it('deve autenticar profissional aprovado com credenciais válidas (200)', async () => {
            const res = await request(app)
                .post('/api/login/profissionais')
                .send({ email: EMAIL_PROF, senha: SENHA_RAW });

            expect(res.statusCode).toBe(200);
            expect(res.body).toHaveProperty('access_token');
            expect(res.body).toHaveProperty('refresh_token');
            expect(res.body.usuario.tipo).toBe('profissional');
        });

        it('deve rejeitar profissional com status aguardando_aprovacao (403)', async () => {
            const res = await request(app)
                .post('/api/login/profissionais')
                .send({ email: EMAIL_PROF_PENDENTE, senha: SENHA_RAW });

            expect(res.statusCode).toBe(403);
            expect(res.body.erro).toContain('aprovada');
            expect(res.body).toHaveProperty('status_conta');
        });

        it('deve rejeitar email inexistente (401)', async () => {
            const res = await request(app)
                .post('/api/login/profissionais')
                .send({ email: 'fantasma@helpi.com', senha: SENHA_RAW });

            expect(res.statusCode).toBe(401);
            expect(res.body.erro).toContain('inválidos');
        });

        it('deve rejeitar senha incorreta (401)', async () => {
            const res = await request(app)
                .post('/api/login/profissionais')
                .send({ email: EMAIL_PROF, senha: 'TotalmenteErrada' });

            expect(res.statusCode).toBe(401);
            expect(res.body.erro).toContain('inválidos');
        });
    });
});
