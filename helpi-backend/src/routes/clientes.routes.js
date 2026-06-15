// =============================================================
// HELPI - Rotas de Clientes
// POST /api/clientes → Registar novo cliente
// =============================================================

const express = require('express');
const router = express.Router();
const clientesController = require('../controllers/clientes.controller');
const { validarCadastroCliente } = require('../middlewares/validators/clienteValidator');

/**
 * @openapi
 * /api/clientes:
 *   post:
 *     summary: Registrar novo cliente
 *     tags: [Clientes]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - nome
 *               - cpf
 *               - email
 *               - senha
 *               - telefone
 *             properties:
 *               nome:
 *                 type: string
 *                 example: "João Silva"
 *               cpf:
 *                 type: string
 *                 example: "52998224725"
 *               email:
 *                 type: string
 *                 example: "joao@email.com"
 *               senha:
 *                 type: string
 *                 example: "minhasenha123"
 *               telefone:
 *                 type: string
 *                 example: "(44) 99999-9999"
 *     responses:
 *       '201':
 *         description: Cliente registrado com sucesso
 *       '400':
 *         description: Erro de validação
 *       '409':
 *         description: E-mail ou CPF já cadastrado
 */
router.post('/', validarCadastroCliente, clientesController.criarCliente);

// FIX: module.exports movido para o final (estava antes da definição das rotas)
module.exports = router;