// =============================================================
// HELPI - Testes de Token Expirado e Corrompido
// Pilar 1 > Domínio de Autenticação e Autorização
//
// Testa: Token expirado → 401, Token corrompido → 401,
//        Refresh token flow, Servidor NÃO crasha
// =============================================================

const request = require('supertest');
const jwt = require('jsonwebtoken');
const app = require('../../src/app');
const { gerarTokenExpirado } = require('../setup');

describe('🕐 Token Expirado e Corrompido', () => {

    // ─── TESTE DO TOKEN EXPIRADO ────────────────────────────
    describe('Token Expirado', () => {
        
        it('deve rejeitar token expirado com 401 e mensagem clara', async () => {
            // Gera token que expira em 0 segundos
            const tokenExpirado = gerarTokenExpirado('cliente');
            
            // Pequeno delay para garantir que o token expirou
            await new Promise(resolve => setTimeout(resolve, 100));
            
            const res = await request(app)
                .post('/api/chamados')
                .set('Authorization', `Bearer ${tokenExpirado}`)
                .send({
                    categoria_solicitada: 'Elétrica',
                    problema_descricao: 'Teste token expirado',
                    latitude_destino: -23.55,
                    longitude_destino: -46.66
                });

            expect(res.statusCode).toBe(401);
            expect(res.body.erro).toContain('expirado');
        });

        it('deve rejeitar token expirado de profissional com 401', async () => {
            const tokenExpirado = gerarTokenExpirado('profissional');
            
            await new Promise(resolve => setTimeout(resolve, 100));
            
            const res = await request(app)
                .put('/api/chamados/fake-uuid/aceitar')
                .set('Authorization', `Bearer ${tokenExpirado}`)
                .send({});

            expect(res.statusCode).toBe(401);
            expect(res.body.erro).toContain('expirado');
        });

        it('NÃO deve crashar o servidor ao receber token expirado', async () => {
            const tokenExpirado = gerarTokenExpirado('cliente');
            
            await new Promise(resolve => setTimeout(resolve, 100));
            
            // Primeira request com token expirado
            await request(app)
                .post('/api/chamados')
                .set('Authorization', `Bearer ${tokenExpirado}`)
                .send({});

            // Segunda request para provar que o servidor continua funcional
            const res = await request(app)
                .get('/api/v1/status');

            // Aceita 200 (se tiver DB configurado) ou 503 (se não tiver DB configurado, como no GitHub Actions)
            expect([200, 503]).toContain(res.statusCode);
        });
    });

    // ─── TESTE DO TOKEN CORROMPIDO ──────────────────────────
    describe('Token Corrompido / Lixo', () => {
        
        it('deve rejeitar string aleatória como token (401)', async () => {
            const res = await request(app)
                .post('/api/chamados')
                .set('Authorization', 'Bearer abc123lixo-token-falso')
                .send({});

            expect(res.statusCode).toBe(401);
            expect(res.body.erro).toContain('inválido');
        });

        it('deve rejeitar token assinado com secret errado (401)', async () => {
            const tokenFalso = jwt.sign(
                { id: 'hacker-uuid', tipo: 'cliente' },
                'secret-errado-do-hacker',
                { expiresIn: '1h' }
            );

            const res = await request(app)
                .post('/api/chamados')
                .set('Authorization', `Bearer ${tokenFalso}`)
                .send({});

            expect(res.statusCode).toBe(401);
        });

        it('deve rejeitar token vazio (401)', async () => {
            const res = await request(app)
                .post('/api/chamados')
                .set('Authorization', 'Bearer ')
                .send({});

            expect(res.statusCode).toBe(401);
        });

        it('NÃO deve crashar com payloads enormes no header Authorization', async () => {
            const tokenGigante = 'Bearer ' + 'A'.repeat(10000);
            
            const res = await request(app)
                .post('/api/chamados')
                .set('Authorization', tokenGigante)
                .send({});

            expect(res.statusCode).toBe(401);
        });
    });

    // ─── TESTE DO REFRESH TOKEN ─────────────────────────────
    describe('Refresh Token', () => {
        
        it('deve rejeitar refresh sem body (400)', async () => {
            const res = await request(app)
                .post('/api/auth/refresh')
                .send({});

            expect(res.statusCode).toBe(400);
            expect(res.body.erro).toContain('obrigatório');
        });

        it('deve rejeitar refresh token inválido (401)', async () => {
            const res = await request(app)
                .post('/api/auth/refresh')
                .send({ refresh_token: 'token-falso-abc123' });

            expect(res.statusCode).toBe(401);
        });
    });
});
