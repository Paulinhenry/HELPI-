// =============================================================
// HELPI - Testes de RBAC (Role-Based Access Control)
// Pilar 1 > Domínio de Autenticação e Autorização
//
// Testa: Token de Cliente em rotas de Profissional (e vice-versa),
//        Sem token, Token de tipo desconhecido
// =============================================================

const request = require('supertest');
const app = require('../../src/app');
const { gerarTokenCliente, gerarTokenProfissional } = require('../setup');

describe('🔐 RBAC - Controlo de Acesso por Papel', () => {

    // ─── TESTE DE FRONTEIRA: Cliente → Rota de Profissional ─
    describe('Cliente tenta aceder a rotas de Profissional', () => {
        
        it('deve rejeitar cliente a tentar aceitar chamado (403)', async () => {
            const tokenCliente = gerarTokenCliente();
            
            const res = await request(app)
                .put('/api/chamados/fake-uuid-123/aceitar')
                .set('Authorization', `Bearer ${tokenCliente}`)
                .send({});

            expect(res.statusCode).toBe(403);
            expect(res.body.erro).toContain('profissionais');
        });

        it('deve rejeitar cliente a tentar registar chegada (403)', async () => {
            const tokenCliente = gerarTokenCliente();
            
            const res = await request(app)
                .put('/api/chamados/fake-uuid-123/chegada')
                .set('Authorization', `Bearer ${tokenCliente}`)
                .send({});

            expect(res.statusCode).toBe(403);
        });

        it('deve rejeitar cliente a tentar finalizar chamado (403)', async () => {
            const tokenCliente = gerarTokenCliente();
            
            const res = await request(app)
                .put('/api/chamados/fake-uuid-123/finalizar')
                .set('Authorization', `Bearer ${tokenCliente}`)
                .send({});

            expect(res.statusCode).toBe(403);
        });
    });

    // ─── TESTE DE FRONTEIRA: Profissional → Rota de Cliente ─
    describe('Profissional tenta aceder a rotas de Cliente', () => {
        
        it('deve rejeitar profissional a tentar criar chamado (403)', async () => {
            const tokenPro = gerarTokenProfissional();
            
            const res = await request(app)
                .post('/api/chamados')
                .set('Authorization', `Bearer ${tokenPro}`)
                .send({
                    categoria_solicitada: 'Elétrica',
                    problema_descricao: 'Teste RBAC',
                    latitude_destino: -23.55,
                    longitude_destino: -46.66
                });

            expect(res.statusCode).toBe(403);
            expect(res.body.erro).toContain('clientes');
        });

        it('deve rejeitar profissional a tentar processar pagamento (403)', async () => {
            const tokenPro = gerarTokenProfissional();
            
            const res = await request(app)
                .post('/api/pagamentos/processar')
                .set('Authorization', `Bearer ${tokenPro}`)
                .send({});

            expect(res.statusCode).toBe(403);
        });

        it('deve rejeitar profissional a tentar estimar preço (403)', async () => {
            const tokenPro = gerarTokenProfissional();
            
            const res = await request(app)
                .post('/api/pagamentos/estimar')
                .set('Authorization', `Bearer ${tokenPro}`)
                .send({ categoria: 'Elétrica' });

            expect(res.statusCode).toBe(403);
        });
    });

    // ─── TESTE SEM TOKEN ────────────────────────────────────
    describe('Sem Token (Anónimo)', () => {
        
        it('deve rejeitar pedido sem token para rota de cliente (401)', async () => {
            const res = await request(app)
                .post('/api/chamados')
                .send({});

            expect(res.statusCode).toBe(401);
            expect(res.body.erro).toContain('Token');
        });

        it('deve rejeitar pedido sem token para rota de profissional (401)', async () => {
            const res = await request(app)
                .put('/api/chamados/fake-uuid/aceitar')
                .send({});

            expect(res.statusCode).toBe(401);
        });

        it('deve rejeitar pedido com Authorization header mal-formado (401)', async () => {
            const res = await request(app)
                .post('/api/chamados')
                .set('Authorization', 'TokenSemBearer abc123')
                .send({});

            expect(res.statusCode).toBe(401);
        });
    });
});
