// =============================================================
// HELPI - Validador de Criação de Chamados
// Valida os campos ANTES de processar o chamado.
// =============================================================

const { AppError } = require('../errorHandler');

const validarCriacaoChamado = (req, res, next) => {
    const { categoria_solicitada, problema_descricao, latitude_destino, longitude_destino } = req.body;
    const erros = [];

    // Categoria
    if (!categoria_solicitada || categoria_solicitada.trim().length === 0) {
        erros.push('A categoria do serviço é obrigatória.');
    }

    // Descrição do problema
    if (!problema_descricao || problema_descricao.trim().length < 10) {
        erros.push('A descrição do problema é obrigatória e deve ter ao menos 10 caracteres.');
    }

    // Latitude
    if (latitude_destino === undefined || latitude_destino === null) {
        erros.push('A latitude do destino é obrigatória.');
    } else if (typeof latitude_destino !== 'number' || latitude_destino < -90 || latitude_destino > 90) {
        erros.push('Latitude inválida. Deve ser um número entre -90 e 90.');
    }

    // Longitude
    if (longitude_destino === undefined || longitude_destino === null) {
        erros.push('A longitude do destino é obrigatória.');
    } else if (typeof longitude_destino !== 'number' || longitude_destino < -180 || longitude_destino > 180) {
        erros.push('Longitude inválida. Deve ser um número entre -180 e 180.');
    }

    if (erros.length > 0) {
        return next(new AppError(erros.join(' | '), 400));
    }

    // Normaliza
    req.body.categoria_solicitada = categoria_solicitada.trim();
    req.body.problema_descricao = problema_descricao.trim();

    next();
};

module.exports = { validarCriacaoChamado };
