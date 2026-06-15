const express = require('express');
const router = express.Router();
const avaliacoesController = require('../controllers/avaliacoes.controller');

/**
 * @openapi
 * /api/avaliacoes:
 *   post:
 *     summary: Criar uma nova avaliação
 *     tags:
 *       - Avaliações
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - cliente_id
 *               - profissional_id
 *               - chamado_id
 *               - nota
 *             properties:
 *               cliente_id:
 *                 type: string
 *                 example: "64b7c8e2a5f4d9"
 *               profissional_id:
 *                 type: string
 *                 example: "65a1b2c3d4e5f6"
 *               chamado_id:
 *                 type: string
 *                 example: "66c2d3e4f5g6h7"
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
 *         description: Erro de validação
 *
 * /api/avaliacoes/profissional/{profissional_id}:
 *   get:
 *     summary: Listar avaliações de um profissional
 *     tags:
 *       - Avaliações
 *     parameters:
 *       - in: path
 *         name: profissional_id
 *         required: true
 *         schema:
 *           type: string
 *         description: ID do profissional
 *     responses:
 *       '200':
 *         description: Lista de avaliações recuperada
 *         content:
 *           application/json:
 *             schema:
 *               type: array
 *               items:
 *                 type: object
 *                 properties:
 *                   cliente_id:
 *                     type: string
 *                     example: "64b7c8e2a5f4d9"
 *                   chamado_id:
 *                     type: string
 *                     example: "66c2d3e4f5g6h7"
 *                   nota:
 *                     type: integer
 *                     example: 5
 *                   comentario:
 *                     type: string
 *                     example: "Excelente atendimento."
 *       '404':
 *         description: Profissional não encontrado
 */
router.post('/', avaliacoesController.criarAvaliacao);

module.exports = router;