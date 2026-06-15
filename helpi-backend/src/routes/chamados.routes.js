const express = require('express');
const router = express.Router();
const chamadosController = require('../controllers/chamados.controller');

/**
 * @openapi
 * /api/chamados:
 *   post:
 *     summary: Criar um novo chamado de emergência
 *     tags:
 *       - Chamados
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - cliente_id
 *               - categoria_solicitada
 *               - problema_descricao
 *               - latitude_destino
 *               - longitude_destino
 *             properties:
 *               cliente_id:
 *                 type: string
 *                 example: "64b7c8e2a5f4d9"
 *               categoria_solicitada:
 *                 type: string
 *                 example: "Eletricista"
 *               problema_descricao:
 *                 type: string
 *                 example: "Curto-circuito na residência"
 *               latitude_destino:
 *                 type: number
 *                 format: double
 *                 example: -23.55052
 *               longitude_destino:
 *                 type: number
 *                 format: double
 *                 example: -46.633308
 *     responses:
 *       '201':
 *         description: Chamado criado com sucesso
 *
 * /api/chamados/{id}/aceitar:
 *   put:
 *     summary: Profissional aceita o chamado
 *     tags:
 *       - Chamados
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: ID do chamado
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - profissional_id
 *             properties:
 *               profissional_id:
 *                 type: string
 *                 example: "65a1b2c3d4e5f6"
 *     responses:
 *       '200':
 *         description: Chamado aceito
 *
 * /api/chamados/{id}/chegada:
 *   put:
 *     summary: Profissional avisa que chegou ao local
 *     tags:
 *       - Chamados
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: ID do chamado
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - profissional_id
 *             properties:
 *               profissional_id:
 *                 type: string
 *                 example: "65a1b2c3d4e5f6"
 *     responses:
 *       '200':
 *         description: Chegada registrada
 *
 * /api/chamados/{id}/finalizar:
 *   put:
 *     summary: Finalizar serviço
 *     tags:
 *       - Chamados
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: ID do chamado
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - profissional_id
 *             properties:
 *               profissional_id:
 *                 type: string
 *                 example: "65a1b2c3d4e5f6"
 *     responses:
 *       '200':
 *         description: Serviço finalizado com sucesso
 */
router.post('/', chamadosController.criarChamado);
router.put('/:id/aceitar', chamadosController.aceitarChamado);
router.put('/:id/chegada', chamadosController.registrarChegada);
router.put('/:id/finalizar', chamadosController.finalizarChamado);

module.exports = router;