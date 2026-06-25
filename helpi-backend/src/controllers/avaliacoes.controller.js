// =============================================================
// HELPI - Controlador de Avaliações
// Gerencia a avaliação de serviços finalizados pelos clientes.
// =============================================================

const pool = require('../config/database');
const logger = require('../utils/logger');

const criarAvaliacao = async (req, res, next) => {
    const { chamado_id, nota, comentario } = req.body;
    // SEGURANÇA: O cliente_id vem do token JWT, não do body
    const cliente_id_logado = req.usuario.id;

    // Validações ANTES de obter conexão do pool (evita desperdício de conexões)
    if (!nota || nota < 1 || nota > 5) {
        return res.status(400).json({ erro: "A nota deve ser um número inteiro entre 1 e 5." });
    }

    if (!chamado_id) {
        return res.status(400).json({ erro: "O ID do chamado é obrigatório." });
    }

    // Usa uma transação para garantir atomicidade (INSERT + UPDATE juntos)
    const client = await pool.connect();

    try {
        const verChamado = await client.query(
            'SELECT cliente_id, profissional_id, status FROM chamados_express WHERE id = $1',
            [chamado_id]
        );

        if (verChamado.rows.length === 0) {
            return res.status(404).json({ erro: "Pedido de serviço não encontrado." });
        }

        if (verChamado.rows[0].status !== 'finalizado') {
            return res.status(400).json({ erro: "Só é possível avaliar serviços que já foram finalizados." });
        }

        // SEGURANÇA: Verifica se o cliente logado é realmente o dono do chamado
        if (verChamado.rows[0].cliente_id !== cliente_id_logado) {
            return res.status(403).json({ erro: "Você só pode avaliar serviços que você solicitou." });
        }

        const { cliente_id, profissional_id } = verChamado.rows[0];

        const jaAvaliado = await client.query('SELECT id FROM avaliacoes WHERE chamado_id = $1', [chamado_id]);
        if (jaAvaliado.rows.length > 0) {
            return res.status(409).json({ erro: "Este serviço já foi avaliado anteriormente." });
        }

        // Inicia transação para garantir consistência
        await client.query('BEGIN');

        const novaAvaliacao = await client.query(
            `INSERT INTO avaliacoes (chamado_id, cliente_id, profissional_id, nota, comentario) 
             VALUES ($1, $2, $3, $4, $5) 
             RETURNING id, nota, comentario, criado_em`,
            [chamado_id, cliente_id, profissional_id, nota, comentario]
        );

        const media = await client.query(
            'SELECT AVG(nota) as media_notas FROM avaliacoes WHERE profissional_id = $1',
            [profissional_id]
        );
        const novaMedia = parseFloat(media.rows[0].media_notas).toFixed(1);

        await client.query('UPDATE profissionais SET avaliacao = $1 WHERE id = $2', [novaMedia, profissional_id]);

        await client.query('COMMIT');

        logger.info(`[AVALIACAO] CRIADA: chamado ${chamado_id} | nota: ${nota}/5 | profissional: ${profissional_id} | nova_media: ${novaMedia}`);

        res.status(201).json({
            mensagem: "Avaliação registada com sucesso! Obrigado pelo feedback.",
            avaliacao: novaAvaliacao.rows[0],
            nova_media_profissional: novaMedia
        });
    } catch (erro) {
        await client.query('ROLLBACK');
        next(erro);
    } finally {
        client.release();
    }
};

module.exports = { criarAvaliacao };