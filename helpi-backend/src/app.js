const express = require('express');
const pool = require('./config/database');
const { errorHandler } = require('./middlewares/errorHandler');
const { validarCadastroCliente } = require('./middlewares/validators/clienteValidator');

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

// O validarCadastroCliente roda ANTES da lógica da rota.
// Se a validação falhar, nem chega ao banco.
app.post('/api/clientes', validarCadastroCliente, async (req, res, next) => {
    try {
        const { nome, cpf, email, senha, telefone } = req.body;

        // Nota: A password ainda está em texto limpo — o teu sócio vai injetar o bcrypt aqui.
        const novoCliente = await pool.query(
            `INSERT INTO clientes (nome, cpf, email, senha, telefone)
             VALUES ($1, $2, $3, $4, $5)
             RETURNING id, nome, cpf, email, telefone, criado_em`,
            [nome, cpf, email, senha, telefone]
        );

        res.status(201).json({
            mensagem: 'Cliente registado com sucesso!',
            cliente: novoCliente.rows[0],
        });
    } catch (erro) {
        // Envia o erro diretamente para o errorHandler centralizado
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

        // Insere usando os campos exatos mapeados na base de dados (cpf_cnpj e categoria)
        const novoProfissional = await pool.query(
            `INSERT INTO profissionais 
            (nome, cpf_cnpj, email, senha, telefone, categoria, biografia) 
            VALUES ($1, $2, $3, $4, $5, $6, $7) 
            RETURNING id, nome, categoria, status, criado_em`,
            [nome, cpf_cnpj, email, senha, telefone, categoria, biografia]
        );

        res.status(201).json({
            mensagem: "Profissional registado com sucesso! Aguardando aprovação.",
            profissional: novoProfissional.rows[0]
        });
    } catch (erro) {
        // Deixa o errorHandler central lidar com CPFs ou E-mails duplicados
        next(erro);
    }
});

// ==========================================
// MÓDULO ON-DEMAND (ESTILO UBER)
// ==========================================

// 4. Criar um Chamado Express (O cliente pede socorro)
app.post('/api/chamados', async (req, res, next) => {
    try {
        // Recebemos a localização do cliente e o problema
        const { cliente_id, categoria_solicitada, problema_descricao, latitude_destino, longitude_destino } = req.body;

        // A MÁGICA: Fórmula de Haversine no PostgreSQL para achar quem está num raio de 10km
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

        // Executamos a procura por profissionais próximos
        const busca = await pool.query(`SELECT * FROM (${queryProfissionaisProximos}) AS subset WHERE distancia_km <= 10 ORDER BY distancia_km ASC LIMIT 5`, 
        [latitude_destino, longitude_destino, categoria_solicitada]);

        // Se a lista estiver vazia, não há ninguém na região
        if (busca.rows.length === 0) {
            return res.status(404).json({ 
                erro: `Pedimos desculpa! Não há nenhum ${categoria_solicitada} disponível num raio de 10km neste exato momento.` 
            });
        }

        // Se encontrou profissionais, criamos o chamado no banco (ainda sem profissional associado, à espera que alguém aceite)
        const novoChamado = await pool.query(
            `INSERT INTO chamados_express 
            (cliente_id, categoria_solicitada, problema_descricao, latitude_destino, longitude_destino, status) 
            VALUES ($1, $2, $3, $4, $5, 'procurando_profissional') 
            RETURNING id, status, criado_em`,
            [cliente_id, categoria_solicitada, problema_descricao, latitude_destino, longitude_destino]
        );

        res.status(201).json({
            mensagem: "Chamado criado com sucesso! A notificar profissionais próximos...",
            chamado: novoChamado.rows[0],
            profissionais_notificados: busca.rows.length // Mostra a quantos profissionais o alerta vai tocar
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