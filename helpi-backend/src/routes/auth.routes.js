const express = require('express');
const router = express.Router();
const authController = require('../controllers/auth.controller');

router.post('/login/clientes', authController.loginCliente);
router.post('/login/profissionais', authController.loginProfissional);

module.exports = router;