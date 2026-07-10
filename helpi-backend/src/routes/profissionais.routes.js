// =============================================================
// HELPI - Rotas de Profissionais
// GET  /api/profissionais      → Listar profissionais aprovados
// GET  /api/profissionais/:id  → Ver perfil de um profissional
// POST /api/profissionais      → Registar novo profissional
// =============================================================

const express = require('express');
const router = express.Router();
const profissionaisController = require('../controllers/profissionais.controller');
const { validarCadastroProfissional } = require('../middlewares/validators/profissionalValidator');
const { validarUUID } = require('../middlewares/validators/uuidValidator');

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
 *         description: Filtrar profissionais por categoria (ex. Eletricista)
 *     responses:
 *       '200':
 *         description: Lista de profissionais aprovados (ordenados por avaliação)
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
 *                 example: "João Silva"
 *               cpf_cnpj:
 *                 type: string
 *                 example: "12345678901"
 *               email:
 *                 type: string
 *                 format: email
 *                 example: "joao@email.com"
 *               senha:
 *                 type: string
 *                 format: password
 *                 example: "minhasenha123"
 *               telefone:
 *                 type: string
 *                 example: "(44) 99999-9999"
 *               categoria:
 *                 type: string
 *                 example: "Eletricista"
 *               biografia:
 *                 type: string
 *                 example: "Profissional com 10 anos de experiência."
 *     responses:
 *       '201':
 *         description: Profissional registrado com sucesso (aguardando aprovação)
 *       '400':
 *         description: Erro de validação
 *       '409':
 *         description: E-mail ou CPF/CNPJ já cadastrado
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
 *           format: uuid
 *         description: ID do profissional
 *     responses:
 *       '200':
 *         description: Dados do profissional
 *       '404':
 *         description: Profissional não encontrado
 *
 * /api/profissionais/perfil:
 *   put:
 *     summary: Atualizar perfil do profissional autenticado
 *     tags:
 *       - Profissionais
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               nome:
 *                 type: string
 *               telefone:
 *                 type: string
 *               biografia:
 *                 type: string
 *               taxa_visita:
 *                 type: number
 *     responses:
 *       '200':
 *         description: Perfil atualizado
 *       '401':
 *         description: Token inválido
 */

const authProfissional = require('../middlewares/authProfissional');

router.get('/', profissionaisController.listarProfissionais);
router.post('/', validarCadastroProfissional, profissionaisController.registarProfissional);
router.put('/perfil', authProfissional, profissionaisController.atualizarPerfil);
// IMPORTANTE: Rota com parâmetro (:id) deve vir DEPOIS das rotas fixas
router.get('/:id', validarUUID, profissionaisController.verProfissional);

module.exports = router;