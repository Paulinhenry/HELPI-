const request = require('supertest');
const app = require('../src/app');
const pool = require('../src/config/database');

describe('Testes do Motor On-Demand (/api/chamados)', () => {
    let clienteTesteId;

    beforeAll(async () => {
        // 1. Limpeza de segurança
        await pool.query("DELETE FROM chamados_express WHERE problema_descricao LIKE '[TESTE]%'");
        await pool.query("DELETE FROM profissionais WHERE email = 'eletricista.gps@helpi.com'");
        await pool.query("DELETE FROM clientes WHERE email = 'cliente.gps@helpi.com'");

        // 2. Criar um Cliente de Teste
        const clienteRes = await pool.query(`
            INSERT INTO clientes (nome, cpf, email, senha, telefone) 
            VALUES ('Cliente GPS', '00000000000', 'cliente.gps@helpi.com', 'senha123', '11999999999') 
            RETURNING id
        `);
        clienteTesteId = clienteRes.rows[0].id;

        // 3. Criar um Profissional "Online" na Avenida Paulista, SP (Lat: -23.561414, Lng: -46.655881)
        await pool.query(`
            INSERT INTO profissionais 
            (nome, cpf_cnpj, email, senha, telefone, categoria, status, is_online, latitude_atual, longitude_atual) 
            VALUES ('Eletricista Paulista', '99999999999999', 'eletricista.gps@helpi.com', 'senha123', '11988887777', 'Eletricista', 'aprovado', true, -23.561414, -46.655881)
        `);
    });

    // --- 1. Teste de Sucesso (Cliente a menos de 10km) ---
    it('Deve encontrar um eletricista próximo e criar o chamado', async () => {
        const res = await request(app)
            .post('/api/chamados')
            .send({
                cliente_id: clienteTesteId,
                categoria_solicitada: 'Eletricista',
                problema_descricao: '[TESTE] Curto-circuito na sala!',
                // Cliente na Rua Augusta, SP (Muito perto da Avenida Paulista)
                latitude_destino: -23.557434, 
                longitude_destino: -46.662153
            });

        expect(res.statusCode).toEqual(201);
        expect(res.body).toHaveProperty('mensagem');
        expect(res.body.profissionais_notificados).toBeGreaterThan(0); // Garante que encontrou pelo menos o nosso profissional de teste
        expect(res.body.chamado.status).toBe('procurando_profissional');
    });

    // --- 2. Teste de Falha (Cliente a mais de 10km) ---
    it('Deve devolver erro 404 se não houver profissionais num raio de 10km', async () => {
        const res = await request(app)
            .post('/api/chamados')
            .send({
                cliente_id: clienteTesteId,
                categoria_solicitada: 'Eletricista',
                problema_descricao: '[TESTE] Preciso de ajuda no RJ!',
                // Cliente no Rio de Janeiro (A mais de 300km do Eletricista da Paulista)
                latitude_destino: -22.906846, 
                longitude_destino: -43.172896
            });

        expect(res.statusCode).toEqual(404);
        expect(res.body).toHaveProperty('erro');
        expect(res.body.erro).toContain('Não há nenhum Eletricista disponível num raio de 10km');
    });

    // --- 3. Teste de Falha (Ninguém da Categoria) ---
    it('Deve devolver erro 404 se pedir uma categoria que não está online', async () => {
        const res = await request(app)
            .post('/api/chamados')
            .send({
                cliente_id: clienteTesteId,
                categoria_solicitada: 'Pintor', // O nosso profissional de teste é Eletricista
                problema_descricao: '[TESTE] Pintar a parede da sala',
                // Cliente na Rua Augusta (Perto, mas não tem pintores online)
                latitude_destino: -23.557434, 
                longitude_destino: -46.662153
            });

        expect(res.statusCode).toEqual(404);
    });

    afterAll(async () => {
        await pool.end();
    });
});