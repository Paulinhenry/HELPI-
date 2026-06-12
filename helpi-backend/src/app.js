const express = require('express');
const pool = require('./config/database');
const app = express();

app.use(express.json());

app.get('/api/status', (req, res) => {
    res.json({ message: "Motor do Helpi a funcionar perfeitamente!" });
});

app.post('/api/clientes', async (req, res) => {
    try {
        const { nome, email, senha, telefone } = req.body;
        const novoCliente = await pool.query(
            'INSERT INTO clientes (nome, email, senha, telefone) VALUES ($1, $2, $3, $4) RETURNING id, nome, email, telefone, criado_em',
            [nome, email, senha, telefone]
        );
        res.status(201).json({ mensagem: "Cliente registado com sucesso!", cliente: novoCliente.rows[0] });
    } catch (erro) {
        if (erro.code === '23505') return res.status(400).json({ erro: "Este e-mail já está em uso na plataforma." });
        res.status(500).json({ erro: "Erro interno", detalhes: erro.message });
    }
});

module.exports = app;