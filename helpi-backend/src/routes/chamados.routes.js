const express = require('express');
const router = express.Router();
const chamadosController = require('../controllers/chamados.controller');

router.post('/', chamadosController.criarChamado);
router.put('/:id/aceitar', chamadosController.aceitarChamado);
router.put('/:id/chegada', chamadosController.registrarChegada);
router.put('/:id/finalizar', chamadosController.finalizarChamado);

module.exports = router;