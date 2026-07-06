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
const { AppError } = require('../middlewares/errorHandler');
const { TAXA_DESLOCAMENTO, MAPA_CATEGORIAS } = require('../utils/constants');
const { analisarProblema } = require('../utils/precificador');

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

        // VALIDAÇÃO: Verifica inputs obrigatórios e válidos
        if (!categoria_solicitada || !problema_descricao || latitude_destino === undefined || longitude_destino === undefined) {
            await client.query('ROLLBACK');
            throw new AppError('Todos os campos são obrigatórios (categoria, descrição, latitude e longitude).', 400);
        }
        if (typeof latitude_destino !== 'number' || typeof longitude_destino !== 'number') {
            await client.query('ROLLBACK');
            throw new AppError('Latitude e longitude devem ser números válidos.', 400);
        }

        // Tenta usar o mapeamento, ignora case
        const catSoli = categoria_solicitada;
        const categoriaMapeada = MAPA_CATEGORIAS[catSoli] || catSoli;

        // --- INTEGRAÇÃO COM MOTOR DE PRECIFICAÇÃO ---
        const estimativa = analisarProblema(categoria_solicitada, problema_descricao);

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
            (cliente_id, categoria_solicitada, problema_descricao, latitude_destino, longitude_destino, status, valor_estimado_min, valor_estimado_max)
            VALUES ($1, $2, $3, $4, $5, 'procurando_profissional', $6, $7)
            RETURNING id, status, criado_em`,
            [cliente_id, categoria_solicitada, problema_descricao, latitude_destino, longitude_destino, estimativa.preco_minimo, estimativa.preco_maximo]
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
                        // SEGURANÇA: Truncado a 500 chars para evitar payload gigante via WebSocket
                        descricao: problema_descricao.substring(0, 500),
                        distancia_metros: Math.round(profissional.distancia_km * 1000), 
                        // Mostra o valor COM DESCONTO de 10% da plataforma para o profissional
                        valor_sugerido: estimativa.preco_sugerido * 0.90, 
                        valor_estimado_min: estimativa.preco_minimo * 0.90,
                        valor_estimado_max: estimativa.preco_maximo * 0.90
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
            estimativa: {
                min: estimativa.preco_minimo,
                max: estimativa.preco_maximo,
                sugerido: estimativa.preco_sugerido
            },
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

        // Calcula distância usando PostGIS e busca o nome do eletricista
        const infoProf = await client.query(
            `SELECT p.nome,
                    ST_Distance(
                        p.coordenadas,
                        ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography
                    ) AS distancia_metros
             FROM profissionais p
             WHERE p.id = $3`,
            [atualizacao.rows[0].longitude_destino, atualizacao.rows[0].latitude_destino, profissional_id]
        );

        let profissional_nome = "O Profissional";
        let distancia_texto = "calculando distância...";

        if (infoProf.rows.length > 0) {
            profissional_nome = infoProf.rows[0].nome;
            if (infoProf.rows[0].distancia_metros != null) {
                const distancia_metros = Math.round(infoProf.rows[0].distancia_metros);
                distancia_texto = distancia_metros > 1000 
                    ? `${(distancia_metros / 1000).toFixed(1)} km` 
                    : `${distancia_metros} metros`;
            }
        }

        await client.query('COMMIT');

        // WebSocket: notifica apenas o cliente dono do chamado (O Suspiro de Alívio)
        const io = req.app.get('io');
        if (io) {
            io.to(`cliente:${atualizacao.rows[0].cliente_id}`).emit('atualizacao_chamado', {
                chamado_id: id,
                status_novo: 'a_caminho',
                profissional_nome: profissional_nome,
                distancia_texto: distancia_texto,
                mensagem: `${profissional_nome} aceitou e está a ${distancia_texto}!`
            });
        }

        // WebSocket: notifica TODOS os outros profissionais que este chamado já foi aceite
        // Isto faz o popup de "NOVO SERVIÇO" desaparecer nos telemóveis dos que perderam
        const profissionaisConectados = req.app.get('profissionaisConectados');
        if (io && profissionaisConectados) {
            for (const [profId, socketId] of profissionaisConectados.entries()) {
                if (profId !== profissional_id) {
                    io.to(socketId).emit('chamado_expirado', {
                        chamado_id: id,
                        motivo: 'aceite_por_outro'
                    });
                }
            }
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
        const { valor_cobrado } = req.body;
        const profissional_id = req.usuario.id;

        const verChamado = await client.query(
            'SELECT status, profissional_id, cliente_id, valor_estimado_min, valor_estimado_max FROM chamados_express WHERE id = $1 FOR UPDATE',
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

        if (!valor_cobrado || isNaN(valor_cobrado)) {
            await client.query('ROLLBACK');
            return res.status(400).json({ erro: "É necessário informar o valor cobrado pelo serviço." });
        }

        const minEstimado = parseFloat(verChamado.rows[0].valor_estimado_min);
        const maxEstimado = parseFloat(verChamado.rows[0].valor_estimado_max);
        
        // Tolerância de 30%
        if (minEstimado && maxEstimado) {
            const limiteMax = maxEstimado * 1.30;
            if (valor_cobrado < minEstimado || valor_cobrado > limiteMax) {
                await client.query('ROLLBACK');
                return res.status(400).json({ 
                    erro: `O valor cobrado (R$ ${valor_cobrado}) está fora do intervalo permitido. Mínimo: R$ ${minEstimado}, Máximo: R$ ${limiteMax.toFixed(2)}.` 
                });
            }
        }

        const atualizacao = await client.query(
            `UPDATE chamados_express
             SET status = 'finalizado',
                 valor_cobrado = $2,
                 finalizado_em = CURRENT_TIMESTAMP
             WHERE id = $1
             RETURNING id, status, finalizado_em, cliente_id, valor_cobrado, valor_estimado_min, valor_estimado_max, categoria_solicitada, problema_descricao`,
            [id, valor_cobrado]
        );

        await client.query('COMMIT');

        const io = req.app.get('io');
        if (io) {
            io.to(`cliente:${atualizacao.rows[0].cliente_id}`).emit('atualizacao_chamado', {
                chamado_id: id,
                status_novo: 'finalizado',
                mensagem: "Serviço finalizado com sucesso!",
                valor_cobrado: atualizacao.rows[0].valor_cobrado,
                categoria: atualizacao.rows[0].categoria_solicitada,
                descricao: atualizacao.rows[0].problema_descricao
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

// ─── VERIFICAR CHAMADO ATIVO (CRASH RECOVERY) ──────────────
// Quando o profissional reabre a app (ex: bateria morreu), esta rota
// diz-lhe se tem algum chamado em andamento para retomar.
// Retorna o chamado ativo ou null.
const verificarChamadoAtivo = async (req, res, next) => {
    try {
        const profissional_id = req.usuario.id;

        const resultado = await pool.query(
            `SELECT id, status, cliente_id, latitude_destino, longitude_destino,
                    categoria_solicitada, problema_descricao
             FROM chamados_express
             WHERE profissional_id = $1
               AND status IN ('a_caminho', 'em_servico')
             ORDER BY aceite_em DESC
             LIMIT 1`,
            [profissional_id]
        );

        if (resultado.rows.length === 0) {
            return res.json({ chamado_ativo: null });
        }

        logger.info(`[CRASH_RECOVERY] Profissional ${profissional_id} tem chamado ativo: ${resultado.rows[0].id} (status: ${resultado.rows[0].status})`);

        return res.json({ chamado_ativo: resultado.rows[0] });
    } catch (erro) {
        next(erro);
    }
};

// ─── CRASH RECOVERY CLIENTE ─────────────────────────────────
// Retorna o chamado ativo do cliente ou null.
const verificarChamadoAtivoCliente = async (req, res, next) => {
    try {
        const cliente_id = req.usuario.id;

        const resultado = await pool.query(
            `SELECT c.id, c.status, c.categoria_solicitada, c.problema_descricao,
                    c.profissional_id, p.nome as profissional_nome
             FROM chamados_express c
             LEFT JOIN profissionais p ON c.profissional_id = p.id
             WHERE c.cliente_id = $1
               AND c.status IN ('procurando_profissional', 'a_caminho', 'em_servico')
             ORDER BY c.criado_em DESC
             LIMIT 1`,
            [cliente_id]
        );

        if (resultado.rows.length === 0) {
            return res.json({ chamado_ativo: null });
        }

        logger.info(`[CRASH_RECOVERY] Cliente ${cliente_id} tem chamado ativo: ${resultado.rows[0].id} (status: ${resultado.rows[0].status})`);

        return res.json({ chamado_ativo: resultado.rows[0] });
    } catch (erro) {
        next(erro);
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

module.exports = { criarChamado, aceitarChamado, registrarChegada, finalizarChamado, verificarChamadoAtivo, verificarChamadoAtivoCliente, listarMeusChamados, cancelarChamado };