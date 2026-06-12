const express = require('express');
const pool = require('./config/database');
const { errorHandler } = require('./middlewares/errorHandler');
const { validarCadastroCliente } = require('./middlewares/validators/clienteValidator');

const app = express();

app.use(express.json());

// -------------------------------------------------------
// ROTAS
// -------------------------------------------------------

app.get('/api/status', (req, res) => {
    res.json({ message: 'Motor do Helpi a funcionar perfeitamente!' });
});

// O validarCadastroCliente roda ANTES da lógica da rota.
// Se a validação falhar, nem chega ao banco.
app.post('/api/clientes', validarCadastroCliente, async (req, res, next) => {
    try {
        const { nome, cpf, email, senha, telefone } = req.body;

        // ATENÇÃO: senha ainda em texto puro — seu sócio vai adicionar bcrypt aqui.
        // A linha ficará: const senhaHash = await bcrypt.hash(senha, 12);
        // E o INSERT usará senhaHash no lugar de senha.
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
        // Passa o erro para o errorHandler central — sem mais if/else aqui
        next(erro);
    }
});

// -------------------------------------------------------
// MIDDLEWARE DE ERROS — deve ser o ÚLTIMO app.use()
// -------------------------------------------------------
app.use(errorHandler);

module.exports = app;
