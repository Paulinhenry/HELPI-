// =============================================================
// HELPI - Rotas de Autenticação (Login + Refresh)
// POST /api/login/clientes       → Login de cliente
// POST /api/login/profissionais  → Login de profissional
// POST /api/auth/refresh         → Renovar access token
// =============================================================

const express = require('express');
const rateLimit = require('express-rate-limit');
const router = express.Router();
const authController = require('../controllers/auth.controller');
const { validarLogin } = require('../middlewares/validators/loginValidator');

// Rate limiter para proteção contra brute-force (5 tentativas por 15 minutos)
const loginLimiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutos
    max: process.env.NODE_ENV === 'test' ? 1000 : 5,
    standardHeaders: true,
    legacyHeaders: false,
    message: {
        erro: 'Muitas tentativas de login. Tente novamente em 15 minutos.'
    },
});

// Rate limiter para refresh (mais permissivo — 30 req/min)
const refreshLimiter = rateLimit({
    windowMs: 1 * 60 * 1000,
    max: 30,
    standardHeaders: true,
    legacyHeaders: false,
    message: {
        erro: 'Muitas tentativas de refresh. Tente novamente em 1 minuto.'
    },
});

/**
 * @openapi
 * /api/login/clientes:
 *   post:
 *     summary: Login de cliente
 *     tags: [Autenticação]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - email
 *               - senha
 *             properties:
 *               email:
 *                 type: string
 *                 format: email
 *                 example: "joao@email.com"
 *               senha:
 *                 type: string
 *                 format: password
 *                 example: "minhasenha123"
 *     responses:
 *       '200':
 *         description: Login bem-sucedido — retorna access_token e refresh_token
 *       '400':
 *         description: Campos de login inválidos
 *       '401':
 *         description: Email ou senha incorretos
 *       '429':
 *         description: Muitas tentativas — rate limit atingido
 *
 * /api/login/profissionais:
 *   post:
 *     summary: Login de profissional
 *     tags: [Autenticação]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - email
 *               - senha
 *             properties:
 *               email:
 *                 type: string
 *                 format: email
 *                 example: "carlos@email.com"
 *               senha:
 *                 type: string
 *                 format: password
 *                 example: "minhasenha123"
 *     responses:
 *       '200':
 *         description: Login bem-sucedido — retorna access_token e refresh_token
 *       '400':
 *         description: Campos de login inválidos
 *       '401':
 *         description: Email ou senha incorretos
 *       '403':
 *         description: Conta não aprovada
 *       '429':
 *         description: Muitas tentativas — rate limit atingido
 *
 * /api/auth/refresh:
 *   post:
 *     summary: Renovar access token
 *     tags: [Autenticação]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - refresh_token
 *             properties:
 *               refresh_token:
 *                 type: string
 *                 description: O refresh token obtido no login
 *     responses:
 *       '200':
 *         description: Novo access_token gerado
 *       '400':
 *         description: Refresh token não fornecido
 *       '401':
 *         description: Refresh token inválido ou expirado
 */

router.post('/login/clientes', loginLimiter, validarLogin, authController.loginCliente);
router.post('/login/profissionais', loginLimiter, validarLogin, authController.loginProfissional);
router.post('/auth/refresh', refreshLimiter, authController.refreshToken);

module.exports = router;