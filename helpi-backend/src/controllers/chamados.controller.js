// =============================================================
// HELPI - Controlador de Chamados Express (On-Demand)
// Gerencia o ciclo de vida: criar → aceitar → chegar → finalizar
//
// ESCALABILIDADE:
// - Transações com SELECT FOR UPDATE (anti race-condition)
// - PostGIS ST_DWithin + índice GiST (busca O(log n))
// - WebSocket via rooms (não broadcast global)
// - Paginação cursor-based
// =============================================================

const pool = require('../config/database');
const logger = require('../utils/logger');

// ─── CRIAR CHAMADO ──────────────────────────────────────────
const criarChamado = async (req, res, next) => {
    const client = await pool.connect();
    try {
        await client.query('BEGIN');

        // SEGURANÇA: Usa o ID do token JWT (não do body)
        const cliente_id = req.usuario.id;
        const {
            categoria_solicitada,
            problema_descricao,
            latitude_destino,
            longitude_destino
        } = req.body;

        // ── POSTIGS: Busca espacial com índice GiST (O(log n)) ──
        // ST_DWithin usa o índice GIST automaticamente (vs Haversine que faz full table scan)
        const queryProfissionaisProximos = `
            SELECT id, nome,
                ST_Distance(
                    coordenadas,
                    ST_SetSRID(ST_MakePoint($2, $1), 4326)::geography
                ) / 1000 AS distancia_km
            FROM profissionais
            WHERE is_online = true
              AND categoria = $3
              AND status = 'aprovado'
              AND coordenadas IS NOT NULL
              AND ST_DWithin(
                    coordenadas,
                    ST_SetSRID(ST_MakePoint($2, $1), 4326)::geography,
                    10000
              )
            ORDER BY coordenadas <-> ST_SetSRID(ST_MakePoint($2, $1), 4326)::geography
            LIMIT 5
        `;

        const busca = await client.query(queryProfissionaisProximos, [
            latitude_destino,
            longitude_destino,
            categoria_solicitada
        ]);

        // 1. AGORA NÓS GRAVAMOS SEMPRE NA BASE DE DADOS PRIMEIRO!
        const novoChamado = await client.query(
            `INSERT INTO chamados_express
            (cliente_id, categoria_solicitada, problema_descricao, latitude_destino, longitude_destino, status)
            VALUES ($1, $2, $3, $4, $5, 'procurando_profissional')
            RETURNING id, status, criado_em`,
            [cliente_id, categoria_solicitada, problema_descricao, latitude_destino, longitude_destino]
        );

        // Confirma a gravação no PostGIS (Agora sim, vai aparecer no DBeaver/pgAdmin!)
        await client.query('COMMIT');

        // 2. SE NÃO HOUVER NINGUÉM NUM RAIO DE 10KM, AVISAMOS O SISTEMA
        if (busca.rows.length === 0) {
            logger.info(`Chamado criado em espera: ${novoChamado.rows[0].id} (Sem prof. próximos)`);
            return res.status(201).json({
                mensagem: "Chamado criado com sucesso (em espera). Não há profissionais num raio de 10km no momento.",
                chamado: novoChamado.rows[0],
                profissionais_notificados: 0
            });
        }

        // ── WEBSOCKET: Notifica apenas profissionais próximos (rooms) ──
        const io = req.app.get('io');
        if (io) {
            busca.rows.forEach((prof) => {
                io.to(`profissional:${prof.id}`).emit('novo_chamado_emergencia', {
                    mensagem: `🚨 URGENTE: Precisamos de um ${categoria_solicitada} a ${prof.distancia_km.toFixed(1)}km!`,
                    chamado_id: novoChamado.rows[0].id,
                    categoria: categoria_solicitada,
                    distancia_km: parseFloat(prof.distancia_km.toFixed(1))
                });
            });
        }

        logger.info(`Chamado criado: ${novoChamado.rows[0].id} por cliente ${cliente_id}`);

        res.status(201).json({
            mensagem: "Chamado criado com sucesso! A notificar profissionais próximos...",
            chamado: novoChamado.rows[0],
            profissionais_notificados: busca.rows.length
        });
    } catch (erro) {
        await client.query('ROLLBACK').catch(() => {});
        next(erro);
    } finally {
        client.release();
    }
};

