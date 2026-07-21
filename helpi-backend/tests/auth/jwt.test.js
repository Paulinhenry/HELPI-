// =============================================================
// HELPI - Testes Unitários do Utilitário JWT
// Pilar 1 > Domínio de Autenticação > Utils
//
// Testa: gerarAccessToken, gerarRefreshToken,
//        verificarRefreshToken, gerarTokens, gerarToken (retrocompat)
// =============================================================

require('../setup');
const { gerarAccessToken, gerarRefreshToken, verificarRefreshToken, gerarTokens, gerarToken } = require('../../src/utils/jwt');
const jwt = require('jsonwebtoken');

describe('🔧 JWT Utils — Geração e Verificação de Tokens', () => {

    const USUARIO_ID = 'test-uuid-jwt-001';
    const TIPO_CLIENTE = 'cliente';
    const TIPO_PROFISSIONAL = 'profissional';

    // ─── gerarAccessToken ─────────────────────────────────────
    describe('gerarAccessToken', () => {
        it('deve retornar um token JWT válido', () => {
            const token = gerarAccessToken(USUARIO_ID, TIPO_CLIENTE);
            expect(typeof token).toBe('string');
            expect(token.split('.')).toHaveLength(3); // JWT tem 3 partes
        });

        it('deve conter o payload correto (id, tipo, tokenType)', () => {
            const token = gerarAccessToken(USUARIO_ID, TIPO_CLIENTE);
            const decoded = jwt.verify(token, process.env.JWT_SECRET);

            expect(decoded.id).toBe(USUARIO_ID);
            expect(decoded.tipo).toBe(TIPO_CLIENTE);
            expect(decoded.tokenType).toBe('access');
        });

        it('deve ter expiração definida (exp)', () => {
            const token = gerarAccessToken(USUARIO_ID, TIPO_CLIENTE);
            const decoded = jwt.verify(token, process.env.JWT_SECRET);

            expect(decoded).toHaveProperty('exp');
            expect(decoded.exp).toBeGreaterThan(Math.floor(Date.now() / 1000));
        });
    });

    // ─── gerarRefreshToken ────────────────────────────────────
    describe('gerarRefreshToken', () => {
        it('deve retornar um token JWT válido', () => {
            const token = gerarRefreshToken(USUARIO_ID, TIPO_PROFISSIONAL);
            expect(typeof token).toBe('string');
            expect(token.split('.')).toHaveLength(3);
        });

        it('deve ter tokenType = refresh no payload', () => {
            const token = gerarRefreshToken(USUARIO_ID, TIPO_PROFISSIONAL);
            const decoded = verificarRefreshToken(token);

            expect(decoded.tokenType).toBe('refresh');
            expect(decoded.tipo).toBe(TIPO_PROFISSIONAL);
        });

        it('deve usar secret diferente do access token', () => {
            const refreshToken = gerarRefreshToken(USUARIO_ID, TIPO_CLIENTE);

            // Tentar verificar com o secret do access deve falhar
            expect(() => {
                jwt.verify(refreshToken, process.env.JWT_SECRET);
            }).toThrow();
        });
    });

    // ─── verificarRefreshToken ────────────────────────────────
    describe('verificarRefreshToken', () => {
        it('deve decodificar refresh token válido', () => {
            const token = gerarRefreshToken(USUARIO_ID, TIPO_CLIENTE);
            const decoded = verificarRefreshToken(token);

            expect(decoded.id).toBe(USUARIO_ID);
            expect(decoded.tipo).toBe(TIPO_CLIENTE);
        });

        it('deve rejeitar access token (secret diferente)', () => {
            const accessToken = gerarAccessToken(USUARIO_ID, TIPO_CLIENTE);

            expect(() => {
                verificarRefreshToken(accessToken);
            }).toThrow();
        });

        it('deve rejeitar token completamente inválido', () => {
            expect(() => {
                verificarRefreshToken('token.invalido.aqui');
            }).toThrow();
        });
    });

    // ─── gerarTokens ─────────────────────────────────────────
    describe('gerarTokens', () => {
        it('deve retornar objeto com accessToken e refreshToken', () => {
            const tokens = gerarTokens(USUARIO_ID, TIPO_CLIENTE);

            expect(tokens).toHaveProperty('accessToken');
            expect(tokens).toHaveProperty('refreshToken');
            expect(typeof tokens.accessToken).toBe('string');
            expect(typeof tokens.refreshToken).toBe('string');
        });

        it('accessToken deve ter tokenType=access e refreshToken deve ter tokenType=refresh', () => {
            const tokens = gerarTokens(USUARIO_ID, TIPO_PROFISSIONAL);

            const decodedAccess = jwt.verify(tokens.accessToken, process.env.JWT_SECRET);
            const decodedRefresh = verificarRefreshToken(tokens.refreshToken);

            expect(decodedAccess.tokenType).toBe('access');
            expect(decodedRefresh.tokenType).toBe('refresh');
        });
    });

    // ─── gerarToken (retrocompat) ────────────────────────────
    describe('gerarToken (retrocompatibilidade)', () => {
        it('deve funcionar igual a gerarAccessToken', () => {
            const token = gerarToken(USUARIO_ID, TIPO_CLIENTE);
            const decoded = jwt.verify(token, process.env.JWT_SECRET);

            expect(decoded.id).toBe(USUARIO_ID);
            expect(decoded.tipo).toBe(TIPO_CLIENTE);
            expect(decoded.tokenType).toBe('access');
        });
    });
});
