const express = require('express');
const router = express.Router();
const chamadosController = require('../controllers/chamados.controller');

// Importar os middlewares de controlo de acesso desenvolvidos pelo Victor
const authCliente = require('../middlewares/authCliente');
const authProfissional = require('../middlewares/authProfissional');

/**
 * @openapi
 * /api/chamados:
 *   post:
 *     summary: Criar um novo chamado de emergência
 *     tags: [Chamados]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               cliente_id:
 *                 type: string
 *               categoria_solicitada:
 *                 type: string
 *               problema_descricao:
 *                 type: string
 *               latitude_destino:
 *                 type: number
 *               longitude_destino:
 *                 type: number
 *     responses:
 *       201:
 *         description: Chamado criado com sucesso
 *       401:
 *         description: Token não fornecido ou inválido
 *       403:
 *         description: Acesso permitido apenas para clientes
 *
 * /api/chamados/{id}/aceitar:
 *   put:
 *     summary: Profissional aceita o chamado
 *     tags: [Chamados]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               profissional_id:
 *                 type: string
 *     responses:
 *       200:
 *         description: Chamado aceite com sucesso
 *       401:
 *         description: Token inválido
 *       403:
 *         description: Acesso permitido apenas para profissionais
 *
 * /api/chamados/{id}/chegada:
 *   put:
 *     summary: Profissional avisa que chegou ao local
 *     tags: [Chamados]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               profissional_id:
 *                 type: string
 *     responses:
 *       200:
 *         description: Chegada registada com sucesso
 *
 * /api/chamados/{id}/finalizar:
 *   put:
 *     summary: Finalizar o serviço prestado
 *     tags: [Chamados]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               profissional_id:
 *                 type: string
 *     responses:
 *       200:
 *         description: Serviço finalizado com sucesso
 */

// Aplicar as restrições diretamente nos endpoints correspondentes
router.post('/', authCliente, chamadosController.criarChamado);
router.put('/:id/aceitar', authProfissional, chamadosController.aceitarChamado);
router.put('/:id/chegada', authProfissional, chamadosController.registrarChegada);
router.put('/:id/finalizar', authProfissional, chamadosController.finalizarChamado);

module.exports = router;