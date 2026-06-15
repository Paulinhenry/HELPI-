const pool = require('../config/database');

// 1. Listar profissionais aprovados (com filtro opcional de categoria)
const listarProfissionais = async (req, res, next) => {
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
};

// 2. Ver o perfil detalhado de um profissional por ID
const verProfissional = async (req, res, next) => {
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
};

// 3. Registar um novo profissional
const registarProfissional = async (req, res, next) => {
    try {
        const { nome, cpf_cnpj, email, senha, telefone, categoria, biografia } = req.body;

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
        next(erro);
    }
};

// Exportamos as 3 funções para as rotas poderem usá-las
module.exports = {
    listarProfissionais,
    verProfissional,
    registarProfissional
};