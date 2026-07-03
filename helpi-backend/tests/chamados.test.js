const request = require('supertest');
const app = require('../src/app');
const pool = require('../src/config/database');
const { gerarToken } = require('../src/utils/jwt');

describe('Testes do Ciclo de Vida do Motor On-Demand (/api/chamados)', () => {
    let chamadoId;
    let clienteTesteId;
    let profissionalTesteId;
    
    // Variáveis para guardar os "crachás" de acesso
    let tokenCliente;
    let tokenProfissional;

    beforeAll(async () => {
        // 1. Limpeza de segurança
        await pool.query("DELETE FROM avaliacoes WHERE comentario LIKE '[TESTE]%'");
        await pool.query("DELETE FROM chamados_express WHERE problema_descricao LIKE '[TESTE]%'");
        await pool.query("DELETE FROM profissionais WHERE email = 'eletricista.gps@helpi.com'");
        await pool.query("DELETE FROM clientes WHERE email = 'cliente.gps@helpi.com'");

        // 2. Criar Cliente e capturar o ID dele
        const clienteRes = await pool.query(`
            INSERT INTO clientes (nome, cpf, email, senha, telefone) 
            VALUES ('Cliente GPS', '00000000000', 'cliente.gps@helpi.com', 'senha123', '11999999999') 
            RETURNING id
        `);
        clienteTesteId = clienteRes.rows[0].id;

        // 3. Criar Profissional "Online" e capturar o ID dele
        const profRes = await pool.query(`
            INSERT INTO profissionais 
            (nome, cpf_cnpj, email, senha, telefone, categoria, status, is_online, latitude_atual, longitude_atual) 
            VALUES ('Eletricista Paulista', '99999999999999', 'eletricista.gps@helpi.com', 'senha123', '11988887777', 'Eletricista', 'aprovado', true, -23.561414, -46.655881)
            RETURNING id
        `);

        // FIX: Atribuir o ID ANTES de gerar o token (estava invertido — token recebia undefined)
        profissionalTesteId = profRes.rows[0].id;

        tokenCliente = gerarToken(clienteTesteId, 'cliente');
        tokenProfissional = gerarToken(profissionalTesteId, 'profissional');
    });

    // --- PASSO 1: CLIENTE CHAMA ---
    it('1. Deve encontrar o eletricista e criar o chamado', async () => {
        const res = await request(app)
            .post('/api/chamados')
            .set('Authorization', `Bearer ${tokenCliente}`)
            .send({
                cliente_id: clienteTesteId,
                categoria_solicitada: 'Eletricista',
                problema_descricao: '[TESTE] Curto-circuito na sala!',
                latitude_destino: -23.557434, 
                longitude_destino: -46.662153
            });

        expect(res.statusCode).toEqual(201);
        expect(res.body.chamado.status).toBe('procurando_profissional');
        
        // Guardamos o ID do chamado gerado para o eletricista usar nos próximos passos
        chamadoId = res.body.chamado.id;
    });

    // --- PASSO 2: PROFISSIONAL ACEITA ---
    it('2. Profissional deve aceitar o serviço e ficar a caminho', async () => {
        const res = await request(app)
            .put(`/api/chamados/${chamadoId}/aceitar`)
            .set('Authorization', `Bearer ${tokenProfissional}`)
            .send({ profissional_id: profissionalTesteId });

        expect(res.statusCode).toEqual(200);
        expect(res.body.chamado.status).toBe('a_caminho');
    });

    // --- PASSO 3: PROFISSIONAL CHEGA ---
    it('3. Profissional avisa que chegou ao local', async () => {
        const res = await request(app)
            .put(`/api/chamados/${chamadoId}/chegada`)
            .set('Authorization', `Bearer ${tokenProfissional}`)
            .send({ profissional_id: profissionalTesteId });

        expect(res.statusCode).toEqual(200);
        expect(res.body.chamado.status).toBe('em_servico');
    });

    // --- PASSO 4: PROFISSIONAL FINALIZA ---
    it('4. Profissional finaliza o serviço com sucesso', async () => {
        const res = await request(app)
            .put(`/api/chamados/${chamadoId}/finalizar`)
            .set('Authorization', `Bearer ${tokenProfissional}`)
            .send({ profissional_id: profissionalTesteId, valor_cobrado: 100.00 });

        expect(res.statusCode).toEqual(200);
        expect(res.body.chamado.status).toBe('finalizado');
    });

    // --- PASSO 5: CLIENTE AVALIA O SERVIÇO ---
    it('5. Cliente avalia o serviço e a média do profissional é atualizada', async () => {
        const res = await request(app)
            .post('/api/avaliacoes/cliente')
            .set('Authorization', `Bearer ${tokenCliente}`)
            .send({
                chamado_id: chamadoId,
                nota: 5,
                comentario: '[TESTE] Excelente profissional, muito rápido!'
            });

        expect(res.statusCode).toEqual(201);
        expect(res.body.avaliacao.nota).toBe(5);
        expect(res.body).toHaveProperty('nova_media_profissional');
        
        // Garante que o cálculo da média funcionou perfeitamente
        expect(Number(res.body.nova_media_profissional)).toBe(5.0); 
    });

    // --- PASSO 6: TENTA AVALIAR DUAS VEZES (SEGURANÇA) ---
    it('6. Deve bloquear tentativa de avaliar o mesmo serviço duas vezes', async () => {
        const res = await request(app)
            .post('/api/avaliacoes/cliente')
            .set('Authorization', `Bearer ${tokenCliente}`)
            .send({
                chamado_id: chamadoId,
                nota: 3,
                comentario: '[TESTE] Tentar dar uma segunda nota para baixar a média.'
            });

        expect(res.statusCode).toEqual(409); // 409 significa Conflito
        expect(res.body.erro).toContain('Você já avaliou');
    });

    // FIX: afterAll movido para o FINAL do describe (estava antes dos testes 5 e 6)
    afterAll(async () => {
        // await pool.end(); // Removido para test:all funcionar
    });
});


