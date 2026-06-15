const express = require('express');
const router = express.Router();
const profissionaisController = require('../controllers/profissionais.controller');

// Mapeamos cada caminho para a sua função correspondente no controlador
router.get('/', profissionaisController.listarProfissionais);
router.get('/:id', profissionaisController.verProfissional);
router.post('/', profissionaisController.registarProfissional);

module.exports = router;