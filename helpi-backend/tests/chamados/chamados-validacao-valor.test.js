// =============================================================
// HELPI - Testes de Validação de Valor na Finalização
// Pilar 2 > Operações > Validação Financeira
//
// Testa: Valor cobrado dentro/fora do intervalo estimado
//        valor_cobrado ausente, NaN, abaixo do mínimo, acima de 130%
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

describe('💰 Chamados — Validação de Valor na Finalização', () => {

    let clienteId;
    let profissionalId;
    let tokenProfissional;
    let chamadoEmServicoId;

    const criarChamadoEmServico = async (valorMin, valorMax) => {
        const ch = await pool.query(`
            INSERT INTO chamados_express 
            (cliente_id, profissional_id, categoria_solicitada, problema_descricao, 
             latitude_destino, longitude_destino, status, valor_estimado_min, valor_estimado_max,
             aceite_em, chegou_ao_local_em)
            VALUES ($1, $2, 'Eletricista', '[TEST_VALOR] Chamado para validação',
                    -23.557, -46.662, 'em_servico', $3, $4,
                    CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            RETURNING id
        `, [clienteId, profissionalId, valorMin, valorMax]);
        return ch.rows[0].id;
    };

    beforeAll(async () => {
        const senhaHash = await bcrypt.hash('Teste@123', 10);

        await pool.query(`DELETE FROM chamados_express WHERE problema_descricao LIKE '%[TEST_VALOR]%'`);
        await pool.query(`DELETE FROM clientes WHERE email = 'valor.test.cli@helpi.com'`);
        await pool.query(`DELETE FROM profissionais WHERE email = 'valor.test.prof@helpi.com'`);

        const cli = await pool.query(`
            INSERT INTO clientes (nome, cpf, email, senha, telefone)
            VALUES ('Valor Client', '33300044411', 'valor.test.cli@helpi.com', $1, '11999990070')
            RETURNING id
        `, [senhaHash]);
        clienteId = cli.rows[0].id;

        const prof = await pool.query(`
            INSERT INTO profissionais (nome, cpf_cnpj, email, senha, telefone, categoria, status)
            VALUES ('Valor Prof', '33300044455566', 'valor.test.prof@helpi.com', $1, '11999990071', 'Eletricista', 'aprovado')
            RETURNING id
        `, [senhaHash]);
        profissionalId = prof.rows[0].id;
        tokenProfissional = gerarToken(profissionalId, 'profissional');
    });

    afterAll(async () => {
        await pool.query(`DELETE FROM chamados_express WHERE problema_descricao LIKE '%[TEST_VALOR]%'`);
        await pool.query(`DELETE FROM clientes WHERE email = 'valor.test.cli@helpi.com'`);
        await pool.query(`DELETE FROM profissionais WHERE email = 'valor.test.prof@helpi.com'`);
    });

    it('deve rejeitar finalização sem valor_cobrado (400)', async () => {
        const id = await criarChamadoEmServico(50, 150);

        const res = await request(app)
            .put(`/api/chamados/${id}/finalizar`)
            .set('Authorization', `Bearer ${tokenProfissional}`)
            .send({}); // sem valor

        expect(res.statusCode).toBe(400);
        expect(res.body.erro).toContain('valor cobrado');
    });

    it('deve rejeitar finalização com valor NaN (400)', async () => {
        const id = await criarChamadoEmServico(50, 150);

        const res = await request(app)
            .put(`/api/chamados/${id}/finalizar`)
            .set('Authorization', `Bearer ${tokenProfissional}`)
            .send({ valor_cobrado: 'abc' });

        expect(res.statusCode).toBe(400);
    });

    it('deve rejeitar valor abaixo do mínimo estimado (400)', async () => {
        const id = await criarChamadoEmServico(100, 200);

        const res = await request(app)
            .put(`/api/chamados/${id}/finalizar`)
            .set('Authorization', `Bearer ${tokenProfissional}`)
            .send({ valor_cobrado: 10 }); // Muito abaixo de 100

        expect(res.statusCode).toBe(400);
        expect(res.body.erro).toContain('fora do intervalo');
    });

    it('deve rejeitar valor acima de 130% do máximo estimado (400)', async () => {
        const id = await criarChamadoEmServico(100, 200);

        const res = await request(app)
            .put(`/api/chamados/${id}/finalizar`)
            .set('Authorization', `Bearer ${tokenProfissional}`)
            .send({ valor_cobrado: 999 }); // Muito acima de 200 * 1.30

        expect(res.statusCode).toBe(400);
        expect(res.body.erro).toContain('fora do intervalo');
    });

    it('deve aceitar valor dentro do intervalo (200)', async () => {
        const id = await criarChamadoEmServico(100, 200);

        const res = await request(app)
            .put(`/api/chamados/${id}/finalizar`)
            .set('Authorization', `Bearer ${tokenProfissional}`)
            .send({ valor_cobrado: 150 }); // Dentro de [100, 260]

        expect(res.statusCode).toBe(200);
        expect(res.body.chamado.status).toBe('finalizado');
        expect(parseFloat(res.body.chamado.valor_cobrado)).toBe(150);
    });

    it('deve aceitar valor no limite máximo (130% do max) (200)', async () => {
        const id = await criarChamadoEmServico(100, 200);

        const res = await request(app)
            .put(`/api/chamados/${id}/finalizar`)
            .set('Authorization', `Bearer ${tokenProfissional}`)
            .send({ valor_cobrado: 260 }); // Exatamente 200 * 1.30

        expect(res.statusCode).toBe(200);
        expect(res.body.chamado.status).toBe('finalizado');
    });

    it('deve rejeitar profissional diferente do dono do chamado (403)', async () => {
        const id = await criarChamadoEmServico(100, 200);
        const tokenOutro = gerarToken('00000000-0000-0000-0000-111111111111', 'profissional');

        const res = await request(app)
            .put(`/api/chamados/${id}/finalizar`)
            .set('Authorization', `Bearer ${tokenOutro}`)
            .send({ valor_cobrado: 150 });

        expect(res.statusCode).toBe(403);
    });
});
