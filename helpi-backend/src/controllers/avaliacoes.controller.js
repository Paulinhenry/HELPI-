const pool = require('../config/database');
const bcrypt = require('bcrypt');

// ==========================================
// MÓDULO DE AVALIAÇÕES (SISTEMA DE 5 ESTRELAS)
// ==========================================

// 8. Cliente avalia um serviço finalizado
app.post('/api/avaliacoes', authCliente, async (req, res, next) => {
    try {
        const { chamado_id, nota, comentario } = req.body;
        const clienteLogadoId = req.usuario.id;

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

        const clienteDoChamado = verChamado.rows[0].cliente_id;

        if (clienteLogadoId !== clienteDoChamado) {
          return res.status(403).json({
        erro: "Você não pode avaliar um serviço que não é seu."});
        }

        // Não deixamos o cliente avaliar um eletricista que ainda está a caminho!
        if (verChamado.rows[0].status !== 'finalizado') {
            return res.status(400).json({ erro: "Só é possível avaliar serviços que já foram finalizados." });
        }

        const profissional_id = verChamado.rows[0].profissional_id;

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
            [chamado_id, clienteLogadoId, profissional_id, nota, comentario]
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