// =============================================================
// HELPI - Controlador de Avaliações (Motor de Confiança)
// Gerencia as avaliações bi-direcionais (Cliente <-> Profissional)
// e executa a Máquina de Punição.
// =============================================================

const pool = require('../config/database');
const logger = require('../utils/logger');

// Rota: POST /api/avaliacoes/cliente
const clienteAvaliaProfissional = async (req, res, next) => {
    const { chamado_id, nota, tags = [], comentario } = req.body;
    const cliente_id = req.usuario.id;

    if (!nota || nota < 1 || nota > 5) {
        return res.status(400).json({ erro: "A nota deve ser um número inteiro entre 1 e 5." });
    }

    if (!chamado_id) {
        return res.status(400).json({ erro: "O ID do chamado é obrigatório." });
    }

    const client = await pool.connect();

    try {
        await client.query('BEGIN');

        // 1. Validar Chamado
        const verChamado = await client.query(
            'SELECT cliente_id, profissional_id, status FROM chamados_express WHERE id = $1',
            [chamado_id]
        );

        if (verChamado.rows.length === 0) {
            await client.query('ROLLBACK');
            return res.status(404).json({ erro: "Pedido de serviço não encontrado." });
        }

        const chamado = verChamado.rows[0];

        if (chamado.status !== 'finalizado') {
            await client.query('ROLLBACK');
            return res.status(400).json({ erro: "Só é possível avaliar serviços que já foram finalizados." });
        }

        if (chamado.cliente_id !== cliente_id) {
            await client.query('ROLLBACK');
            return res.status(403).json({ erro: "Você só pode avaliar serviços que você solicitou." });
        }

        // 2. Inserir a Avaliação (O Cofre garante que não há duplicados via UNIQUE(chamado_id, avaliador_tipo))
        let novaAvaliacao;
        try {
            const insertResult = await client.query(
                `INSERT INTO avaliacoes (chamado_id, avaliador_id, avaliador_tipo, avaliado_id, avaliado_tipo, nota, tags, comentario) 
                 VALUES ($1, $2, 'cliente', $3, 'profissional', $4, $5, $6) 
                 RETURNING id, nota, tags, comentario, criado_em`,
                [chamado_id, cliente_id, chamado.profissional_id, nota, JSON.stringify(tags), comentario]
            );
            novaAvaliacao = insertResult.rows[0];
        } catch (dbError) {
            // Código 23505 = unique_violation no Postgres
            if (dbError.code === '23505') {
                await client.query('ROLLBACK');
                return res.status(409).json({ erro: "Você já avaliou este serviço anteriormente." });
            }
            throw dbError;
        }

        // 3. Atualizar Cache e Máquina de Punição
        // Atualiza nota_media de forma atômica e verifica a regra de suspensão
        const updateProf = await client.query(
            `UPDATE profissionais 
             SET 
               total_avaliacoes = total_avaliacoes + 1,
               nota_media = ((nota_media * total_avaliacoes) + $1) / (total_avaliacoes + 1),
               status = CASE 
                          WHEN (total_avaliacoes + 1) >= 10 AND (((nota_media * total_avaliacoes) + $1) / (total_avaliacoes + 1)) < 4.0 THEN 'suspenso'
                          ELSE status 
                        END
             WHERE id = $2
             RETURNING nota_media, total_avaliacoes, status`,
            [nota, chamado.profissional_id]
        );

        const profAtualizado = updateProf.rows[0];
        
        await client.query('COMMIT');

        logger.info(`[TRUST_ENGINE] Cliente avaliou Profissional | chamado ${chamado_id} | nota: ${nota}/5 | prof_status: ${profAtualizado.status}`);

        // Opcional: Logar se o profissional foi suspenso agora
        if (profAtualizado.status === 'suspenso') {
            logger.warn(`[TRUST_ENGINE] 🚨 Profissional ${chamado.profissional_id} SUSPENSO (nota ${parseFloat(profAtualizado.nota_media).toFixed(2)})`);
        }

        res.status(201).json({
            mensagem: "Avaliação registrada com sucesso! Obrigado pelo feedback.",
            avaliacao: novaAvaliacao,
            nova_media_profissional: parseFloat(profAtualizado.nota_media).toFixed(2),
            profissional_suspenso: profAtualizado.status === 'suspenso'
        });
    } catch (erro) {
        await client.query('ROLLBACK');
        next(erro);
    } finally {
        client.release();
    }
};

// Rota: POST /api/avaliacoes/profissional
const profissionalAvaliaCliente = async (req, res, next) => {
    const { chamado_id, nota, tags = [], comentario } = req.body;
    const profissional_id = req.usuario.id;

    if (!nota || nota < 1 || nota > 5) {
        return res.status(400).json({ erro: "A nota deve ser um número inteiro entre 1 e 5." });
    }

    if (!chamado_id) {
        return res.status(400).json({ erro: "O ID do chamado é obrigatório." });
    }

    const client = await pool.connect();

    try {
        await client.query('BEGIN');

        // 1. Validar Chamado
        const verChamado = await client.query(
            'SELECT cliente_id, profissional_id, status FROM chamados_express WHERE id = $1',
            [chamado_id]
        );

        if (verChamado.rows.length === 0) {
            await client.query('ROLLBACK');
            return res.status(404).json({ erro: "Pedido de serviço não encontrado." });
        }

        const chamado = verChamado.rows[0];

        if (chamado.status !== 'finalizado') {
            await client.query('ROLLBACK');
            return res.status(400).json({ erro: "Só é possível avaliar serviços que já foram finalizados." });
        }

        if (chamado.profissional_id !== profissional_id) {
            await client.query('ROLLBACK');
            return res.status(403).json({ erro: "Você só pode avaliar serviços que você realizou." });
        }

        // 2. Inserir a Avaliação
        let novaAvaliacao;
        try {
            const insertResult = await client.query(
                `INSERT INTO avaliacoes (chamado_id, avaliador_id, avaliador_tipo, avaliado_id, avaliado_tipo, nota, tags, comentario) 
                 VALUES ($1, $2, 'profissional', $3, 'cliente', $4, $5, $6) 
                 RETURNING id, nota, tags, comentario, criado_em`,
                [chamado_id, profissional_id, chamado.cliente_id, nota, JSON.stringify(tags), comentario]
            );
            novaAvaliacao = insertResult.rows[0];
        } catch (dbError) {
            if (dbError.code === '23505') {
                await client.query('ROLLBACK');
                return res.status(409).json({ erro: "Você já avaliou este serviço anteriormente." });
            }
            throw dbError;
        }

        // 3. Atualizar Cache de Nota do Cliente
        const updateCliente = await client.query(
            `UPDATE clientes 
             SET 
               total_avaliacoes = total_avaliacoes + 1,
               nota_media = ((nota_media * total_avaliacoes) + $1) / (total_avaliacoes + 1)
             WHERE id = $2
             RETURNING nota_media, total_avaliacoes`,
            [nota, chamado.cliente_id]
        );

        const clienteAtualizado = updateCliente.rows[0];
        
        await client.query('COMMIT');

        logger.info(`[TRUST_ENGINE] Profissional avaliou Cliente | chamado ${chamado_id} | nota: ${nota}/5`);

        res.status(201).json({
            mensagem: "Avaliação do cliente registrada com sucesso!",
            avaliacao: novaAvaliacao,
            nova_media_cliente: parseFloat(clienteAtualizado.nota_media).toFixed(2)
        });
    } catch (erro) {
        await client.query('ROLLBACK');
        next(erro);
    } finally {
        client.release();
    }
};

module.exports = { clienteAvaliaProfissional, profissionalAvaliaCliente };