const request = require('supertest');
const app = require('../src/app');

describe("Testes Básicos da API", () => {
    it("Deve retornar status 200 na rota /api/status", async () => {
        const res = await request(app).get('/api/status');
        expect(res.statusCode).toEqual(200);
        expect(res.body).toHaveProperty('status', 'online');
        expect(res.body).toHaveProperty('mensagem');
        expect(res.body).toHaveProperty('timestamp');
    });
});