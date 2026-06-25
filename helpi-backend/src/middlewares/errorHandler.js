// =============================================================
// HELPI - Middleware de Tratamento de Erros Centralizado
// Todos os erros do app passam por aqui, em vez de ficarem
// espalhados dentro de cada rota com try/catch repetido.
// =============================================================

const logger = require('../utils/logger');

// Mapa de códigos de erro do PostgreSQL para mensagens amigáveis
const PG_ERRORS = {
    '23505': { status: 409, mensagem: 'Este e-mail ou CPF já está cadastrado na plataforma.' },
    '23502': { status: 400, mensagem: 'Um campo obrigatório não foi enviado.' },
    '23503': { status: 400, mensagem: 'Referência inválida: o recurso relacionado não existe.' },
    '22001': { status: 400, mensagem: 'Um dos campos enviados é longo demais.' },
    '42P01': { status: 500, mensagem: 'Erro interno: tabela não encontrada.' },
};

// Erros de validação lançados manualmente pelas rotas/validators
class AppError extends Error {
    constructor(mensagem, status = 400) {
        super(mensagem);
        this.status = status;
        this.isOperational = true; // Distingue erros esperados de bugs
    }
}

// O middleware em si — Express identifica pelo 4º parâmetro (err)
const errorHandler = (err, req, res, next) => {
    // --- Erro do PostgreSQL ---
    if (err.code && PG_ERRORS[err.code]) {
        const { status, mensagem } = PG_ERRORS[err.code];
        return res.status(status).json({ erro: mensagem });
    }

    // --- Erro operacional lançado manualmente com AppError ---
    if (err.isOperational) {
        return res.status(err.status).json({ erro: err.message });
    }

    // --- JSON malformado (body-parser) ---
    if (err.type === 'entity.parse.failed') {
        return res.status(400).json({ erro: 'O corpo da requisição não é um JSON válido.' });
    }

    // --- Erro desconhecido (bug real) ---
    // Em produção, não expõe detalhes internos
    logger.error(`[ERROR] ERRO_NAO_TRATADO: ${err.message}`, { 
        stack: err.stack,
        url: req.originalUrl,
        method: req.method
    });

    const isProd = process.env.NODE_ENV === 'production';
    return res.status(500).json({
        erro: 'Erro interno do servidor.',
        // Em desenvolvimento, o front-end ainda recebe o erro para te ajudar a debugar
        ...(isProd ? {} : { detalhes: err.message }),
    });
};

module.exports = { errorHandler, AppError };
