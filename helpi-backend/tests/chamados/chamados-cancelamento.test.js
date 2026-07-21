// =============================================================
// HELPI - Testes de Cancelamento de Chamados
// Pilar 2 > Operações > Cancelamento
//
// Testa: PATCH /api/chamados/:id/cancelar
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

describe('🚫 Chamados — Cancelamento', () => {

    let clienteId;
    let outroClienteId;
    let profissionalId;
    let tokenCliente;
    let tokenOutroCliente;
    let tokenProfissional;
    let chamadoProcurandoId;
    let chamadoAceitoId;

    beforeAll(async () => {
        const senhaHash = await bcrypt.hash('Teste@123', 10);

        // Limpa dados anteriores
        await pool.query(`DELETE FROM chamados_express WHERE problema_descricao LIKE '%[TEST_CANCEL]%'`);
        await pool.query(`DELETE FROM clientes WHERE email IN ('cancel.test.c1@helpi.com', 'cancel.test.c2@helpi.com')`);
        await pool.query(`DELETE FROM profissionais WHERE email = 'cancel.test.prof@helpi.com'`);

        // Cria clientes de teste
        const c1 = await pool.query(`
            INSERT INTO clientes (nome, cpf, email, senha, telefone)
            VALUES ('Cancel Client 1', '11100022211', 'cancel.test.c1@helpi.com', $1, '11999990050')
            RETURNING id
        `, [senhaHash]);
        clienteId = c1.rows[0].id;
        tokenCliente = gerarToken(clienteId, 'cliente');

        const c2 = await pool.query(`
            INSERT INTO clientes (nome, cpf, email, senha, telefone)
            VALUES ('Cancel Client 2', '11100022222', 'cancel.test.c2@helpi.com', $1, '11999990051')
            RETURNING id
        `, [senhaHash]);
        outroClienteId = c2.rows[0].id;
        tokenOutroCliente = gerarToken(outroClienteId, 'cliente');

        // Cria profissional de teste
        const prof = await pool.query(`
            INSERT INTO profissionais (nome, cpf_cnpj, email, senha, telefone, categoria, status, is_online, latitude_atual, longitude_atual)
            VALUES ('Cancel Prof', '11100022233344', 'cancel.test.prof@helpi.com', $1, '11999990052', 'Eletricista', 'aprovado', true, -23.561, -46.655)
            RETURNING id
        `, [senhaHash]);
        profissionalId = prof.rows[0].id;
        tokenProfissional = gerarToken(profissionalId, 'profissional');

        // Chamado em "procurando" (cancelável)
        const ch1 = await pool.query(`
            INSERT INTO chamados_express (cliente_id, categoria_solicitada, problema_descricao, latitude_destino, longitude_destino, status)
            VALUES ($1, 'Eletricista', '[TEST_CANCEL] Chamado cancelável', -23.557, -46.662, 'procurando_profissional')
            RETURNING id
        `, [clienteId]);
        chamadoProcurandoId = ch1.rows[0].id;

        // Chamado já aceite (não cancelável)
        const ch2 = await pool.query(`
            INSERT INTO chamados_express (cliente_id, profissional_id, categoria_solicitada, problema_descricao, latitude_destino, longitude_destino, status)
            VALUES ($1, $2, 'Eletricista', '[TEST_CANCEL] Chamado aceite', -23.557, -46.662, 'a_caminho')
            RETURNING id
        `, [clienteId, profissionalId]);
        chamadoAceitoId = ch2.rows[0].id;
    });

    afterAll(async () => {
        await pool.query(`DELETE FROM chamados_express WHERE problema_descricao LIKE '%[TEST_CANCEL]%'`);
        await pool.query(`DELETE FROM clientes WHERE email IN ('cancel.test.c1@helpi.com', 'cancel.test.c2@helpi.com')`);
        await pool.query(`DELETE FROM profissionais WHERE email = 'cancel.test.prof@helpi.com'`);
    });

    it('deve cancelar chamado em status "procurando_profissional" (200)', async () => {
        const res = await request(app)
            .patch(`/api/chamados/${chamadoProcurandoId}/cancelar`)
            .set('Authorization', `Bearer ${tokenCliente}`);

        expect(res.statusCode).toBe(200);
        expect(res.body.chamado.status).toBe('cancelado_pelo_cliente');
    });

    it('deve rejeitar cancelamento de chamado já aceite (400)', async () => {
        const res = await request(app)
            .patch(`/api/chamados/${chamadoAceitoId}/cancelar`)
            .set('Authorization', `Bearer ${tokenCliente}`);

        expect(res.statusCode).toBe(400);
        expect(res.body.erro).toBeDefined();
    });

    it('deve rejeitar cancelamento por outro cliente (400)', async () => {
        // Cria novo chamado procurando para testar
        const ch = await pool.query(`
            INSERT INTO chamados_express (cliente_id, categoria_solicitada, problema_descricao, latitude_destino, longitude_destino, status)
            VALUES ($1, 'Eletricista', '[TEST_CANCEL] Chamado outro dono', -23.557, -46.662, 'procurando_profissional')
            RETURNING id
        `, [clienteId]);

        const res = await request(app)
            .patch(`/api/chamados/${ch.rows[0].id}/cancelar`)
            .set('Authorization', `Bearer ${tokenOutroCliente}`); // OUTRO cliente

        expect(res.statusCode).toBe(400);
    });

    it('deve rejeitar cancelamento de chamado inexistente (400)', async () => {
        const res = await request(app)
            .patch('/api/chamados/00000000-0000-0000-0000-000000000000/cancelar')
            .set('Authorization', `Bearer ${tokenCliente}`);

        expect(res.statusCode).toBe(400);
    });

    it('deve rejeitar pedido sem token (401)', async () => {
        const res = await request(app)
            .patch(`/api/chamados/${chamadoProcurandoId}/cancelar`);

        expect(res.statusCode).toBe(401);
    });
});
