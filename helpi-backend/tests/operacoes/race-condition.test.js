// =============================================================
// HELPI - Teste de Race Condition (O TESTE DE OURO)
// Pilar 1 > Domínio de Operações
//
// Simula 5 profissionais a disparar "ACEITAR" no mesmo
// milissegundo. O SELECT FOR UPDATE deve garantir que apenas
// 1 recebe o serviço e os outros 4 recebem erro.
//
// NOTA: Teste de integração — requer PostgreSQL com PostGIS ativo
// =============================================================

const request = require('supertest');
const app = require('../../src/app');
const pool = require('../../src/config/database');
const { gerarToken } = require('../../src/utils/jwt');

describe('🏆 Race Condition — O Teste de Ouro', () => {
    let chamadoId;
    let tokenCliente;
    const NUM_PROFISSIONAIS = 5;
    const profissionais = [];

    beforeAll(async () => {
        // Limpeza total
        await pool.query("DELETE FROM avaliacoes WHERE comentario LIKE '[TESTE-RACE]%'");
        await pool.query("DELETE FROM chamados_express WHERE problema_descricao LIKE '[TESTE-RACE]%'");
        
        for (let i = 1; i <= NUM_PROFISSIONAIS; i++) {
            await pool.query(`DELETE FROM profissionais WHERE email = 'race.pro${i}@helpi.com'`);
        }
        await pool.query("DELETE FROM clientes WHERE email = 'race.cliente@helpi.com'");

        // Criar Cliente
        const clienteRes = await pool.query(`
            INSERT INTO clientes (nome, cpf, email, senha, telefone) 
            VALUES ('Cliente Race', '33333333333', 'race.cliente@helpi.com', 'senha123', '11999880001') 
            RETURNING id
        `);
        const clienteId = clienteRes.rows[0].id;
        tokenCliente = gerarToken(clienteId, 'cliente');

        // Criar 5 Profissionais online no raio de 10km
        for (let i = 1; i <= NUM_PROFISSIONAIS; i++) {
            const profRes = await pool.query(`
                INSERT INTO profissionais 
                (nome, cpf_cnpj, email, senha, telefone, categoria, status, is_online, latitude_atual, longitude_atual)
                VALUES (
                    'Profissional Race ${i}', 
                    '${String(44444444444444 + i)}', 
                    'race.pro${i}@helpi.com', 
                    'senha123', 
                    '1199988000${i}', 
                    'Eletricista', 
                    'aprovado', 
                    true, 
                    ${-23.561414 + (i * 0.001)}, 
                    -46.655881
                )
                RETURNING id
            `);
            
            profissionais.push({
                id: profRes.rows[0].id,
                token: gerarToken(profRes.rows[0].id, 'profissional')
            });
        }

        // Criar o chamado que será disputado
        const chamadoRes = await request(app)
            .post('/api/chamados')
            .set('Authorization', `Bearer ${tokenCliente}`)
            .send({
                categoria_solicitada: 'Elétrica',
                problema_descricao: '[TESTE-RACE] Corrida de profissionais',
                latitude_destino: -23.557434,
                longitude_destino: -46.662153
            });

        chamadoId = chamadoRes.body.chamado.id;
        expect(chamadoId).toBeDefined();
    }, 30000); // Timeout de 30s para o setup

    // ─── O TESTE DE OURO ────────────────────────────────────
    it('deve entregar o serviço a EXATAMENTE 1 profissional quando 5 aceitam ao mesmo tempo', async () => {
        // Dispara as 5 requests SIMULTANEAMENTE
        const promessas = profissionais.map(prof => {
            return request(app)
                .put(`/api/chamados/${chamadoId}/aceitar`)
                .set('Authorization', `Bearer ${prof.token}`)
                .send({});
        });

        // Espera todas terminarem
        const resultados = await Promise.all(promessas);

        // Analisa os resultados
        const aceites = resultados.filter(r => r.statusCode === 200);
        const rejeitados = resultados.filter(r => r.statusCode === 400);

        // REGRA DE OURO: Exatamente 1 aceite, exatamente 4 rejeitados
        expect(aceites).toHaveLength(1);
        expect(rejeitados).toHaveLength(NUM_PROFISSIONAIS - 1);

        // O aceite deve ter o status correto
        expect(aceites[0].body.chamado.status).toBe('a_caminho');

        // Os rejeitados devem ter mensagem clara
        rejeitados.forEach(r => {
            expect(r.body.erro).toContain('já aceitou');
        });
    }, 30000);

    // ─── VERIFICAÇÃO PÓS-CORRIDA ────────────────────────────
    it('deve ter gravado apenas 1 profissional no chamado após a corrida', async () => {
        const resultado = await pool.query(
            'SELECT profissional_id, status FROM chamados_express WHERE id = $1',
            [chamadoId]
        );

        expect(resultado.rows).toHaveLength(1);
        expect(resultado.rows[0].status).toBe('a_caminho');
        expect(resultado.rows[0].profissional_id).toBeDefined();
        
        // Confirma que é um dos 5 profissionais que criámos
        const profIds = profissionais.map(p => p.id);
        expect(profIds).toContain(resultado.rows[0].profissional_id);
    });

    // Limpeza
    afterAll(async () => {
        await pool.query("DELETE FROM avaliacoes WHERE comentario LIKE '[TESTE-RACE]%'");
        await pool.query("DELETE FROM chamados_express WHERE problema_descricao LIKE '[TESTE-RACE]%'");
        
        for (let i = 1; i <= NUM_PROFISSIONAIS; i++) {
            await pool.query(`DELETE FROM profissionais WHERE email = 'race.pro${i}@helpi.com'`);
        }
        await pool.query("DELETE FROM clientes WHERE email = 'race.cliente@helpi.com'");
        // await pool.end(); // Removido para test:all funcionar
    });
});
