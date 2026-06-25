// =============================================================
// HELPI - Controlador de Clientes
// Gerencia o registo de novos clientes na plataforma.
// =============================================================

const pool = require('../config/database');
const bcrypt = require('bcrypt');
const logger = require('../utils/logger');

const SALT_ROUNDS = 12;

const criarCliente = async (req, res, next) => {
    try {
        const { nome, cpf, email, senha, telefone } = req.body;
        const senhaHash = await bcrypt.hash(senha, SALT_ROUNDS);

        const novoCliente = await pool.query(
            `INSERT INTO clientes (nome, cpf, email, senha, telefone)
             VALUES ($1, $2, $3, $4, $5)
             RETURNING id, nome, cpf, email, telefone, criado_em`,
            [nome, cpf, email.toLowerCase().trim(), senhaHash, telefone]
        );

        logger.info(`[CLIENTE] REGISTADO: cliente ${novoCliente.rows[0].id} | email: ${email.toLowerCase().trim()}`);

        res.status(201).json({
            mensagem: 'Cliente registado com sucesso!',
            cliente: novoCliente.rows[0],
        });
    } catch (erro) {
        next(erro);
    }
};

module.exports = { criarCliente };