// ─── ACEITAR CHAMADO ────────────────────────────────────────
// ESCALABILIDADE: SELECT FOR UPDATE impede dois profissionais
// de aceitarem o mesmo chamado simultaneamente (lock pessimista)
const aceitarChamado = async (req, res, next) => {
    const client = await pool.connect();
    try {
        await client.query('BEGIN');

        const { id } = req.params;
        const profissional_id = req.usuario.id;

        // Lock pessimista: bloqueia a linha até o COMMIT
        const verChamado = await client.query(
            'SELECT status, cliente_id FROM chamados_express WHERE id = $1 FOR UPDATE',
            [id]
        );

        if (verChamado.rows.length === 0) {
            await client.query('ROLLBACK');
            return res.status(404).json({ erro: "Pedido de emergência não encontrado." });
        }

        if (verChamado.rows[0].status !== 'procurando_profissional') {
            await client.query('ROLLBACK');
            return res.status(400).json({
                erro: "Que pena! Outro profissional já aceitou este pedido ou o cliente cancelou."
            });
        }

        const atualizacao = await client.query(
            `UPDATE chamados_express
             SET status = 'a_caminho',
                 profissional_id = $1,
                 aceite_em = CURRENT_TIMESTAMP
             WHERE id = $2
             RETURNING id, status, profissional_id, cliente_id, aceite_em`,
            [profissional_id, id]
        );

        await client.query('COMMIT');

        // WebSocket: notifica apenas o cliente dono do chamado
        const io = req.app.get('io');
        if (io) {
            io.to(`cliente:${atualizacao.rows[0].cliente_id}`).emit('atualizacao_chamado', {
                chamado_id: id,
                status_novo: 'a_caminho',
                mensagem: "Um profissional aceitou o seu chamado e está a caminho!"
            });
        }

        logger.info(`Chamado ${id} aceito pelo profissional ${profissional_id}`);

        res.json({
            mensagem: "Chamado aceito com sucesso!",
            chamado: atualizacao.rows[0]
        });
    } catch (erro) {
        await client.query('ROLLBACK').catch(() => {});
        next(erro);
    } finally {
        client.release();
    }
};

// ─── REGISTRAR CHEGADA ──────────────────────────────────────
const registrarChegada = async (req, res, next) => {
    const client = await pool.connect();
    try {
        await client.query('BEGIN');

        const { id } = req.params;
        const profissional_id = req.usuario.id;

        const verChamado = await client.query(
            'SELECT status, profissional_id, cliente_id FROM chamados_express WHERE id = $1 FOR UPDATE',
            [id]
        );

        if (verChamado.rows.length === 0) {
            await client.query('ROLLBACK');
            return res.status(404).json({ erro: "Pedido de emergência não encontrado." });
        }

        if (verChamado.rows[0].profissional_id !== profissional_id) {
            await client.query('ROLLBACK');
            return res.status(403).json({ erro: "Você não tem permissão para alterar este pedido." });
        }

        if (verChamado.rows[0].status !== 'a_caminho') {
            await client.query('ROLLBACK');
            return res.status(400).json({ erro: "O pedido precisa estar 'a_caminho' para registrar a chegada." });
        }

        const atualizacao = await client.query(
            `UPDATE chamados_express
             SET status = 'em_servico',
                 chegou_ao_local_em = CURRENT_TIMESTAMP
             WHERE id = $1
             RETURNING id, status, chegou_ao_local_em, cliente_id`,
            [id]
        );

        await client.query('COMMIT');

        const io = req.app.get('io');
        if (io) {
            io.to(`cliente:${atualizacao.rows[0].cliente_id}`).emit('atualizacao_chamado', {
                chamado_id: id,
                status_novo: 'em_servico',
                mensagem: "O profissional chegou ao local!"
            });
        }

        logger.info(`Profissional ${profissional_id} chegou ao local do chamado ${id}`);

        res.json({
            mensagem: "Chegada registrada com sucesso! O cliente foi notificado.",
            chamado: atualizacao.rows[0]
        });
    } catch (erro) {
        await client.query('ROLLBACK').catch(() => {});
        next(erro);
    } finally {
        client.release();
    }
};

