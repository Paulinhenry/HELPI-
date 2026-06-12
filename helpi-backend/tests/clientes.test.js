const request = require('supertest');
const app = require('../src/app');
const pool = require('../src/config/database');

describe("Testes do CRUD de Clientes (/api/clientes)", () => {
    const emailUnico = `joao.teste.${Date.now()}@email.com`;

    it("Deve registar um novo cliente com sucesso", async () => {
        const res = await request(app)
            .post('/api/clientes')
            .send({
                nome: "João da Silva",
                email: emailUnico,
                senha: "senha_segura_123",
                telefone: "11999998888"
            });
        console.log("🚨 O ERRO DO BANCO FOI:", res.body);

        expect(res.statusCode).toEqual(201);
        expect(res.body).toHaveProperty('mensagem');
        expect(res.body.cliente).toHaveProperty('id');
        expect(res.body.cliente.nome).toBe("João da Silva");
    });

    afterAll(async () => {
        await pool.end();
    });
});