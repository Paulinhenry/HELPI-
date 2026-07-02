const request = require('supertest');
const app = require('../src/app');
const pool = require('../src/config/database');

describe("Testes do CRUD de Clientes (/api/clientes)", () => {
    // Usamos um email único e o CPF válido para passar no validador
    const emailUnico = `fernando.teste.${Date.now()}@email.com`;
    const cpfValidoTeste = "52998224725";

    beforeAll(async () => {
        // Limpa o nosso utilizador de teste da base de dados antes de começar
        // Assim, o CPF estará sempre livre para o teste passar com sucesso
        await pool.query("DELETE FROM clientes WHERE cpf = $1", [cpfValidoTeste]);
    });

    it("Deve registar um novo cliente com sucesso", async () => {
        const res = await request(app)
            .post('/api/clientes')
            .send({
                nome: "Fernando da Silva",
                cpf: cpfValidoTeste, // Usa o CPF que passa na conta matemática
                email: emailUnico,
                senha: "senha_segura_12345",
                telefone: "44991047772"
            });

        expect(res.statusCode).toEqual(201);
        expect(res.body).toHaveProperty('mensagem');
        expect(res.body.cliente).toHaveProperty('id');
        expect(res.body.cliente.nome).toBe("Fernando da Silva");
    });

    afterAll(async () => {
        // await pool.end(); // Removido para test:all funcionar
    });
});
