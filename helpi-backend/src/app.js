const express = require('express');
const pool = require('./config/database');
const { errorHandler } = require('./middlewares/errorHandler');
const { validarCadastroCliente } = require('./middlewares/validators/clienteValidator');
const bcrypt = require('bcrypt'); // Adicionado pelo Victor

const app = express();

app.use(express.json());

// -------------------------------------------------------
// STATUS DA API
// -------------------------------------------------------
app.get('/api/status', (req, res) => {
    res.json({ message: 'Motor do Helpi a funcionar perfeitamente!' });
});

// -------------------------------------------------------
// MÓDULO DE CLIENTES
// -------------------------------------------------------

app.post('/api/clientes', validarCadastroCliente, async (req, res, next) => {
    try {
        const { nome, cpf, email, senha, telefone } = req.body;
        
        // CÓDIGO DO VICTOR: Encriptação de senha ativada! 🔒
        const senhaHash = await bcrypt.hash(senha, 10); 
        
        const novoCliente = await pool.query(
            `INSERT INTO clientes (nome, cpf, email, senha, telefone)
             VALUES ($1, $2, $3, $4, $5)
             RETURNING id, nome, cpf, email, telefone, criado_em`,
            [nome, cpf, email, senhaHash, telefone] // Usando a senha encriptada do Victor
        );

        res.status(201).json({
            mensagem: 'Cliente registado com sucesso!',
            cliente: novoCliente.rows[0],
        });
    } catch (erro) {
        next(erro);
    }
});

// -------------------------------------------------------
// MÓDULO DE PROFISSIONAIS (CATÁLOGO & REGISTO)
// -------------------------------------------------------

// 1. Listar profissionais aprovados (com filtro opcional de categoria via Query: ?categoria=X)
app.get('/api/profissionais', async (req, res, next) => {
    try {
        const { categoria } = req.query; 

        let query = 'SELECT id, nome, categoria, biografia, taxa_visita, avaliacao FROM profissionais WHERE status = $1';
        const valores = ['aprovado']; 

        if (categoria) {
            query += ' AND categoria = $2';
            valores.push(categoria);
        }

        const resultado = await pool.query(query, valores);
        res.json(resultado.rows);
    } catch (erro) {
        next(erro);
    }
});

// 2. Ver o perfil detalhado de um profissional específico por ID
app.get('/api/profissionais/:id', async (req, res, next) => {
    try {
        const { id } = req.params;
        const resultado = await pool.query(
            'SELECT id, nome, categoria, biografia, taxa_visita, avaliacao, criado_em FROM profissionais WHERE id = $1',
            [id]
        );

        if (resultado.rows.length === 0) {
            return res.status(404).json({ erro: "Profissional não encontrado." });
        }

        res.json(resultado.rows[0]);
    } catch (erro) {
        next(erro);
    }
});

// 3. Registar um novo profissional na plataforma
app.post('/api/profissionais', async (req, res, next) => {
    try {
        const { nome, cpf_cnpj, email, senha, telefone, categoria, biografia } = req.body;
        
        const senhaHash = await bcrypt.hash(senha, 10);

        const novoProfissional = await pool.query(
            `INSERT INTO profissionais 
            (nome, cpf_cnpj, email, senha, telefone, categoria, biografia) 
            VALUES ($1, $2, $3, $4, $5, $6, $7) 
            RETURNING id, nome, categoria, status, criado_em`,
            [nome, cpf_cnpj, email, senhaHash, telefone, categoria, biografia]
        );

        res.status(201).json({
            mensagem: "Profissional registado com sucesso! Aguardando aprovação.",
            profissional: novoProfissional.rows[0]
        });
    } catch (erro) {
        next(erro);
    }
});

// ==========================================
// MÓDULO ON-DEMAND (ESTILO UBER)
// ==========================================

