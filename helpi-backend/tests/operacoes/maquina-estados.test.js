// =============================================================
// HELPI - Testes da Máquina de Estados dos Chamados
// Pilar 1 > Domínio de Operações
//
// Testa: Transições ilegais de status devem ser bloqueadas.
// O chamado DEVE seguir: procurando → a_caminho → em_servico → finalizado
//
// NOTA: Testes de integração — requerem PostgreSQL com PostGIS ativo
// =============================================================

const request = require('supertest');
const app = require('../../src/app');
const pool = require('../../src/config/database');
const { gerarToken } = require('../../src/utils/jwt');

describe('⚙️ Máquina de Estados — Transições de Status', () => {
    let chamadoId;
    let tokenCliente;
    let tokenProfissional;
    let clienteId;
    let profissionalId;

    beforeAll(async () => {
        // Limpeza
        await pool.query("DELETE FROM avaliacoes WHERE comentario LIKE '[TESTE-FSM]%'");
        await pool.query("DELETE FROM chamados_express WHERE problema_descricao LIKE '[TESTE-FSM]%'");
        await pool.query("DELETE FROM profissionais WHERE email = 'fsm.profissional@helpi.com'");
        await pool.query("DELETE FROM clientes WHERE email = 'fsm.cliente@helpi.com'");

        // Criar Cliente
        const clienteRes = await pool.query(`
            INSERT INTO clientes (nome, cpf, email, senha, telefone) 
            VALUES ('Cliente FSM', '11111111111', 'fsm.cliente@helpi.com', 'senha123', '11999990001') 
            RETURNING id
        `);
        clienteId = clienteRes.rows[0].id;

        // Criar Profissional online com coordenadas (PostGIS)
        const profRes = await pool.query(`
            INSERT INTO profissionais 
            (nome, cpf_cnpj, email, senha, telefone, categoria, status, is_online, latitude_atual, longitude_atual)
            VALUES ('Profissional FSM', '22222222222222', 'fsm.profissional@helpi.com', 'senha123', '11999990002', 'Eletricista', 'aprovado', true, -23.561414, -46.655881)
            RETURNING id
        `);
        profissionalId = profRes.rows[0].id;

        tokenCliente = gerarToken(clienteId, 'cliente');
        tokenProfissional = gerarToken(profissionalId, 'profissional');

        // Criar chamado para testar
        const res = await request(app)
            .post('/api/chamados')
            .set('Authorization', `Bearer ${tokenCliente}`)
            .send({
                categoria_solicitada: 'Elétrica',
                problema_descricao: '[TESTE-FSM] Teste de máquina de estados',
                latitude_destino: -23.557434,
                longitude_destino: -46.662153
            });

        chamadoId = res.body.chamado.id;
    });

    // ─── TRANSIÇÃO ILEGAL: procurando → em_servico (pular aceite) ──
    it('deve PROIBIR ir de "procurando" direto para "em_servico" (chegada sem aceitar)', async () => {
        const res = await request(app)
            .put(`/api/chamados/${chamadoId}/chegada`)
            .set('Authorization', `Bearer ${tokenProfissional}`)
            .send({});

        // Dois cenários possíveis: 403 (não é o profissional do chamado) ou 400 (status inválido)
        expect([400, 403]).toContain(res.statusCode);
    });

    // ─── TRANSIÇÃO ILEGAL: procurando → finalizado (pular tudo) ──
    it('deve PROIBIR ir de "procurando" direto para "finalizado"', async () => {
        const res = await request(app)
            .put(`/api/chamados/${chamadoId}/finalizar`)
            .set('Authorization', `Bearer ${tokenProfissional}`)
            .send({ valor_cobrado: 100 });

        expect([400, 403]).toContain(res.statusCode);
    });

    // ─── TRANSIÇÃO LEGAL: procurando → a_caminho ──
    it('deve PERMITIR aceitar o chamado (procurando → a_caminho)', async () => {
        const res = await request(app)
            .put(`/api/chamados/${chamadoId}/aceitar`)
            .set('Authorization', `Bearer ${tokenProfissional}`)
            .send({});

        expect(res.statusCode).toBe(200);
        expect(res.body.chamado.status).toBe('a_caminho');
    });

    // ─── TRANSIÇÃO ILEGAL: a_caminho → finalizado (pular chegada) ──
    it('deve PROIBIR finalizar sem registar chegada (a_caminho → finalizado)', async () => {
        const res = await request(app)
            .put(`/api/chamados/${chamadoId}/finalizar`)
            .set('Authorization', `Bearer ${tokenProfissional}`)
            .send({ valor_cobrado: 100 });

        expect(res.statusCode).toBe(400);
    });

    // ─── TRANSIÇÃO ILEGAL: aceitar de novo (a_caminho → a_caminho) ──
    it('deve PROIBIR aceitar um chamado que já foi aceite', async () => {
        const res = await request(app)
            .put(`/api/chamados/${chamadoId}/aceitar`)
            .set('Authorization', `Bearer ${tokenProfissional}`)
            .send({});

        expect(res.statusCode).toBe(400);
        expect(res.body.erro).toContain('já aceitou');
    });

    // ─── TRANSIÇÃO LEGAL: a_caminho → em_servico ──
    it('deve PERMITIR registar chegada (a_caminho → em_servico)', async () => {
        const res = await request(app)
            .put(`/api/chamados/${chamadoId}/chegada`)
            .set('Authorization', `Bearer ${tokenProfissional}`)
            .send({});

        expect(res.statusCode).toBe(200);
        expect(res.body.chamado.status).toBe('em_servico');
    });

    // ─── TRANSIÇÃO LEGAL: em_servico → finalizado ──
    it('deve PERMITIR finalizar o serviço (em_servico → finalizado)', async () => {
        const res = await request(app)
            .put(`/api/chamados/${chamadoId}/finalizar`)
            .set('Authorization', `Bearer ${tokenProfissional}`)
            .send({ valor_cobrado: 150 });

        if (res.statusCode !== 200) console.log(res.body);
        expect(res.statusCode).toBe(200);
        expect(res.body.chamado.status).toBe('finalizado');
    });

    // ─── TRANSIÇÃO ILEGAL: finalizado → qualquer coisa ──
    it('deve PROIBIR aceitar um chamado finalizado', async () => {
        const res = await request(app)
            .put(`/api/chamados/${chamadoId}/aceitar`)
            .set('Authorization', `Bearer ${tokenProfissional}`)
            .send({});

        expect(res.statusCode).toBe(400);
    });

    it('deve PROIBIR finalizar um chamado já finalizado', async () => {
        const res = await request(app)
            .put(`/api/chamados/${chamadoId}/finalizar`)
            .set('Authorization', `Bearer ${tokenProfissional}`)
            .send({ valor_cobrado: 150 });

        expect(res.statusCode).toBe(400);
    });

    // Limpeza
    afterAll(async () => {
        await pool.query("DELETE FROM avaliacoes WHERE comentario LIKE '[TESTE-FSM]%'");
        await pool.query("DELETE FROM chamados_express WHERE problema_descricao LIKE '[TESTE-FSM]%'");
        await pool.query("DELETE FROM profissionais WHERE email = 'fsm.profissional@helpi.com'");
        await pool.query("DELETE FROM clientes WHERE email = 'fsm.cliente@helpi.com'");
        // await pool.end(); // Removido para test:all funcionar
    });
});
