const express = require('express');
const pool = require('./config/database');
const { errorHandler } = require('./middlewares/errorHandler');
const { validarCadastroCliente } = require('./middlewares/validators/clienteValidator');
const bcrypt = require('bcrypt'); // Adicionado pelo Victor

const app = express();

app.use(express.json());

// Uso de controladores e rotas organizados
//--------------------------------------------
//clientes
const rotasClientes = require('./routes/clientes.routes');

app.use('/api/clientes', rotasClientes); // Diz ao Express para usar o novo ficheiro

//profissionais
const rotasProfissionais = require('./routes/profissionais.routes');

app.use('/api/profissionais', rotasProfissionais);

//chamados
const rotasChamados = require('./routes/chamados.routes');

app.use('/api/chamados', rotasChamados);

//--------------------------------------------
// -------------------------------------------------------
// STATUS DA API
// -------------------------------------------------------
app.get('/api/status', (req, res) => {
    res.json({ message: 'Motor do Helpi a funcionar perfeitamente!' });
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