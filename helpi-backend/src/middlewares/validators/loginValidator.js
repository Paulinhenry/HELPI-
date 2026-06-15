// =============================================================
// HELPI - Validador de Login
// Valida os campos de email e senha antes de tocar no banco.
// =============================================================

const { AppError } = require('../errorHandler');

const validarLogin = (req, res, next) => {
    const { email, senha } = req.body;
    const erros = [];

    if (!email || typeof email !== 'string' || email.trim().length === 0) {
        erros.push('E-mail é obrigatório.');
    } else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
        erros.push('E-mail inválido.');
    }

    if (!senha || typeof senha !== 'string' || senha.length === 0) {
        erros.push('Senha é obrigatória.');
    }

    if (erros.length > 0) {
        return next(new AppError(erros.join(' | '), 400));
    }

    // Normaliza email antes de seguir
    req.body.email = email.toLowerCase().trim();

    next();
};

module.exports = { validarLogin };