// ─── FINALIZAR CHAMADO ──────────────────────────────────────
const finalizarChamado = async (req, res, next) => {
    const client = await pool.connect();
    try {
        await client.query('BEGIN');

        const { id } = req.params;
        const profissional_id = req.usuario.id;

        const verChamado = await client.query(
            'SELECT status, profissional_id, cliente_id FROM chamados_express WHERE id = $1 FOR UPDATE',
            [id]
        );

        if (verChamado.rows.length === 0) {
            await client.query('ROLLBACK');
            return res.status(404).json({ erro: "Pedido de emergência não encontrado." });
        }

        if (verChamado.rows[0].profissional_id !== profissional_id) {
            await client.query('ROLLBACK');
            return res.status(403).json({ erro: "Você não tem permissão para finalizar este pedido." });
        }

        if (verChamado.rows[0].status !== 'em_servico') {
            await client.query('ROLLBACK');
            return res.status(400).json({ erro: "O pedido precisa estar 'em_servico' para ser finalizado." });
        }

        const atualizacao = await client.query(
            `UPDATE chamados_express
             SET status = 'finalizado',
                 finalizado_em = CURRENT_TIMESTAMP
             WHERE id = $1
             RETURNING id, status, finalizado_em, cliente_id`,
            [id]
        );

        await client.query('COMMIT');

        const io = req.app.get('io');
        if (io) {
            io.to(`cliente:${atualizacao.rows[0].cliente_id}`).emit('atualizacao_chamado', {
                chamado_id: id,
                status_novo: 'finalizado',
                mensagem: "Serviço concluído! Por favor, avalie o profissional."
            });
        }

        logger.info(`Chamado ${id} finalizado pelo profissional ${profissional_id}`);

        res.json({
            mensagem: "Serviço finalizado com sucesso! Bom trabalho.",
            chamado: atualizacao.rows[0]
        });
    } catch (erro) {
        await client.query('ROLLBACK').catch(() => {});
        next(erro);
    } finally {
        client.release();
    }
};

// ─── LISTAR CHAMADOS DO CLIENTE (NOVO) ──────────────────────
// Paginação cursor-based para escala
const listarMeusChamados = async (req, res, next) => {
    try {
        const cliente_id = req.usuario.id;
        const { cursor, limit = 20 } = req.query;
        const limitNum = Math.min(parseInt(limit, 10) || 20, 50);

        let query = `
            SELECT id, categoria_solicitada, problema_descricao, status,
                   criado_em, aceite_em, finalizado_em
            FROM chamados_express
            WHERE cliente_id = $1
        `;
        const valores = [cliente_id];

        if (cursor) {
            query += ` AND criado_em < $2`;
            valores.push(cursor);
        }

        query += ` ORDER BY criado_em DESC LIMIT $${valores.length + 1}`;
        valores.push(limitNum + 1); // +1 para saber se há próxima página

        const resultado = await pool.query(query, valores);
        const hasMore = resultado.rows.length > limitNum;
        const chamados = hasMore ? resultado.rows.slice(0, limitNum) : resultado.rows;
        const nextCursor = hasMore ? chamados[chamados.length - 1].criado_em : null;

        res.json({
            chamados,
            paginacao: {
                total_retornado: chamados.length,
                proximo_cursor: nextCursor,
                tem_mais: hasMore
            }
        });
    } catch (erro) {
        next(erro);
    }
};

module.exports = { criarChamado, aceitarChamado, registrarChegada, finalizarChamado, listarMeusChamados };