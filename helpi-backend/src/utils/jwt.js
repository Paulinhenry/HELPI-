// =============================================================
// HELPI - Utilitário JWT (Access + Refresh Token)
//
// ESCALABILIDADE:
// - Access Token curto (15min) — limita janela de ataque
// - Refresh Token longo (30d) — UX sem re-login constante
// - Funções separadas para gerar e verificar cada tipo
// =============================================================

const jwt = require('jsonwebtoken');

const ACCESS_TOKEN_EXPIRY = '15m';   // 15 minutos
const REFRESH_TOKEN_EXPIRY = '30d';  // 30 dias

/**
 * Gera um Access Token (curta duração, usado em todas as requests)
 */
const gerarAccessToken = (usuarioId, tipo) => {
    return jwt.sign(
        { id: usuarioId, tipo, tokenType: 'access' },
        process.env.JWT_SECRET,
        { expiresIn: ACCESS_TOKEN_EXPIRY }
    );
};

/**
 * Gera um Refresh Token (longa duração, usado apenas para renovar o access)
 */
const gerarRefreshToken = (usuarioId, tipo) => {
    const secret = process.env.JWT_REFRESH_SECRET || process.env.JWT_SECRET + '_refresh';
    return jwt.sign(
        { id: usuarioId, tipo, tokenType: 'refresh' },
        secret,
        { expiresIn: REFRESH_TOKEN_EXPIRY }
    );
};

/**
 * Verifica e decodifica um Refresh Token
 */
const verificarRefreshToken = (token) => {
    const secret = process.env.JWT_REFRESH_SECRET || process.env.JWT_SECRET + '_refresh';
    return jwt.verify(token, secret);
};

/**
 * Gera o par completo (access + refresh) — usado no login
 */
const gerarTokens = (usuarioId, tipo) => {
    return {
        accessToken: gerarAccessToken(usuarioId, tipo),
        refreshToken: gerarRefreshToken(usuarioId, tipo),
    };
};

// Retrocompatibilidade: mantém a função antiga funcionando
const gerarToken = (usuarioId, tipo) => gerarAccessToken(usuarioId, tipo);

module.exports = {
    gerarAccessToken,
    gerarRefreshToken,
    verificarRefreshToken,
    gerarTokens,
    gerarToken, // Retrocompatibilidade
};