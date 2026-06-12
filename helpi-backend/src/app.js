const express = require('express');
const pool = require('./config/database');
const app = express();

app.use(express.json());

app.get('/api/status', (req, res) => {
    res.json({ message: "Motor do Helpi a funcionar perfeitamente!" });
});

app.post('/api/clientes', async (req, res) => {
    try {
        // 1. Agora extraímos também o cpf do que vem do telemóvel
        const { nome, cpf, email, senha, telefone } = req.body;

        // 2. Inserimos o cpf na query SQL ($2 agora é o cpf, os outros avançam uma casa)
        const novoCliente = await pool.query(
            'INSERT INTO clientes (nome, cpf, email, senha, telefone) VALUES ($1, $2, $3, $4, $5) RETURNING id, nome, cpf, email, telefone, criado_em',
            [nome, cpf, email, senha, telefone]
        );

        res.status(201).json({
            mensagem: "Cliente registado com sucesso!",
            cliente: novoCliente.rows[0]
        });
    } catch (erro) {
        console.error('Erro no registo:', erro);
        // Se o erro for de duplicação (email ou cpf já existem)
        if (erro.code === '23505') {
            return res.status(400).json({ erro: "Este E-mail ou CPF já está em uso na plataforma." });
        }
        res.status(500).json({ erro: "Erro interno", detalhes: erro.message });
    }
});

module.exports = app;