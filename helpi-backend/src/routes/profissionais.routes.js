const express = require('express');
const router = express.Router();
const profissionaisController = require('../controllers/profissionais.controller');

/**
 * @openapi
 * /api/profissionais:
 *   get:
 *     summary: Listar profissionais aprovados
 *     tags:
 *       - Profissionais
 *     parameters:
 *       - in: query
 *         name: categoria
 *         schema:
 *           type: string
 *         description: Filtrar profissionais por categoria
 *     responses:
 *       '200':
 *         description: Lista de profissionais
 *
 *   post:
 *     summary: Registrar novo profissional
 *     tags:
 *       - Profissionais
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - nome
 *               - cpf_cnpj
 *               - email
 *               - senha
 *               - telefone
 *               - categoria
 *             properties:
 *               nome:
 *                 type: string
 *                 example: João Silva
 *               cpf_cnpj:
 *                 type: string
 *                 example: "12345678901"
 *               email:
 *                 type: string
 *                 format: email
 *                 example: joao@email.com
 *               senha:
 *                 type: string
 *                 format: password
 *                 example: "123456"
 *               telefone:
 *                 type: string
 *                 example: "(44) 99999-9999"
 *               categoria:
 *                 type: string
 *                 example: Eletricista
 *               biografia:
 *                 type: string
 *                 example: Profissional com 10 anos de experiência.
 *     responses:
 *       '201':
 *         description: Profissional registrado com sucesso
 *       '400':
 *         description: Erro de validação
 *
 * /api/profissionais/{id}:
 *   get:
 *     summary: Ver perfil de um profissional
 *     tags:
 *       - Profissionais
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: ID do profissional
 *     responses:
 *       '200':
 *         description: Dados do profissional
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 id:
 *                   type: string
 *                   example: "64b7c8e2a5f4d9"
 *                 nome:
 *                   type: string
 *                   example: João Silva
 *                 categoria:
 *                   type: string
 *                   example: Eletricista
 *                 biografia:
 *                   type: string
 *                   example: Profissional com 10 anos de experiência.
 *                 telefone:
 *                   type: string
 *                   example: "(44) 99999-9999"
 *                 email:
 *                   type: string
 *                   example: joao@email.com
 *       '404':
 *         description: Profissional não encontrado
 */
router.get('/', profissionaisController.listarProfissionais);
router.get('/:id', profissionaisController.verProfissional);
router.post('/', profissionaisController.registarProfissional);

module.exports = router;