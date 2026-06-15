const pool = require('../config/database');

// 1. Criar o pedido (Com o motor PostGIS)
const criarChamado = async (req, res, next) => {
    try {
        const { cliente_id, categoria_solicitada, problema_descricao, latitude_destino, longitude_destino } = req.body;

        const queryProfissionaisProximos = `
            SELECT id, nome, 
                   (ST_Distance(coordenadas, ST_SetSRID(ST_MakePoint($2, $1), 4326)) / 1000) AS distancia_km
            FROM profissionais
            WHERE is_online = true 
              AND categoria = $3 
              AND status = 'aprovado'
              AND ST_DWithin(coordenadas, ST_SetSRID(ST_MakePoint($2, $1), 4326), 10000)
            ORDER BY coordenadas <-> ST_SetSRID(ST_MakePoint($2, $1), 4326)
            LIMIT 5
        `;

        const busca = await pool.query(queryProfissionaisProximos, [latitude_destino, longitude_destino, categoria_solicitada]);

        if (busca.rows.length === 0) {
            return res.status(404).json({ 
                erro: `Pedimos desculpa! Não há nenhum ${categoria_solicitada} disponível num raio de 10km neste exato momento.` 
            });
        }

        const novoChamado = await pool.query(
            `INSERT INTO chamados_express 
            (cliente_id, categoria_solicitada, problema_descricao, latitude_destino, longitude_destino, status) 
            VALUES ($1, $2, $3, $4, $5, 'procurando_profissional') 
            RETURNING id, status, criado_em`,
            [cliente_id, categoria_solicitada, problema_descricao, latitude_destino, longitude_destino]
        );

        const io = req.app.get('io');
        if (io) {
            io.emit('novo_chamado_emergencia', {
                mensagem: `🚨 URGENTE: Precisamos de um ${categoria_solicitada} a menos de 10km!`,
                chamado_id: novoChamado.rows[0].id
            });
        }
        
        res.status(201).json({
            mensagem: "Chamado criado com sucesso! A notificar profissionais próximos...",
            chamado: novoChamado.rows[0],
            profissionais_notificados: busca.rows.length 
        });
    } catch (erro) {
        next(erro);
    }
};

// 2. Aceitar o pedido
const aceitarChamado = async (req, res, next) => {
    try {
        const { id } = req.params; 
        const { profissional_id } = req.body; 

        const verChamado = await pool.query('SELECT status FROM chamados_express WHERE id = $1', [id]);
        
        if (verChamado.rows.length === 0) return res.status(404).json({ erro: "Pedido não encontrado." });
        if (verChamado.rows[0].status !== 'procurando_profissional') {
            return res.status(400).json({ erro: "Outro profissional já aceitou este pedido." });
        }

        const atualizacao = await pool.query(
            `UPDATE chamados_express SET profissional_id = $1, status = 'a_caminho', aceite_em = CURRENT_TIMESTAMP 
             WHERE id = $2 RETURNING id, status, aceite_em`,
            [profissional_id, id]
        );

        res.json({ mensagem: "Serviço aceite com sucesso!", chamado: atualizacao.rows[0] });
    } catch (erro) {
        next(erro);
    }
};

// 3. Chegar ao local
const registrarChegada = async (req, res, next) => {
    try {
        const { id } = req.params;
        const { profissional_id } = req.body; 

        const verChamado = await pool.query('SELECT status, profissional_id FROM chamados_express WHERE id = $1', [id]);
        
        if (verChamado.rows.length === 0) return res.status(404).json({ erro: "Pedido não encontrado." });
        if (verChamado.rows[0].profissional_id !== profissional_id) return res.status(403).json({ erro: "Sem permissão." });
        if (verChamado.rows[0].status !== 'a_caminho') return res.status(400).json({ erro: "O pedido precisa estar 'a_caminho'." });

        const atualizacao = await pool.query(
            `UPDATE chamados_express SET status = 'em_servico', chegou_ao_local_em = CURRENT_TIMESTAMP 
             WHERE id = $1 RETURNING id, status, chegou_ao_local_em, cliente_id`, [id]
        );

        const io = req.app.get('io');
        if (io) io.emit('atualizacao_chamado', { chamado_id: id, cliente_id: atualizacao.rows[0].cliente_id, status_novo: 'em_servico' });

        res.json({ mensagem: "Chegada registrada com sucesso!", chamado: atualizacao.rows[0] });
    } catch (erro) {
        next(erro);
    }
};

// 4. Finalizar o serviço
const finalizarChamado = async (req, res, next) => {
    try {
        const { id } = req.params;
        const { profissional_id } = req.body; 

        const verChamado = await pool.query('SELECT status, profissional_id FROM chamados_express WHERE id = $1', [id]);
        
        if (verChamado.rows.length === 0) return res.status(404).json({ erro: "Pedido não encontrado." });
        if (verChamado.rows[0].profissional_id !== profissional_id) return res.status(403).json({ erro: "Sem permissão." });
        if (verChamado.rows[0].status !== 'em_servico') return res.status(400).json({ erro: "O pedido precisa estar 'em_servico'." });

        const atualizacao = await pool.query(
            `UPDATE chamados_express SET status = 'finalizado', finalizado_em = CURRENT_TIMESTAMP 
             WHERE id = $1 RETURNING id, status, finalizado_em, cliente_id`, [id]
        );

        const io = req.app.get('io');
        if (io) io.emit('atualizacao_chamado', { chamado_id: id, cliente_id: atualizacao.rows[0].cliente_id, status_novo: 'finalizado' });

        res.json({ mensagem: "Serviço finalizado com sucesso!", chamado: atualizacao.rows[0] });
    } catch (erro) {
        next(erro);
    }
};

module.exports = { criarChamado, aceitarChamado, registrarChegada, finalizarChamado };