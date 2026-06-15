// =============================================================
// HELPI - Middleware de Autenticação de Clientes
// Verifica o JWT e garante que o utilizador é um cliente.
// =============================================================

const jwt = require('jsonwebtoken');
const logger = require('../utils/logger');

const authCliente = (req, res, next) => {
    try {
        const authHeader = req.headers.authorization;

        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return res.status(401).json({
                erro: 'Token não fornecido. Envie no formato: Bearer <token>'
            });
        }

        const token = authHeader.split(' ')[1];

        const decoded = jwt.verify(token, process.env.JWT_SECRET);

        if (decoded.tipo !== 'cliente') {
            return res.status(403).json({
                erro: 'Acesso permitido apenas para clientes'
            });
        }

        req.usuario = decoded;
        next();

    } catch (erro) {
        // Distingue token expirado de token inválido para melhor UX
        if (erro.name === 'TokenExpiredError') {
            return res.status(401).json({
                erro: 'Token expirado. Faça login novamente.'
            });
        }

        return res.status(401).json({
            erro: 'Token inválido'
        });
    }
};

module.exports = authCliente;