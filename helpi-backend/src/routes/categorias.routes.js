const express = require('express');
const router = express.Router();
const { listarCategorias } = require('../controllers/categorias.controller');
const authCliente = require('../middlewares/authCliente');

// Endpoint para clientes listarem as categorias disponíveis
router.get('/', authCliente, listarCategorias);

module.exports = router;
