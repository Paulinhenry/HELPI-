const request = require('supertest');
const app = require('../src/app');
const pool = require('../src/config/database');

describe('Testes de Registo de Profissionais (/api/profissionais)', () => {
    // Usamos dados fixos para o teste, mas garantimos que a base de dados
    // é limpa antes de cada execução.
    const emailTeste = 'carlos.teste.pro@email.com';
    const documentoTeste = '12345678901234';

    beforeAll(async () => {
        // Limpeza de segurança: Apaga o profissional de teste caso ele tenha ficado
        // preso na base de dados numa execução anterior.
        await pool.query('DELETE FROM profissionais WHERE email = $1', [emailTeste]);
    });

    // --- 1. Teste de Caminho Feliz (Sucesso) ---
    it('Deve registar um novo profissional com sucesso', async () => {
        const res = await request(app)
            .post('/api/profissionais')
            .send({
                nome: 'Carlos Eletricista',
                cpf_cnpj: documentoTeste,
                email: emailTeste,
                senha: 'senha_segura_123',
                telefone: '11988887777',
                categoria: 'Eletricista',
                biografia: 'Especialista em instalações residenciais com 10 anos de experiência.'
            });

        expect(res.statusCode).toEqual(201);
        expect(res.body).toHaveProperty('mensagem');
        expect(res.body.profissional).toHaveProperty('id');
        expect(res.body.profissional.nome).toBe('Carlos Eletricista');
        
        // Garante que o profissional entra com o status bloqueado por padrão (Regra de Negócio)
        expect(res.body.profissional.status).toBe('pendente_aprovacao');
    });

    // --- 2. Teste de Conflito (Segurança contra Duplicados) ---
    it('Deve rejeitar o registo se o CPF/CNPJ ou E-mail já estiver em uso', async () => {
        // Tentamos enviar exatamente os mesmos dados da inserção anterior
        const res = await request(app)
            .post('/api/profissionais')
            .send({
                nome: 'Carlos Clone',
                cpf_cnpj: documentoTeste, 
                email: emailTeste, 
                senha: 'outrasenha_123',
                telefone: '11900000000',
                categoria: 'Encanador',
                biografia: 'Tentando roubar a vaga do Carlos.'
            });

        expect(res.statusCode).toEqual(409);
        expect(res.body).toHaveProperty('erro');
        expect(res.body.erro).toContain('cadastrado');
    });

    afterAll(async () => {
        // Encerra a ligação à base de dados para o terminal não ficar bloqueado
        // await pool.end(); // Removido para test:all funcionar
    });
});
