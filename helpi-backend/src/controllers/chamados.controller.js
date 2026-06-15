const pool = require('../config/database');
const bcrypt = require('bcrypt');

// ==========================================
// MÓDULO ON-DEMAND (ESTILO UBER)
// ==========================================

// 4. Criar um Chamado Express (O cliente pede socorro)
app.post('/api/chamados', authCliente, async (req, res, next) => {
    try {
        const {
    categoria_solicitada,
    problema_descricao,
    latitude_destino,
    longitude_destino
    } = req.body;

    const cliente_id = req.usuario.id;

        const queryProfissionaisProximos = `
            SELECT id, nome, 
            (6371 * acos(
                cos(radians($1)) * cos(radians(latitude_atual)) * cos(radians(longitude_atual) - radians($2)) + 
                sin(radians($1)) * sin(radians(latitude_atual))
            )) AS distancia_km
            FROM profissionais
            WHERE is_online = true 
              AND categoria = $3 
              AND status = 'aprovado'
              AND latitude_atual IS NOT NULL
        `;

        const busca = await pool.query(`SELECT * FROM (${queryProfissionaisProximos}) AS subset WHERE distancia_km <= 10 ORDER BY distancia_km ASC LIMIT 5`, 
        [latitude_destino, longitude_destino, categoria_solicitada]);

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
});

// 5. Profissional aceita o chamado de emergência
app.put('/api/chamados/:id/aceitar', authProfissional, async (req, res, next) => {  
    try {
        const { id } = req.params; 
        const profissional_id = req.usuario.id; 

        const verChamado = await pool.query('SELECT status FROM chamados_express WHERE id = $1', [id]);
        
        if (verChamado.rows.length === 0) {
            return res.status(404).json({ erro: "Pedido de emergência não encontrado." });
        }
        
        if (verChamado.rows[0].status !== 'procurando_profissional') {
            return res.status(400).json({ 
                erro: "Que pena! Outro profissional já aceitou este pedido ou o cliente cancelou." 
            });
        }


    } catch (erro) {
        next(erro);
    }
});

// 6. Profissional avisa que chegou ao local
app.put('/api/chamados/:id/chegada', authProfissional, async (req, res, next) => {
    try {
        const { id } = req.params;
        const profissional_id = req.usuario.id;

        const verChamado = await pool.query('SELECT status, profissional_id FROM chamados_express WHERE id = $1', [id]);
        
        if (verChamado.rows.length === 0) {
            return res.status(404).json({ erro: "Pedido de emergência não encontrado." });
        }
        
        // Segurança: Garante que apenas o profissional que aceitou o pedido pode dizer que chegou
        if (verChamado.rows[0].profissional_id !== profissional_id) {
            return res.status(403).json({ erro: "Você não tem permissão para alterar este pedido." });
        }

        if (verChamado.rows[0].status !== 'a_caminho') {
            return res.status(400).json({ erro: "O pedido precisa estar 'a_caminho' para registrar a chegada." });
        }

        const atualizacao = await pool.query(
            `UPDATE chamados_express 
             SET status = 'em_servico', 
                 chegou_ao_local_em = CURRENT_TIMESTAMP 
             WHERE id = $1 
             RETURNING id, status, chegou_ao_local_em, cliente_id`,
            [id]
        );

        // Dispara o WebSocket para o telemóvel do cliente atualizar a tela instantaneamente
        const io = req.app.get('io');
        if (io) {
            io.emit('atualizacao_chamado', {
                chamado_id: id,
                cliente_id: atualizacao.rows[0].cliente_id,
                status_novo: 'em_servico',
                mensagem: "O profissional chegou ao local!"
            });
        }

        res.json({
            mensagem: "Chegada registrada com sucesso! O cliente foi notificado.",
            chamado: atualizacao.rows[0]
        });

    } catch (erro) {
        next(erro);
    }
});

// 7. Profissional finaliza o serviço
app.put('/api/chamados/:id/finalizar', authProfissional, async (req, res, next) => {
    try {
        const { id } = req.params;
        const profissional_id = req.usuario.id;

        const verChamado = await pool.query('SELECT status, profissional_id FROM chamados_express WHERE id = $1', [id]);
        
        if (verChamado.rows.length === 0) {
            return res.status(404).json({ erro: "Pedido de emergência não encontrado." });
        }
        
        if (verChamado.rows[0].profissional_id !== profissional_id) {
            return res.status(403).json({ erro: "Você não tem permissão para finalizar este pedido." });
        }

        if (verChamado.rows[0].status !== 'em_servico') {
            return res.status(400).json({ erro: "O pedido precisa estar 'em_servico' para ser finalizado." });
        }

        const atualizacao = await pool.query(
            `UPDATE chamados_express 
             SET status = 'finalizado', 
                 finalizado_em = CURRENT_TIMESTAMP 
             WHERE id = $1 
             RETURNING id, status, finalizado_em, cliente_id`,
            [id]
        );

        // Dispara o WebSocket final para a tela de avaliação do cliente
        const io = req.app.get('io');
        if (io) {
            io.emit('atualizacao_chamado', {
                chamado_id: id,
                cliente_id: atualizacao.rows[0].cliente_id,
                status_novo: 'finalizado',
                mensagem: "Serviço concluído! Por favor, avalie o profissional."
            });
        }

        res.json({
            mensagem: "Serviço finalizado com sucesso! Bom trabalho.",
            chamado: atualizacao.rows[0]
        });

    } catch (erro) {
        next(erro);
    }
});
