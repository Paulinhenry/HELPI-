const request = require('supertest');
const app = require('../src/app');
const pool = require('../src/config/database');

describe('Testes do CRUD de Clientes (/api/clientes)', () => {
    const emailUnico = `joao.teste.${Date.now()}@email.com`;

    // --- Testes de SUCESSO ---

    it('Deve registar um novo cliente com sucesso', async () => {
        const res = await request(app)
            .post('/api/clientes')
            .send({
                nome: 'João da Silva',
                cpf: '529.982.247-25', // CPF válido (com máscara)
                email: emailUnico,
                senha: 'senha_segura_123',
                telefone: '(11) 99999-8888',
            });

        expect(res.statusCode).toEqual(201);
        expect(res.body).toHaveProperty('mensagem');
        expect(res.body.cliente).toHaveProperty('id');
        expect(res.body.cliente.nome).toBe('João da Silva');
        // Confirma que o CPF foi salvo sem máscara
        expect(res.body.cliente.cpf).toBe('52998224725');
        // Confirma que o e-mail foi normalizado para minúsculas
        expect(res.body.cliente.email).toBe(emailUnico.toLowerCase());
    });

    // --- Testes de VALIDAÇÃO ---

    it('Deve rejeitar cadastro sem campos obrigatórios', async () => {
        const res = await request(app)
            .post('/api/clientes')
            .send({}); // Corpo vazio

        expect(res.statusCode).toEqual(400);
        expect(res.body).toHaveProperty('erro');
    });

    it('Deve rejeitar CPF inválido', async () => {
        const res = await request(app)
            .post('/api/clientes')
            .send({
                nome: 'Teste Silva',
                cpf: '111.111.111-11', // CPF com todos os dígitos iguais
                email: 'teste@email.com',
                senha: 'senha123',
                telefone: '11999999999',
            });

        expect(res.statusCode).toEqual(400);
        expect(res.body.erro).toContain('CPF inválido');
    });

    it('Deve rejeitar e-mail inválido', async () => {
        const res = await request(app)
            .post('/api/clientes')
            .send({
                nome: 'Teste Silva',
                cpf: '529.982.247-25',
                email: 'nao-e-um-email',
                senha: 'senha123',
                telefone: '11999999999',
            });

        expect(res.statusCode).toEqual(400);
        expect(res.body.erro).toContain('E-mail inválido');
    });

    it('Deve rejeitar senha fraca (sem número)', async () => {
        const res = await request(app)
            .post('/api/clientes')
            .send({
                nome: 'Teste Silva',
                cpf: '529.982.247-25',
                email: 'teste@email.com',
                senha: 'senhasemnum',
                telefone: '11999999999',
            });

        expect(res.statusCode).toEqual(400);
        expect(res.body.erro).toContain('Senha deve ter');
    });

    it('Deve rejeitar senha fraca (menos de 8 caracteres)', async () => {
        const res = await request(app)
            .post('/api/clientes')
            .send({
                nome: 'Teste Silva',
                cpf: '529.982.247-25',
                email: 'teste@email.com',
                senha: 'ab1',
                telefone: '11999999999',
            });

        expect(res.statusCode).toEqual(400);
        expect(res.body.erro).toContain('Senha deve ter');
    });

    // --- Testes de CONFLITO (duplicação no banco) ---

    it('Deve rejeitar e-mail ou CPF já cadastrado', async () => {
        // Tenta cadastrar com o mesmo e-mail do primeiro teste
        const res = await request(app)
            .post('/api/clientes')
            .send({
                nome: 'Outro Nome',
                cpf: '529.982.247-25',
                email: emailUnico, // Mesmo e-mail
                senha: 'senha123abc',
                telefone: '11988887777',
            });

        expect(res.statusCode).toEqual(409);
        expect(res.body.erro).toContain('já está cadastrado');
    });

    afterAll(async () => {
        await pool.end();
    });
});
