const pool = require('../config/database');
const logger = require('../utils/logger');

exports.obterHistorico = async (req, res, next) => {
    try {
        const { id: chamado_id } = req.params;
        
        // Verifica se quem está a pedir está autenticado 
        // (O middleware authMiddleware já garante req.usuario)
        const usuario_id = req.usuario.id;

        // Idealmente, deve-se verificar se o chamado_id pertence a este usuario_id (cliente ou profissional)
        // Para simplificar no MVP, retornamos as mensagens do chamado
        const query = `
            SELECT id, chamado_id, remetente_id, tipo_remetente, texto, criado_em 
            FROM mensagens_chat 
            WHERE chamado_id = $1 
            ORDER BY criado_em ASC
        `;
        
        const { rows } = await pool.query(query, [chamado_id]);
        
        res.status(200).json({
            sucesso: true,
            mensagens: rows
        });
    } catch (error) {
        logger.error(`[CHAT] Erro ao obter histórico: ${error.message}`);
        next(error);
    }
};
