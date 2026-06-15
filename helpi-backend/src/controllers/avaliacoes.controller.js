const pool = require('../config/database');

const criarAvaliacao = async (req, res, next) => {
    try {
        const { chamado_id, nota, comentario } = req.body;

        if (!nota || nota < 1 || nota > 5) {
            return res.status(400).json({ erro: "A nota deve ser um número inteiro entre 1 e 5." });
        }

        const verChamado = await pool.query(
            'SELECT cliente_id, profissional_id, status FROM chamados_express WHERE id = $1',
            [chamado_id]
        );

        if (verChamado.rows.length === 0) {
            return res.status(404).json({ erro: "Pedido de serviço não encontrado." });
        }

        if (verChamado.rows[0].status !== 'finalizado') {
            return res.status(400).json({ erro: "Só é possível avaliar serviços que já foram finalizados." });
        }

        const { cliente_id, profissional_id } = verChamado.rows[0];

        const jaAvaliado = await pool.query('SELECT id FROM avaliacoes WHERE chamado_id = $1', [chamado_id]);
        if (jaAvaliado.rows.length > 0) {
            return res.status(409).json({ erro: "Este serviço já foi avaliado anteriormente." });
        }

        const novaAvaliacao = await pool.query(
            `INSERT INTO avaliacoes (chamado_id, cliente_id, profissional_id, nota, comentario) 
             VALUES ($1, $2, $3, $4, $5) 
             RETURNING id, nota, comentario, criado_em`,
            [chamado_id, cliente_id, profissional_id, nota, comentario]
        );

        const media = await pool.query(
            'SELECT AVG(nota) as media_notas FROM avaliacoes WHERE profissional_id = $1',
            [profissional_id]
        );
        
        const novaMedia = parseFloat(media.rows[0].media_notas).toFixed(1); 

        await pool.query(
            'UPDATE profissionais SET avaliacao = $1 WHERE id = $2',
            [novaMedia, profissional_id]
        );

        res.status(201).json({
            mensagem: "Avaliação registada com sucesso!",
            avaliacao: novaAvaliacao.rows[0],
            nova_media_profissional: novaMedia
        });

    } catch (erro) {
        next(erro);
    }
};

module.exports = { criarAvaliacao };