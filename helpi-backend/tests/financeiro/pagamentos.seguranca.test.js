// =============================================================
// HELPI - Testes de Segurança de Pagamentos
// Pilar 1 > Domínio Financeiro
//
// Testa: Rota de pagamento sem JWT (Impostor),
//        Token de profissional em rota de cliente (RBAC cruzado)
// =============================================================

const request = require('supertest');
const app = require('../../src/app');
const { gerarTokenProfissional } = require('../setup');

describe('💰 Segurança de Pagamentos', () => {

    // ─── TESTE DO IMPOSTOR (SEM TOKEN) ──────────────────────
    describe('Teste do Impostor — Processar Pagamento', () => {
        
        it('deve recusar checkout sem JWT (401)', async () => {
            const res = await request(app)
                .post('/api/pagamentos/processar')
                .send({
                    chamado_id: 'fake-uuid',
                    transaction_amount: 100
                });

            expect(res.statusCode).toBe(401);
            expect(res.body.erro).toBeDefined();
        });

        it('deve recusar checkout com token de Profissional (403)', async () => {
            const tokenPro = gerarTokenProfissional();
            
            const res = await request(app)
                .post('/api/pagamentos/processar')
                .set('Authorization', `Bearer ${tokenPro}`)
                .send({
                    chamado_id: 'fake-uuid',
                    transaction_amount: 100
                });

            expect(res.statusCode).toBe(403);
            expect(res.body.erro).toContain('clientes');
        });
    });

    // ─── TESTE DO IMPOSTOR (ESTIMATIVA) ─────────────────────
    describe('Teste do Impostor — Estimar Preço', () => {
        
        it('deve recusar estimativa sem JWT (401)', async () => {
            const res = await request(app)
                .post('/api/pagamentos/estimar')
                .send({ categoria: 'Elétrica', descricao: 'tomada' });

            expect(res.statusCode).toBe(401);
        });

        it('deve recusar estimativa com token de Profissional (403)', async () => {
            const tokenPro = gerarTokenProfissional();
            
            const res = await request(app)
                .post('/api/pagamentos/estimar')
                .set('Authorization', `Bearer ${tokenPro}`)
                .send({ categoria: 'Elétrica', descricao: 'tomada' });

            expect(res.statusCode).toBe(403);
        });
    });
});