// 4. Criar um Chamado Express (O cliente pede socorro)
app.post('/api/chamados', async (req, res, next) => {
    try {
        const { cliente_id, categoria_solicitada, problema_descricao, latitude_destino, longitude_destino } = req.body;

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
app.put('/api/chamados/:id/aceitar', async (req, res, next) => {
    try {
        const { id } = req.params; 
        const { profissional_id } = req.body; 

        const verChamado = await pool.query('SELECT status FROM chamados_express WHERE id = $1', [id]);
        
        if (verChamado.rows.length === 0) {
            return res.status(404).json({ erro: "Pedido de emergência não encontrado." });
        }
        
        if (verChamado.rows[0].status !== 'procurando_profissional') {
            return res.status(400).json({ 
                erro: "Que pena! Outro profissional já aceitou este pedido ou o cliente cancelou." 
            });
        }

        const atualizacao = await pool.query(
            `UPDATE chamados_express 
             SET profissional_id = $1, 
                 status = 'a_caminho', 
                 aceite_em = CURRENT_TIMESTAMP 
             WHERE id = $2 
             RETURNING id, status, aceite_em`,
            [profissional_id, id]
        );

        res.json({
            mensagem: "Serviço aceite com sucesso! O cliente já sabe que estás a caminho.",
            chamado: atualizacao.rows[0]
        });

    } catch (erro) {
        next(erro);
    }
});

// 6. Profissional avisa que chegou ao local
app.put('/api/chamados/:id/chegada', async (req, res, next) => {
    try {
        const { id } = req.params;
        const { profissional_id } = req.body; 

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
app.put('/api/chamados/:id/finalizar', async (req, res, next) => {
    try {
        const { id } = req.params;
        const { profissional_id } = req.body; 

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

// ==========================================
// MÓDULO DE AVALIAÇÕES (SISTEMA DE 5 ESTRELAS)
// ==========================================

// 8. Cliente avalia um serviço finalizado
app.post('/api/avaliacoes', async (req, res, next) => {
    try {
        const { chamado_id, nota, comentario } = req.body;

        // 1. Validação de segurança básica
        if (!nota || nota < 1 || nota > 5) {
            return res.status(400).json({ erro: "A nota deve ser um número inteiro entre 1 e 5." });
        }

        // 2. Verificamos o estado do serviço e descobrimos quem é o cliente e o profissional
        const verChamado = await pool.query(
            'SELECT cliente_id, profissional_id, status FROM chamados_express WHERE id = $1',
            [chamado_id]
        );

        if (verChamado.rows.length === 0) {
            return res.status(404).json({ erro: "Pedido de serviço não encontrado." });
        }

        // Não deixamos o cliente avaliar um eletricista que ainda está a caminho!
        if (verChamado.rows[0].status !== 'finalizado') {
            return res.status(400).json({ erro: "Só é possível avaliar serviços que já foram finalizados." });
        }

        const { cliente_id, profissional_id } = verChamado.rows[0];

        // 3. Verificamos se o cliente já avaliou este serviço antes
        const jaAvaliado = await pool.query('SELECT id FROM avaliacoes WHERE chamado_id = $1', [chamado_id]);
        if (jaAvaliado.rows.length > 0) {
            return res.status(409).json({ erro: "Este serviço já foi avaliado anteriormente." });
        }

        // 4. Guardamos a avaliação na base de dados
        const novaAvaliacao = await pool.query(
            `INSERT INTO avaliacoes (chamado_id, cliente_id, profissional_id, nota, comentario) 
             VALUES ($1, $2, $3, $4, $5) 
             RETURNING id, nota, comentario, criado_em`,
            [chamado_id, cliente_id, profissional_id, nota, comentario]
        );

        // 5. A MAGIA: Recalcula a média global do profissional usando SQL puro e rápido
        const media = await pool.query(
            'SELECT AVG(nota) as media_notas FROM avaliacoes WHERE profissional_id = $1',
            [profissional_id]
        );
        
        // Arredonda para 1 casa decimal (Ex: 4.8)
        const novaMedia = parseFloat(media.rows[0].media_notas).toFixed(1); 

        // 6. Atualiza o perfil do profissional com a nova pontuação
        await pool.query(
            'UPDATE profissionais SET avaliacao = $1 WHERE id = $2',
            [novaMedia, profissional_id]
        );

        res.status(201).json({
            mensagem: "Avaliação registada com sucesso! Obrigado pelo feedback.",
            avaliacao: novaAvaliacao.rows[0],
            nova_media_profissional: novaMedia
        });

    } catch (erro) {
        next(erro);
    }
});

// -------------------------------------------------------
// MIDDLEWARE DE ERROS — deve ser O ÚLTIMO app.use()
// -------------------------------------------------------
app.use(errorHandler);

module.exports = app;