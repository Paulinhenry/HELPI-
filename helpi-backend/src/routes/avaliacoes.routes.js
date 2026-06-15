const express = require('express');
const router = express.Router();
const avaliacoesController = require('../controllers/avaliacoes.controller');

router.post('/', avaliacoesController.criarAvaliacao);

module.exports = router;