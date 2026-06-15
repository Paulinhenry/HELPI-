const pool = require('../config/database');
const bcrypt = require('bcrypt'); // A encriptação do Victor vem para aqui

// -------------------------------------------------------
// MÓDULO DE CLIENTES
// -------------------------------------------------------

app.post('/api/clientes', validarCadastroCliente, async (req, res, next) => {
    try {
        const { nome, cpf, email, senha, telefone } = req.body;
        
        // CÓDIGO DO VICTOR: Encriptação de senha ativada! 🔒
        const senhaHash = await bcrypt.hash(senha, 10); 
        
        const novoCliente = await pool.query(
            `INSERT INTO clientes (nome, cpf, email, senha, telefone)
             VALUES ($1, $2, $3, $4, $5)
             RETURNING id, nome, cpf, email, telefone, criado_em`,
            [nome, cpf, email, senhaHash, telefone] // Usando a senha encriptada do Victor
        );

        res.status(201).json({
            mensagem: 'Cliente registado com sucesso!',
            cliente: novoCliente.rows[0],
        });
    } catch (erro) {
        next(erro);
    }
});