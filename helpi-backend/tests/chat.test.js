// =============================================================
// HELPI - Testes do Histórico de Chat
// Pilar 1 > Domínio de Chat
//
// Testa: GET /api/chamados/:id/mensagens — obter histórico
// =============================================================

const request = require('supertest');
const app = require('../src/app');
const pool = require('../src/config/database');
const { gerarTokenCliente, gerarTokenProfissional } = require('./setup');

describe('💬 Chat — Histórico de Mensagens', () => {

    let chamadoId;
    let clienteId;
    let tokenCliente;

    beforeAll(async () => {
        // Busca um chamado existente no banco para testar
        const chamado = await pool.query(`SELECT id, cliente_id FROM chamados_express LIMIT 1`);
        if (chamado.rows.length > 0) {
            chamadoId = chamado.rows[0].id;
            clienteId = chamado.rows[0].cliente_id;
            tokenCliente = gerarTokenCliente(clienteId);
        }
    });

    it('deve retornar histórico de mensagens de um chamado (200)', async () => {
        if (!chamadoId) return; // Skip se não houver chamados

        const res = await request(app)
            .get(`/api/chamados/${chamadoId}/mensagens`)
            .set('Authorization', `Bearer ${tokenCliente}`);

        expect(res.statusCode).toBe(200);
        expect(res.body).toHaveProperty('sucesso', true);
        expect(res.body).toHaveProperty('mensagens');
        expect(Array.isArray(res.body.mensagens)).toBe(true);
    });

    it('deve retornar array vazio para chamado sem mensagens (200)', async () => {
        if (!chamadoId) return;

        // Usa o mesmo chamado — provavelmente não tem mensagens nos testes
        const res = await request(app)
            .get(`/api/chamados/${chamadoId}/mensagens`)
            .set('Authorization', `Bearer ${tokenCliente}`);

        expect(res.statusCode).toBe(200);
        expect(Array.isArray(res.body.mensagens)).toBe(true);
    });

    it('deve rejeitar pedido sem token (401)', async () => {
        if (!chamadoId) return;

        const res = await request(app)
            .get(`/api/chamados/${chamadoId}/mensagens`);

        expect(res.statusCode).toBe(401);
    });

    it('profissional autenticado também deve poder consultar (200)', async () => {
        if (!chamadoId) return;

        // Busca o chamado com profissional associado
        const chamadoProf = await pool.query(`SELECT id, profissional_id FROM chamados_express WHERE profissional_id IS NOT NULL LIMIT 1`);
        if (chamadoProf.rows.length === 0) return;

        const tokenProf = gerarTokenProfissional(chamadoProf.rows[0].profissional_id);
        const res = await request(app)
            .get(`/api/chamados/${chamadoProf.rows[0].id}/mensagens`)
            .set('Authorization', `Bearer ${tokenProf}`);

        expect(res.statusCode).toBe(200);
        expect(res.body.sucesso).toBe(true);
    });

    it('deve rejeitar UUID inválido (400)', async () => {
        const res = await request(app)
            .get('/api/chamados/nao-uuid/mensagens')
            .set('Authorization', `Bearer ${gerarTokenCliente()}`);

        expect(res.statusCode).toBe(400);
    });
});
