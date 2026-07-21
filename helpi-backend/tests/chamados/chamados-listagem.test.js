// =============================================================
// HELPI - Testes de Listagem + Crash Recovery
// Pilar 2 > Operações > Listagem e Recovery
//
// Testa: listarMeusChamados, verificarChamadoAtivo,
//        verificarChamadoAtivoCliente
// =============================================================

const request = require('supertest');
const app = require('../../src/app');
const pool = require('../../src/config/database');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');

const gerarToken = (id, tipo) => jwt.sign(
    { id, tipo, tokenType: 'access' },
    process.env.JWT_SECRET,
    { expiresIn: '15m' }
);

describe('📋 Chamados — Listagem e Crash Recovery', () => {

    let clienteId;
    let profissionalId;
    let tokenCliente;
    let tokenProfissional;
    let chamadoAtivoId;

    beforeAll(async () => {
        const senhaHash = await bcrypt.hash('Teste@123', 10);

        await pool.query(`DELETE FROM chamados_express WHERE problema_descricao LIKE '%[TEST_LIST]%'`);
        await pool.query(`DELETE FROM clientes WHERE email = 'list.test.cli@helpi.com'`);
        await pool.query(`DELETE FROM profissionais WHERE email = 'list.test.prof@helpi.com'`);

        // Cria cliente
        const cli = await pool.query(`
            INSERT INTO clientes (nome, cpf, email, senha, telefone)
            VALUES ('List Client', '22200033311', 'list.test.cli@helpi.com', $1, '11999990060')
            RETURNING id
        `, [senhaHash]);
        clienteId = cli.rows[0].id;
        tokenCliente = gerarToken(clienteId, 'cliente');

        // Cria profissional
        const prof = await pool.query(`
            INSERT INTO profissionais (nome, cpf_cnpj, email, senha, telefone, categoria, status)
            VALUES ('List Prof', '22200033344455', 'list.test.prof@helpi.com', $1, '11999990061', 'Eletricista', 'aprovado')
            RETURNING id
        `, [senhaHash]);
        profissionalId = prof.rows[0].id;
        tokenProfissional = gerarToken(profissionalId, 'profissional');

        // Cria alguns chamados para o cliente
        await pool.query(`
            INSERT INTO chamados_express (cliente_id, categoria_solicitada, problema_descricao, latitude_destino, longitude_destino, status)
            VALUES ($1, 'Eletricista', '[TEST_LIST] Chamado 1 finalizado', -23.557, -46.662, 'finalizado')
        `, [clienteId]);

        await pool.query(`
            INSERT INTO chamados_express (cliente_id, categoria_solicitada, problema_descricao, latitude_destino, longitude_destino, status)
            VALUES ($1, 'Eletricista', '[TEST_LIST] Chamado 2 finalizado', -23.557, -46.662, 'finalizado')
        `, [clienteId]);

        // Chamado ativo (a_caminho) para crash recovery
        const ativo = await pool.query(`
            INSERT INTO chamados_express (cliente_id, profissional_id, categoria_solicitada, problema_descricao, latitude_destino, longitude_destino, status, aceite_em)
            VALUES ($1, $2, 'Eletricista', '[TEST_LIST] Chamado ativo', -23.557, -46.662, 'a_caminho', CURRENT_TIMESTAMP)
            RETURNING id
        `, [clienteId, profissionalId]);
        chamadoAtivoId = ativo.rows[0].id;
    });

    afterAll(async () => {
        await pool.query(`DELETE FROM chamados_express WHERE problema_descricao LIKE '%[TEST_LIST]%'`);
        await pool.query(`DELETE FROM clientes WHERE email = 'list.test.cli@helpi.com'`);
        await pool.query(`DELETE FROM profissionais WHERE email = 'list.test.prof@helpi.com'`);
    });

    // ─── LISTAR MEUS CHAMADOS ──────────────────────────────────
    describe('GET /api/chamados (Listar do Cliente)', () => {

        it('deve retornar chamados do cliente autenticado (200)', async () => {
            const res = await request(app)
                .get('/api/chamados')
                .set('Authorization', `Bearer ${tokenCliente}`);

            expect(res.statusCode).toBe(200);
            expect(res.body).toHaveProperty('chamados');
            expect(Array.isArray(res.body.chamados)).toBe(true);
            expect(res.body.chamados.length).toBeGreaterThanOrEqual(2);
        });

        it('deve incluir paginação cursor-based', async () => {
            const res = await request(app)
                .get('/api/chamados?limit=1')
                .set('Authorization', `Bearer ${tokenCliente}`);

            expect(res.statusCode).toBe(200);
            expect(res.body).toHaveProperty('paginacao');
            expect(res.body.paginacao).toHaveProperty('tem_mais');
            expect(res.body.chamados.length).toBeLessThanOrEqual(1);
        });

        it('deve respeitar cursor de paginação', async () => {
            // Primeira página
            const page1 = await request(app)
                .get('/api/chamados?limit=1')
                .set('Authorization', `Bearer ${tokenCliente}`);

            if (page1.body.paginacao.proximo_cursor) {
                // Segunda página
                const page2 = await request(app)
                    .get(`/api/chamados?limit=1&cursor=${page1.body.paginacao.proximo_cursor}`)
                    .set('Authorization', `Bearer ${tokenCliente}`);

                expect(page2.statusCode).toBe(200);
                expect(page2.body.chamados[0].id).not.toBe(page1.body.chamados[0].id);
            }
        });

        it('deve rejeitar sem token (401)', async () => {
            const res = await request(app)
                .get('/api/chamados');

            expect(res.statusCode).toBe(401);
        });
    });

    // ─── CRASH RECOVERY — PROFISSIONAL ─────────────────────────
    describe('GET /api/chamados/em-andamento (Crash Recovery Profissional)', () => {

        it('deve retornar chamado ativo quando existe (200)', async () => {
            const res = await request(app)
                .get('/api/chamados/em-andamento')
                .set('Authorization', `Bearer ${tokenProfissional}`);

            expect(res.statusCode).toBe(200);
            expect(res.body.chamado_ativo).not.toBeNull();
            expect(res.body.chamado_ativo.id).toBe(chamadoAtivoId);
            expect(['a_caminho', 'em_servico']).toContain(res.body.chamado_ativo.status);
        });

        it('deve retornar null quando não há chamado ativo', async () => {
            // Cria profissional sem chamado ativo
            const tokenSemAtivo = gerarToken('00000000-0000-0000-0000-999999999999', 'profissional');

            const res = await request(app)
                .get('/api/chamados/em-andamento')
                .set('Authorization', `Bearer ${tokenSemAtivo}`);

            expect(res.statusCode).toBe(200);
            expect(res.body.chamado_ativo).toBeNull();
        });

        it('deve rejeitar sem token (401)', async () => {
            const res = await request(app)
                .get('/api/chamados/em-andamento');

            expect(res.statusCode).toBe(401);
        });
    });

    // ─── CRASH RECOVERY — CLIENTE ──────────────────────────────
    describe('GET /api/chamados/meu-ativo (Crash Recovery Cliente)', () => {

        it('deve retornar chamado ativo do cliente quando existe (200)', async () => {
            const res = await request(app)
                .get('/api/chamados/meu-ativo')
                .set('Authorization', `Bearer ${tokenCliente}`);

            expect(res.statusCode).toBe(200);
            expect(res.body.chamado_ativo).not.toBeNull();
            expect(res.body.chamado_ativo.id).toBe(chamadoAtivoId);
        });

        it('deve retornar null quando não há chamado ativo para o cliente', async () => {
            const tokenSemAtivo = gerarToken('00000000-0000-0000-0000-888888888888', 'cliente');

            const res = await request(app)
                .get('/api/chamados/meu-ativo')
                .set('Authorization', `Bearer ${tokenSemAtivo}`);

            expect(res.statusCode).toBe(200);
            expect(res.body.chamado_ativo).toBeNull();
        });

        it('deve rejeitar sem token (401)', async () => {
            const res = await request(app)
                .get('/api/chamados/meu-ativo');

            expect(res.statusCode).toBe(401);
        });
    });
});
