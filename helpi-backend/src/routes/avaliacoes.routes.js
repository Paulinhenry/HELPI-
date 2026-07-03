// =============================================================
// HELPI - Rotas de Avaliações
// POST /api/avaliacoes → Criar nova avaliação (requer auth de cliente)
// =============================================================

const express = require('express');
const router = express.Router();
const avaliacoesController = require('../controllers/avaliacoes.controller');
const authCliente = require('../middlewares/authCliente');

/**
 * @openapi
 * /api/avaliacoes:
 *   post:
 *     summary: Criar uma nova avaliação
 *     tags:
 *       - Avaliações
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - chamado_id
 *               - nota
 *             properties:
 *               chamado_id:
 *                 type: string
 *                 format: uuid
 *                 description: ID do chamado finalizado a ser avaliado
 *               nota:
 *                 type: integer
 *                 minimum: 1
 *                 maximum: 5
 *                 example: 5
 *               comentario:
 *                 type: string
 *                 example: "Excelente atendimento, muito rápido e eficiente."
 *     responses:
 *       '201':
 *         description: Avaliação registrada com sucesso
 *       '400':
 *         description: Erro de validação (nota inválida, chamado não finalizado)
 *       '401':
 *         description: Token não fornecido ou inválido
 *       '403':
 *         description: Não autorizado (não é o dono do chamado)
 *       '409':
 *         description: Este serviço já foi avaliado
 */

const authProfissional = require('../middlewares/authProfissional');

// Rota para o CLIENTE avaliar o PROFISSIONAL
router.post('/cliente', authCliente, avaliacoesController.clienteAvaliaProfissional);

// Rota para o PROFISSIONAL avaliar o CLIENTE
router.post('/profissional', authProfissional, avaliacoesController.profissionalAvaliaCliente);

module.exports = router;