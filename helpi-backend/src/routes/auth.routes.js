// =============================================================
// HELPI - Rotas de Autenticação (Login)
// POST /api/login/clientes     → Login de cliente
// POST /api/login/profissionais → Login de profissional
// =============================================================

const express = require('express');
const rateLimit = require('express-rate-limit');
const router = express.Router();
const authController = require('../controllers/auth.controller');
const { validarLogin } = require('../middlewares/validators/loginValidator');

// Rate limiter para proteção contra brute-force (5 tentativas por 15 minutos)
const loginLimiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutos
    max: 5,
    standardHeaders: true,
    legacyHeaders: false,
    message: {
        erro: 'Muitas tentativas de login. Tente novamente em 15 minutos.'
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
 *         description: Login bem-sucedido — retorna token JWT
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
 *         description: Login bem-sucedido — retorna token JWT
 *       '400':
 *         description: Campos de login inválidos
 *       '401':
 *         description: Email ou senha incorretos
 *       '429':
 *         description: Muitas tentativas — rate limit atingido
 */

router.post('/login/clientes', loginLimiter, validarLogin, authController.loginCliente);
router.post('/login/profissionais', loginLimiter, validarLogin, authController.loginProfissional);

module.exports = router;