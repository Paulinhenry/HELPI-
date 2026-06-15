const express = require('express');
const router = express.Router();
const clientesController = require('../controllers/clientes.controller');
const { validarCadastroCliente } = require('../middlewares/validators/clienteValidator');

// Quando alguém fizer um POST para a raiz desta rota, valida e chama o controlador
router.post('/', validarCadastroCliente, clientesController.criarCliente);

module.exports = router;