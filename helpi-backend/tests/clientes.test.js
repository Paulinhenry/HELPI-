const request = require('supertest');
const app = require('../src/app');
const pool = require('../src/config/database');

describe("Testes do CRUD de Clientes (/api/clientes)", () => {
    const emailUnico = `fernado.teste.${Date.now()}@email.com`;

    it("Deve registar um novo cliente com sucesso", async () => {
        const res = await request(app)
            .post('/api/clientes')
            .send({
                nome: "Fernado da Silva",
                cpf: "12345678900",
                email: emailUnico,
                senha: "senha_segura_12345",
                telefone: "44991047772"
            });
        console.log("🚨 O ERRO DO BANCO FOI:", res.body);

        expect(res.statusCode).toEqual(201);
        expect(res.body).toHaveProperty('mensagem');
        expect(res.body.cliente).toHaveProperty('id');
        expect(res.body.cliente.nome).toBe("Fernado da Silva");
    });

    afterAll(async () => {
        await pool.end();
    });
});