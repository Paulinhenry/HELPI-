const express = require('express');
const router = express.Router();
const clientesController = require('../controllers/clientes.controller');
const { validarCadastroCliente } = require('../middlewares/validators/clienteValidator');

module.exports = router;

/**
 * @swagger
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
 *             properties:
 *               nome:
 *                 type: string
 *                 example: "João Silva"
 *               cpf:
 *                 type: string
 *                 example: "12345678900"
 *               email:
 *                 type: string
 *                 example: "joao@email.com"
 *               senha:
 *                 type: string
 *                 example: "123456"
 *               telefone:
 *                 type: string
 *                 example: "(44) 99999-9999"
 *     responses:
 *       201:
 *         description: Cliente registrado com sucesso
 *       400:
 *         description: Erro de validação
 */
router.post('/', validarCadastroCliente, clientesController.criarCliente);