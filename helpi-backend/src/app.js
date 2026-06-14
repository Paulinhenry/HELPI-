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

// -------------------------------------------------------
// MIDDLEWARE DE ERROS — deve ser O ÚLTIMO app.use()
// -------------------------------------------------------
app.use(errorHandler);

module.exports = app;