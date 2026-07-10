// =============================================================
// HELPI - Middleware de Validação de UUID
// Verifica se os parâmetros :id das rotas são UUIDs válidos
// antes de chegar ao controller/banco de dados.
//
// SEGURANÇA V12: Previne queries desnecessárias com IDs inválidos
// e evita poluir logs com erros do PostgreSQL.
// =============================================================

const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

/**
 * Valida que req.params.id é um UUID v4 válido.
 * Retorna 400 imediatamente se não for, sem tocar no banco.
 */
const validarUUID = (req, res, next) => {
    const { id } = req.params;

    if (!id || !UUID_REGEX.test(id)) {
        return res.status(400).json({
            erro: 'O ID fornecido não é um UUID válido.',
        });
    }

    next();
};

module.exports = { validarUUID };
