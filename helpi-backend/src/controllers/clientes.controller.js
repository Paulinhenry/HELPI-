const pool = require('../config/database');
const bcrypt = require('bcrypt'); // A encriptação do Victor vem para aqui

const criarCliente = async (req, res, next) => {
    try {
        const { nome, cpf, email, senha, telefone } = req.body;
        
        // Criptografia da senha
        const senhaHash = await bcrypt.hash(senha, 10); 
        
        // Lógica de Base de Dados
        const novoCliente = await pool.query(
            `INSERT INTO clientes (nome, cpf, email, senha, telefone)
             VALUES ($1, $2, $3, $4, $5)
             RETURNING id, nome, cpf, email, telefone, criado_em`,
            [nome, cpf, email, senhaHash, telefone] 
        );

        // Resposta de Sucesso
        res.status(201).json({
            mensagem: 'Cliente registado com sucesso!',
            cliente: novoCliente.rows[0],
        });
    } catch (erro) {
        next(erro);
    }
};

module.exports = {
    criarCliente
};