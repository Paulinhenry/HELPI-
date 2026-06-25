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

        // Mapeamento de categorias Cliente -> Profissional
        const mapaCategorias = {
            'Elétrica': 'Eletricista',
            'Hidráulica': 'Encanador',
            'Chaveiro': 'Chaveiro',
            'Limpeza': 'Limpeza',
            'Montador': 'Montador'
        };
        // Tenta usar o mapeamento, ignora case
        const catSoli = categoria_solicitada;
        const categoriaMapeada = mapaCategorias[catSoli] || catSoli;

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
              AND LOWER(categoria) = LOWER($3)
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
            categoriaMapeada
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
            logger.info(`[CHAMADO] CRIADO_EM_ESPERA: chamado ${novoChamado.rows[0].id} criado sem profissionais no raio de 10km (cliente: ${cliente_id})`);
            return res.status(201).json({
                mensagem: "Chamado criado com sucesso (em espera). Não há profissionais num raio de 10km no momento.",
                chamado: novoChamado.rows[0],
                profissionais_notificados: 0
            });
        }

        // --- COMEÇA AQUI O NOVO CÓDIGO DA SIRENE ---

        // 3. A SIRENE DIGITAL (WEBSOCKETS)
        const io = req.app.get('io');
        const profissionaisConectados = req.app.get('profissionaisConectados');
        let profissionaisNotificados = 0;

        if (io && profissionaisConectados) {
            // Percorre todos os profissionais que o PostGIS encontrou num raio de 10km
            busca.rows.forEach(profissional => {
                // Verifica se este profissional específico está com a app aberta (online)
                const socketId = profissionaisConectados.get(profissional.id);
                
                if (socketId) {
                    // Dispara a notificação de emergência diretamente para o telemóvel dele
                    io.to(socketId).emit('novo_chamado_emergencia', {
                        chamado_id: novoChamado.rows[0].id,
                        categoria: categoria_solicitada,
                        descricao: problema_descricao,
                        distancia_metros: Math.round(profissional.distancia_km * 1000), // convertendo km pra metros caso necessário, ou só profissional.distancia_metros se existisse na query. A query retorna distancia_km.
                        valor_sugerido: 40.00 // A taxa de deslocamento que planeámos
                        // 🔒 Segurança: Não enviamos a morada exata nem as coordenadas 
                        // do cliente até o profissional aceitar o serviço!
                    });
                    profissionaisNotificados++;
                }
            });
        }

        logger.info(`[CHAMADO] CRIADO: chamado ${novoChamado.rows[0].id} por cliente ${cliente_id} | categoria: ${categoria_solicitada} | profissionais_no_raio: ${busca.rows.length} | notificados: ${profissionaisNotificados}`);

        return res.status(201).json({
            mensagem: "Emergência disparada! Profissionais notificados.",
            chamado: novoChamado.rows[0],
            profissionais_encontrados_no_raio: busca.rows.length,
            profissionais_online_notificados: profissionaisNotificados
        });
        
        // --- TERMINA AQUI O NOVO CÓDIGO ---
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
             RETURNING id, status, profissional_id, cliente_id, aceite_em,
                       latitude_destino, longitude_destino,
                       categoria_solicitada, problema_descricao`,
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

        logger.info(`[CHAMADO] ACEITE: chamado ${id} aceite pelo profissional ${profissional_id} | status: a_caminho | cliente: ${atualizacao.rows[0].cliente_id}`);

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

        logger.info(`[CHAMADO] CHEGADA: profissional ${profissional_id} chegou ao local do chamado ${id} | status: em_servico`);

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

        logger.info(`[CHAMADO] FINALIZADO: chamado ${id} finalizado pelo profissional ${profissional_id} | status: finalizado`);

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

const cancelarChamado = async (req, res) => {
    const { id } = req.params;
    const cliente_id = req.usuario.id; // O JWT injeta isto automaticamente

    try {
        // Atualiza apenas se o chamado pertencer ao cliente e ainda estiver à procura
        const result = await pool.query(
            `UPDATE chamados_express 
             SET status = 'cancelado_pelo_cliente' 
             WHERE id = $1 AND cliente_id = $2 AND status = 'procurando_profissional'
             RETURNING id, status`,
            [id, cliente_id]
        );

        if (result.rows.length === 0) {
            return res.status(400).json({ 
                erro: 'Chamado não encontrado ou já foi aceite por um profissional.' 
            });
        }

        logger.info(`[CHAMADO] CANCELADO: chamado ${id} cancelado pelo cliente ${cliente_id} | status: cancelado_pelo_cliente`);

        return res.status(200).json({ 
            mensagem: 'Chamado cancelado com sucesso.', 
            chamado: result.rows[0] 
        });
    } catch (error) {
        logger.error(`[CHAMADO] ERRO_CANCELAMENTO: falha ao cancelar chamado ${id}`, { error: error.message, cliente_id });
        return res.status(500).json({ erro: 'Erro interno ao cancelar o pedido.' });
    }
};

module.exports = { criarChamado, aceitarChamado, registrarChegada, finalizarChamado, listarMeusChamados, cancelarChamado };