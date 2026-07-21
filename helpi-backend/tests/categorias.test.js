// =============================================================
// HELPI - Testes da Rota de Categorias
// Pilar 1 > Domínio de Categorias
//
// Testa: GET /api/categorias — listar categorias disponíveis
// =============================================================

const request = require('supertest');
const app = require('../src/app');
const { gerarTokenCliente } = require('./setup');

describe('📋 Categorias — Listagem', () => {

    const token = gerarTokenCliente();

    it('deve retornar lista de categorias com sucesso (200)', async () => {
        const res = await request(app)
            .get('/api/categorias')
            .set('Authorization', `Bearer ${token}`);

        expect(res.statusCode).toBe(200);
        expect(res.body).toHaveProperty('categorias');
        expect(Array.isArray(res.body.categorias)).toBe(true);
        expect(res.body.categorias.length).toBeGreaterThan(0);
    });

    it('resposta deve conter mensagem de sucesso', async () => {
        const res = await request(app)
            .get('/api/categorias')
            .set('Authorization', `Bearer ${token}`);

        expect(res.body).toHaveProperty('mensagem');
        expect(res.body.mensagem).toContain('sucesso');
    });

    it('rota versionada /api/v1/categorias também deve funcionar', async () => {
        const res = await request(app)
            .get('/api/v1/categorias')
            .set('Authorization', `Bearer ${token}`);

        expect(res.statusCode).toBe(200);
        expect(res.body).toHaveProperty('categorias');
    });
});
